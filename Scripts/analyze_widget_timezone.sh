#!/bin/bash

# Script to analyze widget console logs for timezone mismatches
# Usage: ./Scripts/analyze_widget_timezone.sh <console_log_file.txt>
# Or pipe logs: xcodebuild ... | ./Scripts/analyze_widget_timezone.sh

echo "🔍 Widget Timezone Mismatch Analyzer"
echo "===================================="
echo ""

# Read from stdin if no file provided, otherwise read from file
if [ -z "$1" ]; then
    INPUT="-"
    echo "Reading from stdin (pipe logs here)..."
else
    INPUT="$1"
    echo "Reading from file: $1"
fi

echo ""
echo "Looking for 'Today:' lines in widget logs..."
echo ""

# Extract "Today:" lines and analyze
grep -E "(Today:|formatDateKey:|completionStatus keys:)" "$INPUT" | while IFS= read -r line; do
    if [[ $line == *"Today:"* ]]; then
        echo "📅 Found timestamp: $line"
        
        # Extract the date string (format: 2026-01-12 18:30:00 +0000)
        if [[ $line =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ \+[0-9]{4}) ]]; then
            timestamp="${BASH_REMATCH[1]}"
            echo "   Extracted: $timestamp"
            echo ""
            echo "   Calculating date keys..."
            
            # Parse the timestamp (assuming UTC format)
            year=$(echo "$timestamp" | cut -d'-' -f1)
            month=$(echo "$timestamp" | cut -d'-' -f2)
            day=$(echo "$timestamp" | cut -d' ' -f1 | cut -d'-' -f3)
            hour=$(echo "$timestamp" | cut -d' ' -f2 | cut -d':' -f1)
            minute=$(echo "$timestamp" | cut -d' ' -f2 | cut -d':' -f2)
            
            # Calculate UTC date key (what widget generates)
            utc_date_key="${year}-${month}-${day}"
            
            # For Amsterdam (UTC+1), add 1 hour
            # This is simplified - in reality we'd need proper timezone conversion
            amsterdam_hour=$((10#$hour + 1))
            if [ $amsterdam_hour -ge 24 ]; then
                amsterdam_hour=$((amsterdam_hour - 24))
                # Next day
                amsterdam_day=$((10#$day + 1))
                # Simple month/day rollover (not handling month/year boundaries)
                if [ $amsterdam_day -lt 10 ]; then
                    amsterdam_day="0$amsterdam_day"
                fi
                amsterdam_date_key="${year}-${month}-${amsterdam_day}"
            else
                amsterdam_date_key="$utc_date_key"
            fi
            
            echo "   📱 APP (Amsterdam UTC+1):   '$amsterdam_date_key'"
            echo "   📦 WIDGET (UTC):            '$utc_date_key'"
            
            if [ "$amsterdam_date_key" != "$utc_date_key" ]; then
                echo ""
                echo "   ⚠️  MISMATCH! Widget will look for '$utc_date_key' but app stored '$amsterdam_date_key'"
            else
                echo ""
                echo "   ✅ Keys match"
            fi
            echo ""
        fi
    elif [[ $line == *"completionStatus keys:"* ]]; then
        echo "📦 Stored keys (from app): $line"
    elif [[ $line == *"formatDateKey:"* ]]; then
        echo "🔧 Generated key (by widget): $line"
    fi
done

echo ""
echo "===================================="
echo "Analysis complete!"
echo ""
echo "Look for lines showing:"
echo "  - 'completionStatus keys:' = What the app stored"
echo "  - 'formatDateKey:' = What the widget is generating"
echo ""
echo "If they don't match, that's the timezone mismatch bug!"
