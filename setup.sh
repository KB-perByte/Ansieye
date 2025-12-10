#!/bin/bash

echo "🚀 Setting up GitHub PR Review Bot"
echo ""

# Check Python version
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python version: $python_version"

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "Creating .env file from template..."
    cp .env.example .env
    echo ""
    echo "⚠️  Please edit .env file and add your configuration:"
    echo "   - GEMINI_API_KEY"
    echo "   - GITHUB_APP_ID"
    echo "   - GITHUB_PRIVATE_KEY_PATH"
    echo "   - GITHUB_WEBHOOK_SECRET"
else
    echo ".env file already exists"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit .env file with your credentials"
echo "2. Run 'python test_bot.py' to test the connection"
echo "3. Run 'python app.py' to start the bot"

