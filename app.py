#!/usr/bin/env python3
"""
GitHub Bot for PR Reviews using Gemini API
"""
import os
import hmac
import hashlib
import base64
import logging
from flask import Flask, request, jsonify
from dotenv import load_dotenv
from github import Github
from github.GithubException import GithubException
import google.generativeai as genai
from pr_reviewer import PRReviewer

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
GITHUB_APP_ID = os.getenv('GITHUB_APP_ID')
GITHUB_PRIVATE_KEY_PATH = os.getenv('GITHUB_PRIVATE_KEY_PATH')
GITHUB_WEBHOOK_SECRET = os.getenv('GITHUB_WEBHOOK_SECRET')
PORT = int(os.getenv('PORT', 3000))
HOST = os.getenv('HOST', '0.0.0.0')

# Initialize Gemini
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
else:
    logger.warning("GEMINI_API_KEY not set. Gemini API will not work.")

# Initialize PR Reviewer
pr_reviewer = PRReviewer(GEMINI_API_KEY)


def verify_webhook_signature(payload_body, signature_header):
    """Verify GitHub webhook signature"""
    if not GITHUB_WEBHOOK_SECRET:
        logger.warning("GITHUB_WEBHOOK_SECRET not set. Skipping signature verification.")
        return True

    if not signature_header:
        return False

    hash_object = hmac.new(
        GITHUB_WEBHOOK_SECRET.encode('utf-8'),
        msg=payload_body,
        digestmod=hashlib.sha256
    )
    expected_signature = "sha256=" + hash_object.hexdigest()

    return hmac.compare_digest(expected_signature, signature_header)


def get_github_client(installation_id):
    """Get authenticated GitHub client for an installation"""
    # Try to get private key from environment variable (base64 encoded) first
    private_key = None
    private_key_b64 = os.getenv('GITHUB_PRIVATE_KEY_B64')

    if private_key_b64:
        try:
            private_key = base64.b64decode(private_key_b64).decode('utf-8')
            logger.info("Using private key from GITHUB_PRIVATE_KEY_B64 environment variable")
        except Exception as e:
            logger.warning(f"Failed to decode GITHUB_PRIVATE_KEY_B64: {e}")

    # Fallback to file path
    if not private_key and GITHUB_PRIVATE_KEY_PATH:
        if os.path.exists(GITHUB_PRIVATE_KEY_PATH):
            try:
                with open(GITHUB_PRIVATE_KEY_PATH, 'r') as key_file:
                    private_key = key_file.read()
                logger.info(f"Using private key from file: {GITHUB_PRIVATE_KEY_PATH}")
            except Exception as e:
                logger.error(f"Error reading private key file: {e}")
        else:
            logger.error(f"Private key file not found: {GITHUB_PRIVATE_KEY_PATH}")

    if not private_key:
        logger.error("No private key available. Set GITHUB_PRIVATE_KEY_B64 or GITHUB_PRIVATE_KEY_PATH")
        return None

    try:
        from github import GithubIntegration

        integration = GithubIntegration(GITHUB_APP_ID, private_key)
        access_token = integration.get_access_token(installation_id).token

        return Github(access_token)
    except Exception as e:
        logger.error(f"Error creating GitHub client: {e}")
        return None


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "github-pr-review-bot"}), 200


@app.route('/webhook', methods=['POST'])
def webhook():
    """Handle GitHub webhook events"""
    # Verify webhook signature
    signature = request.headers.get('X-Hub-Signature-256', '')
    if not verify_webhook_signature(request.data, signature):
        logger.warning("Invalid webhook signature")
        return jsonify({"error": "Invalid signature"}), 401

    # Parse webhook event
    event_type = request.headers.get('X-GitHub-Event')
    payload = request.json

    logger.info(f"Received webhook event: {event_type}")

    # Handle pull request events
    if event_type == 'pull_request':
        action = payload.get('action')
        logger.info(f"PR action: {action}")

        if action in ['opened', 'synchronize', 'reopened']:
            installation_id = payload.get('installation', {}).get('id')
            if not installation_id:
                logger.error("No installation ID found in webhook payload")
                return jsonify({"error": "No installation ID"}), 400

            # Process PR review asynchronously
            try:
                review_pr(payload, installation_id)
            except Exception as e:
                logger.error(f"Error processing PR review: {e}")
                return jsonify({"error": str(e)}), 500

        return jsonify({"status": "processed"}), 200

    return jsonify({"status": "ignored"}), 200


def review_pr(payload, installation_id):
    """Review a pull request using Gemini API"""
    pr_data = payload.get('pull_request', {})
    repo_full_name = pr_data.get('base', {}).get('repo', {}).get('full_name')
    pr_number = pr_data.get('number')
    pr_url = pr_data.get('html_url')

    logger.info(f"Reviewing PR #{pr_number} in {repo_full_name}")

    # Get GitHub client
    github_client = get_github_client(installation_id)
    if not github_client:
        logger.error("Failed to create GitHub client")
        return

    try:
        repo = github_client.get_repo(repo_full_name)
        pr = repo.get_pull(pr_number)

        # Get PR details
        title = pr.title
        body = pr.body or ""
        base_sha = pr.base.sha
        head_sha = pr.head.sha

        # Get file changes
        files = pr.get_files()
        file_changes = []

        for file in files:
            file_info = {
                'filename': file.filename,
                'status': file.status,
                'additions': file.additions,
                'deletions': file.deletions,
                'changes': file.changes,
                'patch': file.patch if hasattr(file, 'patch') else None
            }
            file_changes.append(file_info)

        logger.info(f"Found {len(file_changes)} changed files")

        # Generate review using Gemini
        review_comments = pr_reviewer.review_pr(
            title=title,
            body=body,
            file_changes=file_changes
        )

        if not review_comments:
            logger.info("No review comments generated")
            return

        # Post review comments
        post_review_comments(pr, review_comments)

    except GithubException as e:
        logger.error(f"GitHub API error: {e}")
    except Exception as e:
        logger.error(f"Error reviewing PR: {e}")


def post_review_comments(pr, review_comments):
    """Post review comments to the PR"""
    try:
        # Create a review summary comment
        summary_body = pr_reviewer.format_review_summary(review_comments)

        # Post as a PR comment
        pr.create_issue_comment(summary_body)
        logger.info("Posted review summary comment")

        # Post inline comments for specific files
        for comment in review_comments.get('file_comments', []):
            if comment.get('line') and comment.get('path'):
                try:
                    pr.create_review_comment(
                        body=comment['comment'],
                        commit_id=pr.head.sha,
                        path=comment['path'],
                        line=comment['line']
                    )
                    logger.info(f"Posted inline comment on {comment['path']}:{comment['line']}")
                except Exception as e:
                    logger.warning(f"Could not post inline comment: {e}")
                    # Fallback to general comment
                    pr.create_issue_comment(
                        f"**{comment['path']}** (line {comment['line']}):\n{comment['comment']}"
                    )

    except Exception as e:
        logger.error(f"Error posting review comments: {e}")


if __name__ == '__main__':
    if not GEMINI_API_KEY:
        logger.error("GEMINI_API_KEY environment variable is required")
        exit(1)

    logger.info(f"Starting GitHub PR Review Bot on {HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False)

