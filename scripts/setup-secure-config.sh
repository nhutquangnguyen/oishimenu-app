#!/bin/bash

# Script to copy secure configuration files to their expected locations
# This should be run before building the app

echo "Setting up secure configuration files..."

# Check if secure config directory exists
if [ ! -d "config/secure" ]; then
    echo "❌ Error: config/secure directory not found!"
    echo "Please copy your configuration files to:"
    echo "  - config/secure/google-services.json"
    echo "  - config/secure/key.properties"
    echo "  - config/secure/.env (if different from root .env)"
    exit 1
fi

# Copy google-services.json
if [ -f "config/secure/google-services.json" ]; then
    cp config/secure/google-services.json android/app/google-services.json
    echo "✅ Copied google-services.json"
else
    echo "⚠️  Warning: config/secure/google-services.json not found"
fi

# Copy key.properties
if [ -f "config/secure/key.properties" ]; then
    cp config/secure/key.properties android/key.properties
    echo "✅ Copied key.properties"
else
    echo "⚠️  Warning: config/secure/key.properties not found"
fi

echo "🔒 Secure configuration setup complete!"
echo "Remember: These files are git-ignored for security"