#!/bin/bash
# Check if Firebase Emulator is running

if curl -s http://localhost:8080 > /dev/null 2>&1; then
    echo "✅ Firebase Emulator is RUNNING"
    echo "   - Firestore: http://localhost:8080"
    echo "   - Auth: http://localhost:9099"
    echo "   - UI: http://localhost:4000"
    exit 0
else
    echo "❌ Firebase Emulator is NOT running"
    echo ""
    echo "To start it:"
    echo "  ./scripts/start-emulator.sh"
    echo ""
    echo "Or run in background:"
    echo "  ./scripts/start-emulator.sh > /dev/null 2>&1 &"
    exit 1
fi

