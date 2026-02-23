# Configure Firebase for Khono Recruite

Your backend already uses the Firebase project **automated-recruitment-workflow**. Use the same project for the Flutter app.

---

## Option A: FlutterFire CLI (recommended)

**You must install the Firebase CLI first** (FlutterFire depends on it).

1. **Install Node.js** if needed, then install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. **Log in to Firebase**:
   ```bash
   firebase login
   ```

3. **Install FlutterFire CLI** (one-time):
   ```bash
   dart pub global activate flutterfire_cli
   ```
   On Windows, add the Dart global cache to your PATH if needed:
   `C:\Users\<You>\AppData\Local\Pub\Cache\bin`

4. **From the Flutter project folder** (`khono_recruite`):
   ```bash
   cd khono_recruite
   flutterfire configure
   ```

5. When prompted:
   - Select **Use an existing project** → **automated-recruitment-workflow**
   - Select **Web** (and any other platforms you need)
   - The CLI will overwrite `lib/firebase_options.dart` with your API keys

6. Run the app:
   ```bash
   flutter run -d chrome
   ```

---

## Option B: Manual (paste from Firebase Console)

1. Open your project’s **Project settings** in Firebase Console:
   - **https://console.firebase.google.com/project/automated-recruitment-workflow/settings/general**

2. Under **Your apps**, select your **Web** app (or click **Add app** → **Web** `</>` and register it).

3. Copy the config values (e.g. from “SDK setup and configuration” / `firebaseConfig`):
   - **apiKey**
   - **appId**
   - **messagingSenderId**
   - **authDomain** (e.g. `automated-recruitment-workflow.firebaseapp.com`)
   - **storageBucket** (e.g. `automated-recruitment-workflow.appspot.com`)

4. Open **`lib/firebase_options.dart`** and paste:
   - **apiKey** → `apiKey: 'YOUR_API_KEY'`
   - **appId** → `appId: 'YOUR_APP_ID'`
   - **messagingSenderId** → `messagingSenderId: 'YOUR_SENDER_ID'`
   - **authDomain** and **storageBucket** are already set for this project; replace them if your Console shows different values.

5. Run the app:
   ```bash
   flutter run -d chrome
   ```

---

After configuration, the app will use Firebase Auth and Firebase AI (Gemini) when the API key is valid.
