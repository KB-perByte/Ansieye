#!/usr/bin/env python3
"""
Test script for the GitHub PR Review Bot
"""
import os
import sys
from dotenv import load_dotenv
from pr_reviewer import PRReviewer

load_dotenv()

def test_gemini_connection():
    """Test Gemini API connection"""
    api_key = os.getenv('GEMINI_API_KEY')
    if not api_key:
        print("❌ GEMINI_API_KEY not set in .env file")
        return False

    print("Testing Gemini API connection...")
    reviewer = PRReviewer(api_key)

    # Test with a simple prompt
    try:
        test_prompt = "Say 'Hello, GitHub Bot!' if you can read this."
        response = reviewer.model.generate_content(test_prompt)
        print(f"✅ Gemini API connection successful!")
        print(f"Response: {response.text[:100]}")
        return True
    except Exception as e:
        print(f"❌ Gemini API connection failed: {e}")
        return False

def test_pr_review():
    """Test PR review functionality"""
    api_key = os.getenv('GEMINI_API_KEY')
    if not api_key:
        print("❌ GEMINI_API_KEY not set")
        return False

    reviewer = PRReviewer(api_key)

    # Mock PR data
    title = "Add user authentication"
    body = "This PR adds user authentication functionality"
    file_changes = [
        {
            'filename': 'auth.py',
            'status': 'added',
            'additions': 50,
            'deletions': 0,
            'patch': '''
+def login(username, password):
+    if username == "admin" and password == "password":
+        return True
+    return False
'''
        }
    ]

    print("\nTesting PR review generation...")
    try:
        review = reviewer.review_pr(title, body, file_changes)
        if review:
            print("✅ PR review generated successfully!")
            print("\nReview Summary:")
            print(review.get('summary', '')[:500])
            return True
        else:
            print("❌ Empty review returned")
            return False
    except Exception as e:
        print(f"❌ PR review failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    print("🧪 Testing GitHub PR Review Bot\n")

    # Test Gemini connection
    if not test_gemini_connection():
        sys.exit(1)

    # Test PR review
    if not test_pr_review():
        sys.exit(1)

    print("\n✅ All tests passed!")

