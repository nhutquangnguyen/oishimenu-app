#!/bin/bash

# Git Push All Changes Script
# This script stages all changes, commits them, and pushes to GitHub

echo "🔍 Checking git status..."
git status

echo ""
echo "📝 Staging all changes..."
git add .

echo ""
echo "📊 Checking what will be committed..."
git diff --cached --stat

echo ""
echo "💾 Creating commit..."
git commit -m "$(cat <<'EOF'
Enhance dashboard with analytics migration and chart grouping

- Move analytics charts from dashboard to Finance page
- Add chart grouping options (Hour, Day, Week day) to sales overview
- Implement smart y-axis scaling to prevent UI overlap
- Update best sellers to show only top 5 items by default
- Add dynamic revenue calculations for payment types and order sources
- Improve Finance page with time frame and branch filters
- Clean up dashboard layout for better focus on core metrics

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

echo ""
echo "📤 Pushing to GitHub..."
git push

echo ""
echo "✅ Git push completed successfully!"