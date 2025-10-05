# Firebase Setup Instructions

## Security Notice
The `firebase_options.dart` file contains sensitive API keys and should NOT be committed to version control.

## Setup Steps

1. **Copy the template file:**
   ```bash
   cp lib/firebase_options_template.dart lib/firebase_options.dart
   ```

2. **Replace the placeholder values in `firebase_options.dart` with your actual Firebase configuration:**
   - `YOUR_API_KEY_HERE` → Your Firebase API key
   - `your-project-id` → Your Firebase project ID
   - `YOUR_MESSAGING_SENDER_ID` → Your messaging sender ID
   - `YOUR_APP_ID` → Your Firebase app ID
   - `YOUR_MEASUREMENT_ID` → Your measurement ID (optional)

3. **Get your Firebase configuration:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to Project Settings → General
   - Scroll down to "Your apps" section
   - Click on the web app icon
   - Copy the configuration values

## Important Security Notes

- ✅ `firebase_options.dart` is already added to `.gitignore`
- ✅ Never commit real Firebase keys to version control
- ✅ Use environment variables for production deployments
- ✅ Consider using Firebase App Check for additional security

## For Production

For production deployments, consider using environment variables or a secure configuration management system instead of hardcoded values.
