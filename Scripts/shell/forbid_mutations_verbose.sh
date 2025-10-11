#!/bin/bash

# Verbose version of the invariant enforcement script
# Shows which files were scanned and which were ignored by allowlist

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔍 VERBOSE: Checking for forbidden XP/level/streak/isCompleted mutations..."
echo ""

# Define CRITICAL forbidden patterns (actual mutations, not reads)
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

echo "📋 ALLOWED PATHS (excluded from scanning):"
for path in "${ALLOWED_PATHS[@]}"; do
    echo "  ✅ $path"
done
echo ""

# Build exclude pattern for find command
EXCLUDE_PATTERN=""
for path in "${ALLOWED_PATHS[@]}"; do
    EXCLUDE_PATTERN="$EXCLUDE_PATTERN -not -path */$path"
done

# Track violations
VIOLATIONS=0
TOTAL_FILES=0
SCANNED_FILES=0
IGNORED_FILES=0

# First, let's show which files were found and which were ignored
echo "📁 FILE DISCOVERY:"
echo ""

ALL_FILES=$(find . -name "*.swift" 2>/dev/null | wc -l)
ALLOWED_FILES=$(find . -name "*.swift" $EXCLUDE_PATTERN 2>/dev/null | wc -l)
SCANNED_FILES=$((ALL_FILES - ALLOWED_FILES))

echo "  📊 Total Swift files found: $ALL_FILES"
echo "  ✅ Files allowed (excluded): $ALLOWED_FILES"
echo "  🔍 Files scanned for violations: $SCANNED_FILES"
echo ""

echo "📋 SAMPLE OF SCANNED FILES:"
find . -name "*.swift" $EXCLUDE_PATTERN 2>/dev/null | head -10 | while read file; do
    echo "  🔍 $file"
done
if [ $SCANNED_FILES -gt 10 ]; then
    echo "  ... and $((SCANNED_FILES - 10)) more files"
fi
echo ""

echo "📋 SAMPLE OF IGNORED FILES (allowed paths):"
find . -name "*.swift" -path "*/Tests/*" -o -name "*.swift" -path "*/Core/Services/*" 2>/dev/null | head -5 | while read file; do
    echo "  ✅ $file"
done
echo ""

# Check each critical pattern
echo "🔍 PATTERN SCANNING:"
echo ""

for pattern in "${CRITICAL_PATTERNS[@]}"; do
    echo "  🎯 Checking pattern: $pattern"
    
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
echo "📊 VERBOSE SUMMARY:"
echo "  Files checked: $TOTAL_FILES"
echo "  Critical violations found: $VIOLATIONS"
echo "  Allowed files excluded: $ALLOWED_FILES"
echo "  Total Swift files in project: $ALL_FILES"

if [ $VIOLATIONS -eq 0 ]; then
    echo "  ${GREEN}✅ All critical checks passed! No forbidden mutations found.${NC}"
    exit 0
else
    echo "  ${RED}❌ Build failed: $VIOLATIONS critical mutation(s) found.${NC}"
    exit 1
fi
