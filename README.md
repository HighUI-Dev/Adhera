# Adhera

A new Flutter project.

## Deploy Web To Firebase Hosting

1. Build the web app:
   - `flutter build web --release`
2. Log in to Firebase CLI:
   - `firebase login`
3. Deploy:
   - `firebase deploy --only hosting`

### Notes

- Hosting is configured in `firebase.json` with:
  - `public: build/web`
  - SPA rewrite to `index.html`
- Default Firebase project alias is set in `.firebaserc`:
  - `tb-pneumo`
