# Quick Start Guide

## 1. Get Your Gemini API Key

1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the API key

## 2. Create a GitHub App

1. Go to: `https://github.com/settings/apps/new`
2. Fill in:
   - **Name**: PR Review Bot (or your choice)
   - **Homepage URL**: Your website (can be placeholder)
   - **Webhook URL**: `https://your-domain.com/webhook` (use ngrok for testing)
   - **Webhook secret**: Generate a random string (save it!)
3. Set permissions:
   - **Pull requests**: Read & Write
   - **Contents**: Read
   - **Metadata**: Read-only
4. Subscribe to events: **Pull requests**
5. Click "Create GitHub App"
6. **Download the private key** (.pem file) - you'll need this!

## 3. Install the GitHub App

1. In your GitHub App settings, click "Install App"
2. Choose repositories or organization
3. Install

## 4. Set Up the Bot

```bash
# Run setup script
./setup.sh

# Or manually:
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

## 5. Configure Environment Variables

Edit `.env` file:

```env
GEMINI_API_KEY=your_gemini_api_key_here
GITHUB_APP_ID=123456  # From GitHub App settings
GITHUB_PRIVATE_KEY_PATH=/path/to/your-app-private-key.pem
GITHUB_WEBHOOK_SECRET=your_webhook_secret_here
PORT=3000
HOST=0.0.0.0
```

## 6. Test the Bot

```bash
# Test Gemini connection
python test_bot.py
```

## 7. Run Locally with ngrok

```bash
# Terminal 1: Start the bot
python app.py

# Terminal 2: Start ngrok
ngrok http 3000

# Copy the HTTPS URL (e.g., https://abc123.ngrok.io)
# Update GitHub App webhook URL to: https://abc123.ngrok.io/webhook
```

## 8. Test It!

1. Create a test PR in your repository
2. The bot should automatically review it and post comments!

## Troubleshooting

- **Bot not responding?** Check webhook deliveries in GitHub App settings
- **Authentication errors?** Verify your App ID and private key path
- **Gemini errors?** Check your API key and quota

## Next Steps

- Deploy to production (Heroku, Railway, AWS, etc.)
- Customize review prompts in `pr_reviewer.py`
- Add more features as needed!

