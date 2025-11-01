#!/bin/bash

# Log Analyzer Script for Habitto App
# Analyzes console logs for expected patterns

LOG_FILE="${1:-console_logs.txt}"

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ Error: Log file '$LOG_FILE' not found"
    echo "Usage: $0 [log_file.txt]"
    echo "If no file specified, defaults to 'console_logs.txt'"
    exit 1
fi

echo "📊 Analyzing console logs from: $LOG_FILE"
echo "=========================================="
echo ""

# Check for critical success indicators
echo "✅ CRITICAL SUCCESS INDICATORS:"
echo ""

# App Initialization
if grep -q "🚀 AppDelegate: INIT CALLED" "$LOG_FILE"; then
    echo "   ✅ App initialization: FOUND"
else
    echo "   ❌ App initialization: NOT FOUND"
fi

# Firebase Configuration
if grep -q "✅ AppDelegate: Firebase configured" "$LOG_FILE"; then
    echo "   ✅ Firebase configuration: FOUND"
elif grep -q "✅ AppDelegate: Firebase already configured" "$LOG_FILE"; then
    echo "   ✅ Firebase configuration: FOUND (already configured)"
else
    echo "   ❌ Firebase configuration: NOT FOUND"
fi

# User Authentication
if grep -q "✅ SyncEngine: User authenticated - uid:" "$LOG_FILE"; then
    USER_ID=$(grep "✅ SyncEngine: User authenticated - uid:" "$LOG_FILE" | head -1 | sed 's/.*uid: //')
    echo "   ✅ User authentication: FOUND (uid: $USER_ID)"
else
    echo "   ❌ User authentication: NOT FOUND"
fi

echo ""
echo "🔄 MIGRATION STATUS:"
echo ""

# Guest to Auth Migration
if grep -q "✅ Guest data already migrated for user:" "$LOG_FILE" || grep -q "✅ Guest to auth migration complete!" "$LOG_FILE"; then
    echo "   ✅ Guest to Auth migration: COMPLETED"
else
    echo "   ⚠️  Guest to Auth migration: NOT FOUND or IN PROGRESS"
fi

# Completion Status Migration
if grep -q "🔄 MIGRATION: Completion status migration already completed" "$LOG_FILE" || grep -q "🔄 MIGRATION: Completion status migration completed successfully" "$LOG_FILE"; then
    echo "   ✅ Completion Status migration: COMPLETED"
else
    echo "   ⚠️  Completion Status migration: NOT FOUND or IN PROGRESS"
fi

# Completions to Events Migration
if grep -q "🔄 MIGRATION: Completion to Event migration already completed" "$LOG_FILE" || grep -q "✅ MIGRATION: Successfully migrated.*completion records to events" "$LOG_FILE"; then
    echo "   ✅ Completions to Events migration: COMPLETED"
else
    echo "   ⚠️  Completions to Events migration: NOT FOUND or IN PROGRESS"
fi

# XP Data Migration
if grep -q "🔄 XPDataMigration: Migration already completed, skipping" "$LOG_FILE" || grep -q "✅ XP_MIGRATION_COMPLETE: All data migrated successfully" "$LOG_FILE"; then
    echo "   ✅ XP Data migration: COMPLETED"
else
    echo "   ⚠️  XP Data migration: NOT FOUND or IN PROGRESS"
fi

echo ""
echo "🔄 SYNC ENGINE STATUS:"
echo ""

# Sync Engine Startup
if grep -q "✅ SyncEngine: startPeriodicSync() call completed" "$LOG_FILE"; then
    echo "   ✅ Sync Engine startup: COMPLETED"
else
    if grep -q "⏭️ SyncEngine: Skipping sync for guest user" "$LOG_FILE"; then
        echo "   ℹ️  Sync Engine: SKIPPED (guest user)"
    else
        echo "   ⚠️  Sync Engine startup: NOT FOUND"
    fi
fi

# Event Compaction
if grep -q "✅ EventCompactor: Scheduling completed" "$LOG_FILE"; then
    echo "   ✅ Event Compaction scheduling: COMPLETED"
else
    echo "   ⚠️  Event Compaction scheduling: NOT FOUND"
fi

echo ""
echo "⚠️  ERROR CHECK:"
echo ""

ERROR_COUNT=0

if grep -q "❌ SyncEngine: Failed to authenticate user" "$LOG_FILE"; then
    echo "   ❌ Authentication error detected"
    ERROR_COUNT=$((ERROR_COUNT + 1))
fi

if grep -q "⚠️ Guest data migration failed" "$LOG_FILE"; then
    echo "   ❌ Guest data migration error detected"
    ERROR_COUNT=$((ERROR_COUNT + 1))
fi

if grep -q "❌ MIGRATION: Failed to" "$LOG_FILE"; then
    echo "   ❌ Migration error detected"
    ERROR_COUNT=$((ERROR_COUNT + 1))
fi

if grep -q "❌ SyncEngine: Failed to" "$LOG_FILE"; then
    echo "   ❌ Sync engine error detected"
    ERROR_COUNT=$((ERROR_COUNT + 1))
fi

if [ $ERROR_COUNT -eq 0 ]; then
    echo "   ✅ No errors detected"
else
    echo ""
    echo "   ⚠️  Found $ERROR_COUNT error(s) - Review logs for details"
fi

echo ""
echo "=========================================="
echo ""
echo "📋 SUMMARY:"
echo ""

# Count success indicators
SUCCESS_COUNT=0
TOTAL_CHECKS=8

grep -q "🚀 AppDelegate: INIT CALLED" "$LOG_FILE" && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
(grep -q "✅ AppDelegate: Firebase configured" "$LOG_FILE" || grep -q "✅ AppDelegate: Firebase already configured" "$LOG_FILE") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
grep -q "✅ SyncEngine: User authenticated - uid:" "$LOG_FILE" && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
(grep -q "✅ Guest data already migrated" "$LOG_FILE" || grep -q "✅ Guest to auth migration complete" "$LOG_FILE") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
(grep -q "🔄 MIGRATION: Completion status migration.*completed" "$LOG_FILE") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
(grep -q "🔄 MIGRATION: Completion to Event migration already completed" "$LOG_FILE" || grep -q "✅ MIGRATION: Successfully migrated.*completion records to events" "$LOG_FILE") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
(grep -q "🔄 XPDataMigration: Migration already completed" "$LOG_FILE" || grep -q "✅ XP_MIGRATION_COMPLETE" "$LOG_FILE") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
(grep -q "✅ SyncEngine: startPeriodicSync() call completed" "$LOG_FILE" || grep -q "⏭️ SyncEngine: Skipping sync for guest user" "$LOG_FILE") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

echo "   Success Indicators: $SUCCESS_COUNT/$TOTAL_CHECKS"
echo "   Errors Found: $ERROR_COUNT"

if [ $SUCCESS_COUNT -eq $TOTAL_CHECKS ] && [ $ERROR_COUNT -eq 0 ]; then
    echo ""
    echo "   🎉 ALL CHECKS PASSED! Implementation appears to be working correctly."
else
    echo ""
    echo "   ⚠️  Some checks failed. Review the output above for details."
fi

echo ""

