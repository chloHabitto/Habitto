#!/bin/bash

# Reset StoreKit Test Transactions
# This script helps clear StoreKit test data

echo "🔧 StoreKit Reset Tool"
echo "====================="
echo ""

# Check if we're on a simulator or device
if [ -z "$SIMULATOR_DEVICE_ID" ]; then
    echo "📱 Available iOS Simulators:"
    echo ""
    xcrun simctl list devices | grep -E "iPhone|iPad" | grep -v "unavailable" | head -5
    echo ""
    echo "Choose an option:"
    echo "1. Reset ALL simulators (⚠️ deletes all data)"
    echo "2. Reset specific simulator"
    echo "3. Exit"
    echo ""
    read -p "Enter choice (1-3): " choice
    
    case $choice in
        1)
            echo "🔄 Resetting ALL simulators..."
            xcrun simctl erase all
            echo "✅ All simulators reset!"
            ;;
        2)
            echo ""
            echo "Enter device ID (from list above):"
            read device_id
            if [ ! -z "$device_id" ]; then
                echo "🔄 Resetting simulator: $device_id"
                xcrun simctl erase "$device_id"
                echo "✅ Simulator reset!"
            else
                echo "❌ Invalid device ID"
            fi
            ;;
        3)
            echo "❌ Cancelled"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice"
            exit 1
            ;;
    esac
fi

echo ""
echo "📝 Next steps:"
echo "1. In Xcode: Product → Clean Build Folder (Cmd+Shift+K)"
echo "2. Restart Xcode (optional but recommended)"
echo "3. Rebuild and run the app"
echo "4. In app: More Tab → Debug Tools → '🔄 Reset Premium Status'"
echo "5. Verify: More Tab → Debug Tools → '🔍 Verify Purchase Status'"
echo "6. Make a fresh test purchase"
echo ""

