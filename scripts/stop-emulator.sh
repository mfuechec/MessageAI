#!/bin/bash
# Stop Firebase Emulator

echo "🛑 Stopping Firebase Emulator..."

# Find and kill firebase emulator processes
pkill -f "firebase emulators:start" || echo "No emulator process found"

# Wait a moment
sleep 1

# Verify it's stopped
if curl -s http://localhost:8080 > /dev/null 2>&1; then
    echo "⚠️  Emulator still running (may need manual kill)"
else
    echo "✅ Emulator stopped successfully"
fi

