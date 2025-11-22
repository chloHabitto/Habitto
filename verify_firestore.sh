#!/bin/bash

# Quick Firestore Verification Script
# Usage: ./verify_firestore.sh [firebase-uid]
# Example: ./verify_firestore.sh fQVQZ0ch8uYsR6sSlvxf5BG3iUe2

FIREBASE_UID="${1:-fQVQZ0ch8uYsR6sSlvxf5BG3iUe2}"

echo "🔍 Verifying Firestore data for UID: $FIREBASE_UID"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Install it with: npm install -g firebase-tools"
    echo ""
    echo "📋 Manual Verification Steps:"
    echo "   1. Go to: https://console.firebase.google.com/"
    echo "   2. Select your project"
    echo "   3. Go to: Firestore Database"
    echo "   4. Navigate to: users/$FIREBASE_UID/"
    echo "   5. Check for: events/, completions/, daily_awards/"
    exit 1
fi

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    echo "⚠️  Not logged into Firebase CLI"
    echo "   Run: firebase login"
    exit 1
fi

echo "✅ Firebase CLI found"
echo ""

# Get project ID from firebase.json or .firebaserc
PROJECT_ID=""
if [ -f ".firebaserc" ]; then
    PROJECT_ID=$(grep -o '"default": "[^"]*"' .firebaserc | cut -d'"' -f4)
elif [ -f "firebase.json" ]; then
    # Try to get from firebase.json or ask user
    echo "⚠️  Could not auto-detect project ID"
    read -p "Enter your Firebase project ID: " PROJECT_ID
fi

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Could not determine Firebase project ID"
    echo "   Please check manually in Firebase Console"
    exit 1
fi

echo "📊 Checking Firestore data..."
echo "   Project: $PROJECT_ID"
echo "   User ID: $FIREBASE_UID"
echo ""

# Check if user document exists
echo "1️⃣  Checking user document..."
USER_DOC=$(firebase firestore:get "users/$FIREBASE_UID" --project "$PROJECT_ID" 2>&1)
if echo "$USER_DOC" | grep -q "Document not found"; then
    echo "   ❌ User document not found: users/$FIREBASE_UID"
else
    echo "   ✅ User document exists: users/$FIREBASE_UID"
fi

# Check events collection
echo ""
echo "2️⃣  Checking events collection..."
EVENTS_COUNT=$(firebase firestore:get "users/$FIREBASE_UID/events" --project "$PROJECT_ID" 2>&1 | grep -c "Document ID" || echo "0")
if [ "$EVENTS_COUNT" -gt 0 ]; then
    echo "   ✅ Events found: $EVENTS_COUNT year-month collections"
else
    echo "   ⚠️  No events found (this is OK if you haven't created/completed habits yet)"
fi

# Check completions collection
echo ""
echo "3️⃣  Checking completions collection..."
COMPLETIONS=$(firebase firestore:get "users/$FIREBASE_UID/completions" --project "$PROJECT_ID" 2>&1)
if echo "$COMPLETIONS" | grep -q "Document not found\|No documents found"; then
    echo "   ⚠️  No completions found (this is OK if you haven't completed habits yet)"
else
    COMPLETIONS_COUNT=$(echo "$COMPLETIONS" | grep -c "Document ID" || echo "0")
    echo "   ✅ Completions found: $COMPLETIONS_COUNT documents"
fi

# Check daily_awards collection
echo ""
echo "4️⃣  Checking daily_awards collection..."
AWARDS=$(firebase firestore:get "users/$FIREBASE_UID/daily_awards" --project "$PROJECT_ID" 2>&1)
if echo "$AWARDS" | grep -q "Document not found\|No documents found"; then
    echo "   ⚠️  No awards found (this is OK if you haven't earned XP yet)"
else
    AWARDS_COUNT=$(echo "$AWARDS" | grep -c "Document ID" || echo "0")
    echo "   ✅ Awards found: $AWARDS_COUNT documents"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Summary:"
echo "   User Document: users/$FIREBASE_UID"
echo ""
echo "💡 Quick Firebase Console Check:"
echo "   https://console.firebase.google.com/project/$PROJECT_ID/firestore/data/~2Fusers~2F$FIREBASE_UID"
echo ""
echo "✅ If you see data in any collection above, Phase 1 is working!"
echo ""

