#!/bin/bash
# Start Firebase Emulator Suite

echo "🔥 Starting Firebase Emulator Suite..."
echo ""
echo "Emulators will be available at:"
echo "  - Auth: http://localhost:9099"
echo "  - Firestore: http://localhost:8080"
echo "  - Storage: http://localhost:9199"
echo "  - Emulator UI: http://localhost:4000"
echo ""

firebase emulators:start --import=./emulator-data --export-on-exit

