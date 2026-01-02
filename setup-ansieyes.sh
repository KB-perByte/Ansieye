#!/bin/bash

##############################################################################
# Ansieyes One-Click Setup Script
# Sets up everything needed to run Ansieyes with AI-Issue-Triage
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

##############################################################################
# Helper Functions
##############################################################################

print_header() {
    echo -e "${BLUE}"
    echo "============================================================"
    echo "$1"
    echo "============================================================"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_command() {
    if command -v $1 &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

##############################################################################
# Main Setup Functions
##############################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_deps=0
    
    # Check Python
    if check_command python3; then
        python_version=$(python3 --version)
        print_info "Python version: $python_version"
    else
        missing_deps=1
    fi
    
    # Check pip
    if check_command pip; then
        print_success "pip is installed"
    elif check_command pip3; then
        print_success "pip3 is installed"
        alias pip=pip3
    else
        missing_deps=1
    fi
    
    # Check git
    if ! check_command git; then
        missing_deps=1
    fi
    
    # Check Node.js
    if check_command node; then
        node_version=$(node --version)
        print_info "Node.js version: $node_version"
    else
        print_warning "Node.js is not installed - will attempt to install"
    fi
    
    # Check npm
    if check_command npm; then
        npm_version=$(npm --version)
        print_info "npm version: $npm_version"
    else
        print_warning "npm is not installed - will install with Node.js"
    fi
    
    if [ $missing_deps -eq 1 ]; then
        print_error "Some prerequisites are missing. Please install them first."
        exit 1
    fi
    
    print_success "All critical prerequisites are installed"
    echo
}

install_nodejs() {
    print_header "Installing Node.js and npm"
    
    if command -v node &> /dev/null; then
        print_info "Node.js already installed, skipping..."
        return 0
    fi
    
    echo "Detecting OS..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            print_info "Installing Node.js via Homebrew..."
            brew install node
        else
            print_error "Homebrew not found. Please install Node.js manually:"
            print_info "Visit: https://nodejs.org/"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        print_info "Installing Node.js via package manager..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y nodejs npm
        elif command -v yum &> /dev/null; then
            sudo yum install -y nodejs npm
        else
            print_error "Package manager not supported. Please install Node.js manually:"
            print_info "Visit: https://nodejs.org/"
            exit 1
        fi
    else
        print_error "OS not supported. Please install Node.js manually:"
        print_info "Visit: https://nodejs.org/"
        exit 1
    fi
    
    print_success "Node.js installed successfully"
    echo
}

install_repomix() {
    print_header "Installing Repomix"
    
    if command -v repomix &> /dev/null; then
        print_info "Repomix already installed, skipping..."
        return 0
    fi
    
    print_info "Installing repomix globally..."
    npm install -g repomix
    
    if command -v repomix &> /dev/null; then
        print_success "Repomix installed successfully"
        repomix_version=$(repomix --version)
        print_info "Repomix version: $repomix_version"
    else
        print_error "Failed to install repomix"
        exit 1
    fi
    
    echo
}

setup_ai_issue_triage() {
    print_header "Setting up AI-Issue-Triage"
    
    echo "Where do you want to install AI-Issue-Triage?"
    echo "Press Enter for default: $HOME/AI-Issue-Triage"
    read -p "Path: " ai_triage_path
    
    if [ -z "$ai_triage_path" ]; then
        ai_triage_path="$HOME/AI-Issue-Triage"
    fi
    
    # Expand ~ to home directory
    ai_triage_path="${ai_triage_path/#\~/$HOME}"
    
    if [ -d "$ai_triage_path" ]; then
        print_warning "Directory already exists: $ai_triage_path"
        read -p "Do you want to use this existing installation? (y/n): " use_existing
        if [[ $use_existing == "y" || $use_existing == "Y" ]]; then
            export AI_TRIAGE_PATH="$ai_triage_path"
            print_success "Using existing AI-Issue-Triage installation"
            return 0
        else
            print_info "Removing existing directory..."
            rm -rf "$ai_triage_path"
        fi
    fi
    
    print_info "Cloning AI-Issue-Triage repository..."
    git clone https://github.com/shvenkat-rh/AI-Issue-Triage.git "$ai_triage_path"
    
    print_info "Checking out feature/pr-analyzer branch..."
    cd "$ai_triage_path"
    git checkout feature/pr-analyzer || git checkout main
    
    print_info "Installing AI-Issue-Triage dependencies..."
    pip install -r requirements.txt
    
    export AI_TRIAGE_PATH="$ai_triage_path"
    print_success "AI-Issue-Triage installed at: $ai_triage_path"
    
    cd "$SCRIPT_DIR"
    echo
}

install_ansieyes_dependencies() {
    print_header "Installing Ansieyes Dependencies"
    
    print_info "Installing Python packages..."
    pip install -r requirements.txt
    
    print_success "Dependencies installed successfully"
    echo
}

configure_environment() {
    print_header "Configuring Environment"
    
    if [ -f ".env" ]; then
        print_warning ".env file already exists"
        read -p "Do you want to overwrite it? (y/n): " overwrite
        if [[ $overwrite != "y" && $overwrite != "Y" ]]; then
            print_info "Keeping existing .env file"
            return 0
        fi
    fi
    
    print_info "Creating .env file..."
    
    # Gemini API Key
    echo
    print_info "Get your Gemini API key from: https://makersuite.google.com/app/apikey"
    read -p "Enter your Gemini API key: " gemini_api_key
    
    # GitHub App ID
    echo
    print_info "You'll need to create a GitHub App first if you haven't already."
    print_info "Follow the guide at: https://github.com/settings/apps"
    read -p "Enter your GitHub App ID: " github_app_id
    
    # GitHub Private Key Path
    echo
    read -p "Enter the full path to your GitHub App private key (.pem file): " github_private_key_path
    github_private_key_path="${github_private_key_path/#\~/$HOME}"
    
    if [ ! -f "$github_private_key_path" ]; then
        print_error "Private key file not found: $github_private_key_path"
        print_warning "Please make sure the file exists and try again"
    fi
    
    # Webhook Secret
    echo
    read -p "Enter your GitHub webhook secret: " github_webhook_secret
    
    # Port and Host
    echo
    read -p "Enter port number (default 3000): " port
    port=${port:-3000}
    
    read -p "Enter host (default 0.0.0.0): " host
    host=${host:-0.0.0.0}
    
    # Create .env file
    cat > .env << EOF
# Gemini API Configuration
GEMINI_API_KEY=$gemini_api_key

# GitHub App Configuration
GITHUB_APP_ID=$github_app_id
GITHUB_PRIVATE_KEY_PATH=$github_private_key_path
GITHUB_WEBHOOK_SECRET=$github_webhook_secret

# AI-Issue-Triage Configuration
AI_TRIAGE_PATH=$AI_TRIAGE_PATH

# Server Configuration
PORT=$port
HOST=$host
EOF
    
    print_success ".env file created successfully"
    echo
}

setup_github_app_instructions() {
    print_header "GitHub App Setup Instructions"
    
    echo
    print_info "If you haven't created a GitHub App yet, follow these steps:"
    echo
    echo "1. Go to: https://github.com/settings/apps"
    echo "2. Click 'New GitHub App'"
    echo
    echo "3. Basic Information:"
    echo "   - Name: ansieyes-bot (or your choice)"
    echo "   - Homepage URL: https://github.com/your-username/Ansieyes"
    echo "   - Webhook URL: (use ngrok URL for testing)"
    echo "   - Webhook secret: (use a strong random string)"
    echo
    echo "4. Permissions (Repository):"
    echo "   - Contents: Read-only"
    echo "   - Issues: Read and write ✓"
    echo "   - Pull requests: Read and write ✓"
    echo "   - Actions: Read-only"
    echo
    echo "5. Subscribe to events:"
    echo "   ☑ Issue comment"
    echo "   ☑ Pull request"
    echo "   ☑ Workflow run"
    echo
    echo "6. After creation:"
    echo "   - Save the App ID"
    echo "   - Generate and download private key (.pem file)"
    echo "   - Install the app on your repositories"
    echo
    
    read -p "Press Enter when you have completed the GitHub App setup..."
    echo
}

test_setup() {
    print_header "Testing Setup"
    
    print_info "Verifying Python dependencies..."
    python3 -c "import flask; print('Flask:', flask.__version__)"
    python3 -c "import google.generativeai as genai; print('Gemini: OK')"
    python3 -c "from github import Github; print('PyGithub: OK')"
    python3 -c "import pydantic; print('Pydantic:', pydantic.__version__)"
    
    print_success "All Python dependencies verified"
    
    print_info "Verifying repomix..."
    repomix --version
    
    print_info "Verifying AI-Issue-Triage..."
    if [ -d "$AI_TRIAGE_PATH" ]; then
        print_success "AI-Issue-Triage found at: $AI_TRIAGE_PATH"
    else
        print_error "AI-Issue-Triage not found at: $AI_TRIAGE_PATH"
        return 1
    fi
    
    print_success "All tests passed!"
    echo
}

start_with_ngrok() {
    print_header "Starting Ansieyes with ngrok"
    
    if ! command -v ngrok &> /dev/null; then
        print_warning "ngrok is not installed"
        print_info "Install ngrok from: https://ngrok.com/download"
        print_info "Or on macOS: brew install ngrok"
        echo
        read -p "Do you want to start without ngrok? (y/n): " start_anyway
        if [[ $start_anyway != "y" && $start_anyway != "Y" ]]; then
            return 0
        fi
    fi
    
    echo
    print_info "To start Ansieyes:"
    echo
    echo "Terminal 1:"
    echo "  cd $SCRIPT_DIR"
    echo "  python3 app.py"
    echo
    echo "Terminal 2 (if using ngrok):"
    echo "  ngrok http 3000"
    echo "  Then update your GitHub App webhook URL with the ngrok URL"
    echo
    
    read -p "Do you want to start Ansieyes now? (y/n): " start_now
    if [[ $start_now == "y" || $start_now == "Y" ]]; then
        print_info "Starting Ansieyes..."
        python3 app.py
    fi
}

deploy_to_aws() {
    print_header "AWS Deployment"
    
    print_info "AWS deployment requires additional setup:"
    echo "  - AWS CLI configured"
    echo "  - Docker installed"
    echo "  - ECS cluster ready"
    echo
    
    read -p "Do you want to proceed with AWS deployment? (y/n): " deploy_aws
    if [[ $deploy_aws == "y" || $deploy_aws == "Y" ]]; then
        print_info "For detailed AWS deployment, see: docs/AWS_DEPLOYMENT.md"
        print_info "Or run: ./aws-deploy.sh"
    fi
    
    echo
}

print_completion_message() {
    print_header "Setup Complete! 🎉"
    
    echo
    print_success "Ansieyes is ready to use!"
    echo
    echo "Quick Start:"
    echo "  1. Start the bot: python3 app.py"
    echo "  2. Setup ngrok: ngrok http 3000"
    echo "  3. Update GitHub App webhook URL"
    echo "  4. Test with: @_ab_triage (on issue) or @_ab_prreview (on PR)"
    echo
    echo "Documentation:"
    echo "  - Complete Guide: COMPLETE_SETUP_GUIDE.md"
    echo "  - Configuration: triage.config.example.json"
    echo
    echo "Commands:"
    echo "  - @_ab_triage    - Issue triage (exact match only)"
    echo "  - @_ab_prreview  - PR review (exact match only)"
    echo
    print_info "Remember: Commands must be exact with no extra text!"
    echo
}

##############################################################################
# Main Menu
##############################################################################

show_menu() {
    print_header "Ansieyes Setup Script"
    
    echo "Choose your setup option:"
    echo
    echo "1) Complete Setup (Recommended)"
    echo "   - Install all dependencies"
    echo "   - Setup AI-Issue-Triage"
    echo "   - Configure environment"
    echo "   - Test setup"
    echo
    echo "2) Quick Setup (Dependencies already installed)"
    echo "   - Configure environment only"
    echo "   - Test setup"
    echo
    echo "3) AWS Deployment"
    echo "   - Deploy to AWS ECS"
    echo
    echo "4) Test Existing Setup"
    echo "   - Verify installation"
    echo
    echo "5) Exit"
    echo
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            complete_setup
            ;;
        2)
            quick_setup
            ;;
        3)
            deploy_to_aws
            ;;
        4)
            test_setup
            ;;
        5)
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            show_menu
            ;;
    esac
}

complete_setup() {
    check_prerequisites
    install_nodejs
    install_repomix
    setup_ai_issue_triage
    install_ansieyes_dependencies
    setup_github_app_instructions
    configure_environment
    test_setup
    start_with_ngrok
    print_completion_message
}

quick_setup() {
    configure_environment
    test_setup
    start_with_ngrok
    print_completion_message
}

##############################################################################
# Main Execution
##############################################################################

main() {
    clear
    
    print_header "Welcome to Ansieyes Setup!"
    
    echo "This script will help you set up Ansieyes with AI-powered"
    echo "PR review and issue triage capabilities."
    echo
    print_warning "Make sure you have:"
    echo "  - GitHub account with admin access"
    echo "  - Gemini API key ready"
    echo "  - (Optional) AWS account for deployment"
    echo
    read -p "Press Enter to continue..."
    
    show_menu
}

# Run main function
main


