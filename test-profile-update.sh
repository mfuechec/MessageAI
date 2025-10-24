#!/bin/bash

# Manually call the updateUserNotificationProfileManual Cloud Function
# for tester2@gmail.com to generate their AI profile

echo "========================================="
echo "Triggering AI Profile Update"
echo "========================================="
echo ""
echo "User: tester2@gmail.com"
echo "User ID: v64FPlQvfWTblskskM9z6nkaj3b2"
echo ""

# Call the Cloud Function
# Note: This requires the user to be authenticated, so we'll use curl with Firebase Auth token
# For testing, we'll use the Firebase CLI to call it directly

firebase functions:shell --project messageai-dev-1f2ec
