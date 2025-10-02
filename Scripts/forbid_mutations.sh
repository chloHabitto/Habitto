#!/bin/bash

# Script to enforce invariant: Only XPService/DailyAwardService can mutate XP/level/streak/isCompleted
# This script fails the build if forbidden patterns are found outside allowed services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Checking for forbidden XP/level/streak/isCompleted mutations..."

# Define CRITICAL forbidden patterns (actual mutations, not reads)
# Note: These patterns exclude commented lines and variable declarations
CRITICAL_PATTERNS=(
    '^[^/]*xp\s*\+\=.*[^=]'  # Direct XP increments (not comparisons, not comments)
    '^[^/]*level\s*\+\=.*[^=]'  # Direct level increments (not comparisons, not comments)
    '^[^/]*streak\s*\+\=.*[^=]'  # Direct streak increments (not comparisons, not comments)
    '^[^/]*isCompleted\s*=\s*true'  # Direct completion assignments (not comments)
    '^[^/]*isCompleted\s*=\s*false'  # Direct completion assignments (not comments)
)

# Define allowed paths (services that can mutate XP/level)
ALLOWED_PATHS=(
    'Core/Services/XPService.swift'
    'Core/Services/DailyAwardService.swift'
    'Core/Services/StreakService.swift'
    'Core/Services/MigrationRunner.swift'
    'Tests/'
    'Scripts/'
    '.git/'
)

# Build exclude pattern for find command
EXCLUDE_PATTERN=""
for path in "${ALLOWED_PATHS[@]}"; do
    EXCLUDE_PATTERN="$EXCLUDE_PATTERN -not -path */$path"
done

# Track violations
VIOLATIONS=0
TOTAL_FILES=0

# Check each critical pattern
for pattern in "${CRITICAL_PATTERNS[@]}"; do
    echo "  Checking critical pattern: $pattern"
    
    # Find Swift files, excluding allowed paths
    FILES=$(find . -name "*.swift" $EXCLUDE_PATTERN 2>/dev/null || true)
    
    if [ -z "$FILES" ]; then
        echo "    ✅ No Swift files found to check"
        continue
    fi
    
    # Check each file for the pattern
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            TOTAL_FILES=$((TOTAL_FILES + 1))
            
            # Use grep to find matches (case insensitive)
            if grep -qi "$pattern" "$file" 2>/dev/null; then
                echo "    ${RED}❌ CRITICAL VIOLATION found in: $file${NC}"
                
                # Show the violating lines
                grep -ni "$pattern" "$file" 2>/dev/null | while IFS= read -r line; do
                    echo "      ${YELLOW}Line: $line${NC}"
                done
                
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        fi
    done <<< "$FILES"
done

echo ""
echo "📊 Summary:"
echo "  Files checked: $TOTAL_FILES"
echo "  Critical violations found: $VIOLATIONS"

if [ $VIOLATIONS -eq 0 ]; then
    echo "  ${GREEN}✅ All critical checks passed! No forbidden mutations found.${NC}"
    exit 0
else
    echo "  ${RED}❌ Build failed: $VIOLATIONS critical mutation(s) found.${NC}"
    echo ""
    echo "🚨 These CRITICAL patterns are forbidden outside XPService/DailyAwardService:"
    printf "  - %s\n" "${CRITICAL_PATTERNS[@]}"
    echo ""
    echo "💡 To fix:"
    echo "  1. Move XP/level/streak mutations to XPService or DailyAwardService"
    echo "  2. Use computed properties instead of stored denormalized fields"
    echo "  3. Route all mutations through the centralized services"
    exit 1
fi