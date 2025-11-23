#!/bin/bash

# Clear StoreKit Test Transactions
# This script helps reset StoreKit test data for development

echo "🔧 StoreKit Transaction Reset Tool"
echo "=================================="
echo ""

# Check if running on simulator
if [ -z "$SIMULATOR_DEVICE_ID" ]; then
    echo "📱 Available iOS Simulators:"
    echo ""
    xcrun simctl list devices | grep -i "iphone\|ipad" | grep -v "unavailable"
    echo ""
    echo "To reset a specific simulator, run:"
    echo "  xcrun simctl erase <DEVICE_ID>"
    echo ""
    echo "To reset ALL simulators (⚠️ deletes all data):"
    echo "  xcrun simctl erase all"
    echo ""
    echo "⚠️  WARNING: This will delete ALL data from the simulator(s)"
    echo ""
    read -p "Do you want to reset ALL simulators? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Resetting all simulators..."
        xcrun simctl erase all
        echo "✅ All simulators reset!"
    else
        echo "❌ Cancelled"
    fi
else
    echo "🔄 Resetting simulator: $SIMULATOR_DEVICE_ID"
    xcrun simctl erase "$SIMULATOR_DEVICE_ID"
    echo "✅ Simulator reset!"
fi

echo ""
echo "📝 Next steps:"
echo "1. Restart Xcode"
echo "2. Clean build folder (Cmd+Shift+K)"
echo "3. Rebuild and run the app"
echo "4. Use 'Reset Premium Status' button in debug menu"
echo "5. Make a fresh test purchase"

