#!/bin/bash
# Helper script to encode private key for environment variable storage

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-private-key.pem>"
    echo ""
    echo "This script encodes your GitHub App private key to base64"
    echo "so you can store it as an environment variable."
    echo ""
    echo "Example:"
    echo "  $0 private-key.pem"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Error: File not found: $1"
    exit 1
fi

echo "Encoding private key: $1"
echo ""
echo "Add this to your .env file or hosting platform:"
echo ""
echo "GITHUB_PRIVATE_KEY_B64=$(cat "$1" | base64 -w 0)"
echo ""

