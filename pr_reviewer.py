#!/usr/bin/env python3
"""
PR Reviewer using Gemini API
"""
import logging
from pprint import pp
import google.generativeai as genai
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)


class PRReviewer:
    """Review pull requests using Gemini API"""

    def __init__(self, api_key: Optional[str] = None):
        """Initialize the PR reviewer with Gemini API key"""
        if api_key:
            genai.configure(api_key=api_key)
            for model in genai.list_models():
                print(model)
            print(genai.list_models)
            self.model = genai.GenerativeModel("gemini-2.5-pro")
        else:
            self.model = None
            logger.warning("Gemini API key not provided")

    def review_pr(self, title: str, body: str, file_changes: List[Dict]) -> Dict:
        """
        Review a pull request and generate comments

        Args:
            title: PR title
            body: PR description
            file_changes: List of file change dictionaries

        Returns:
            Dictionary containing review summary and file comments
        """
        if not self.model:
            logger.error("Gemini model not initialized")
            return {}

        try:
            # Prepare context for review
            review_prompt = self._build_review_prompt(title, body, file_changes)

            # Generate review
            logger.info("Generating review with Gemini API...")
            response = self.model.generate_content(review_prompt)

            # Parse response
            review_text = response.text

            # Structure the review
            review_comments = self._parse_review(review_text, file_changes)

            return review_comments

        except Exception as e:
            logger.error(f"Error generating review: {e}")
            return {
                "summary": f"Error generating review: {str(e)}",
                "file_comments": [],
            }

    def _build_review_prompt(
        self, title: str, body: str, file_changes: List[Dict]
    ) -> str:
        """Build the prompt for Gemini API"""
        prompt = f"""You are an expert code reviewer. Review the following pull request and provide constructive feedback.

Pull Request Title: {title}

Pull Request Description:
{body}

Changed Files:
"""

        for file_change in file_changes:
            filename = file_change.get("filename", "unknown")
            status = file_change.get("status", "unknown")
            additions = file_change.get("additions", 0)
            deletions = file_change.get("deletions", 0)
            patch = file_change.get("patch", "")

            prompt += f"\n--- File: {filename} ({status}) ---\n"
            prompt += f"Additions: +{additions}, Deletions: -{deletions}\n"

            if patch:
                # Limit patch size to avoid token limits
                patch_preview = patch[:5000] if len(patch) > 5000 else patch
                prompt += f"\nDiff:\n{patch_preview}\n"
                if len(patch) > 5000:
                    prompt += "\n[... diff truncated ...]\n"

        prompt += """
Please provide a comprehensive code review with the following structure:

1. **Overall Assessment**: Brief summary of the PR
2. **Strengths**: What was done well
3. **Issues Found**: List any bugs, security issues, performance problems, or code quality concerns
4. **Suggestions**: Recommendations for improvement
5. **File-specific Comments**: For each file with issues, provide:
   - File path
   - Line number (if applicable)
   - Specific comment

Format your response clearly with markdown. Be constructive and professional.
"""

        return prompt

    def _parse_review(self, review_text: str, file_changes: List[Dict]) -> Dict:
        """Parse the review response into structured format"""
        # Extract file-specific comments
        file_comments = []

        # Try to extract file-specific comments from the review
        lines = review_text.split("\n")
        current_file = None
        current_line = None

        for i, line in enumerate(lines):
            # Look for file references
            if "File:" in line or "**" in line:
                # Try to extract filename
                for file_change in file_changes:
                    filename = file_change.get("filename", "")
                    if filename in line:
                        current_file = filename
                        break

            # Look for line numbers
            if "line" in line.lower() and any(char.isdigit() for char in line):
                try:
                    # Extract line number
                    words = line.split()
                    for word in words:
                        if word.isdigit():
                            current_line = int(word)
                            break
                except:
                    pass

        # Create structured review
        review_comments = {"summary": review_text, "file_comments": file_comments}

        # If we found file-specific references, add them
        if current_file:
            review_comments["file_comments"].append(
                {
                    "path": current_file,
                    "line": current_line,
                    "comment": review_text[:500],  # Truncate if too long
                }
            )

        return review_comments

    def format_review_summary(self, review_comments: Dict) -> str:
        """Format review comments for GitHub comment"""
        summary = review_comments.get("summary", "")

        # Add header
        formatted = "## 🤖 AI Code Review (Powered by Gemini)\n\n"
        formatted += summary

        # Add file-specific comments if any
        file_comments = review_comments.get("file_comments", [])
        if file_comments:
            formatted += "\n\n### File-specific Comments\n\n"
            for comment in file_comments:
                path = comment.get("path", "unknown")
                line = comment.get("line", "")
                comment_text = comment.get("comment", "")

                formatted += f"**`{path}`**"
                if line:
                    formatted += f" (line {line})"
                formatted += f":\n{comment_text}\n\n"

        formatted += "\n---\n*This review was generated automatically by the Gemini AI Code Review Bot.*"

        return formatted
