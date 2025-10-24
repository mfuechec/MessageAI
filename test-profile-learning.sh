#!/bin/bash

echo "========================================="
echo "TEST AI LEARNING PROFILE UPDATE"
echo "========================================="
echo ""
echo "This will analyze your feedback and update your AI profile"
echo "Based on your 4 feedback submissions"
echo ""

# Call the manual profile update function
firebase functions:shell --project messageai-dev-1f2ec
