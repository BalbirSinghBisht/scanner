# Free-plan Firebase setup

This project uses Firebase Authentication and Firestore directly. It does not
require Cloud Functions or the Blaze plan.

In Firebase project `scanner-f2add`:

1. Create a Firestore database.
2. Enable Authentication > Email/Password.
3. Enable Authentication > Anonymous.
4. Create the single administrator user `balbirbisht372@gmail.com` with a
   private password.
5. Deploy the repository's `firestore.rules` and `firestore.indexes.json`.

The normal app signs in anonymously and may update only its own device record.
The administrator email can list devices and queue commands. Commands are
received immediately while the mobile process is alive and remain queued for
the next background cycle when it is suspended or offline.

Google Drive browsing requires enabling the Google provider, Drive API, and an
OAuth Android client for `com.mediabackup.scanner_admin`. Never embed or commit
the shared Drive refresh token in the admin app.
