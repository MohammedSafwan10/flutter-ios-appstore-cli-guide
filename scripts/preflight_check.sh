#!/usr/bin/env bash
# ==============================================================================
# Preflight Check Script for Flutter iOS App Store Release
# Validates host tools, environment variables, and credential paths.
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  Flutter iOS App Store Preflight Check   "
echo "=========================================="

ERRORS=0

# 1. Check Tools
echo -n "Checking Xcode CLI tools... "
if xcode-select -p >/dev/null 2>&1; then
  echo -e "${GREEN}OK${NC} ($(xcodebuild -version | head -n1))"
else
  echo -e "${RED}MISSING${NC} (Run: xcode-select --install)"
  ERRORS=$((ERRORS + 1))
fi

echo -n "Checking Flutter SDK... "
if command -v flutter >/dev/null 2>&1; then
  echo -e "${GREEN}OK${NC} ($(flutter --version | head -n1))"
else
  echo -e "${RED}MISSING${NC}"
  ERRORS=$((ERRORS + 1))
fi

echo -n "Checking CocoaPods... "
if command -v pod >/dev/null 2>&1; then
  echo -e "${GREEN}OK${NC} (v$(pod --version))"
else
  echo -e "${RED}MISSING${NC} (Run: brew install cocoapods or sudo gem install cocoapods)"
  ERRORS=$((ERRORS + 1))
fi

echo -n "Checking xcrun altool... "
if xcrun altool --version >/dev/null 2>&1; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${RED}MISSING${NC}"
  ERRORS=$((ERRORS + 1))
fi

echo -n "Checking FlutterFire CLI... "
if command -v flutterfire >/dev/null 2>&1; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${YELLOW}WARNING (Run: dart pub global activate flutterfire_cli)${NC}"
fi

# 2. Check Environment Variables / Credentials
echo ""
echo "Checking App Store Connect Credentials..."

# Load .env if present
if [ -f ".env" ]; then
  # shellcheck disable=SC1091
  source .env
fi

if [ -z "$APPSTORE_KEY_ID" ]; then
  echo -e "${RED}✗ APPSTORE_KEY_ID is not set${NC}"
  ERRORS=$((ERRORS + 1))
else
  echo -e "${GREEN}✓ APPSTORE_KEY_ID is configured${NC}"
fi

if [ -z "$APPSTORE_ISSUER_ID" ]; then
  echo -e "${RED}✗ APPSTORE_ISSUER_ID is not set${NC}"
  ERRORS=$((ERRORS + 1))
else
  echo -e "${GREEN}✓ APPSTORE_ISSUER_ID is configured${NC}"
fi

if [ -z "$APPSTORE_KEY_PATH" ]; then
  echo -e "${RED}✗ APPSTORE_KEY_PATH is not set${NC}"
  ERRORS=$((ERRORS + 1))
else
  if [ -f "$APPSTORE_KEY_PATH" ]; then
    echo -e "${GREEN}✓ Private key file exists at: $APPSTORE_KEY_PATH${NC}"
  else
    echo -e "${RED}✗ Key file NOT FOUND at: $APPSTORE_KEY_PATH${NC}"
    ERRORS=$((ERRORS + 1))
  fi
fi

if [ -z "$APPLE_TEAM_ID" ]; then
  echo -e "${YELLOW}! APPLE_TEAM_ID is not set (will attempt auto-detect from project)${NC}"
else
  echo -e "${GREEN}✓ APPLE_TEAM_ID is configured: $APPLE_TEAM_ID${NC}"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}All preflight checks passed! Ready to build and deploy.${NC}"
  exit 0
else
  echo -e "${RED}Preflight check failed with $ERRORS error(s). Please fix before building.${NC}"
  exit 1
fi
