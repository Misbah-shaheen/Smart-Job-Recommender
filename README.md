# Smart Job Recommender — Full Setup & Run Guide

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Mobile App | Flutter + Dart |
| State Management | Provider |
| Authentication | Firebase Auth |
| Database | Cloud Firestore |
| ML Backend | Python Flask + TF-IDF + Cosine Similarity |
| Dataset | Kaggle Job Description Dataset → preprocessed to JSON |

---

## Project Structure
```
smart_job_recommender/
├── lib/
│   ├── main.dart                  ← App entry, Firebase init, Provider setup
│   ├── models/
│   │   ├── job_model.dart         ← Job data class
│   │   └── user_profile_model.dart← User profile data class
│   ├── services/
│   │   ├── auth_service.dart      ← Firebase Auth wrapper
│   │   ├── profile_service.dart   ← Firestore read/write
│   │   ├── job_service.dart       ← JSON loader + Flask API caller
│   │   └── app_provider.dart      ← Central state (ChangeNotifier)
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── home_screen.dart       ← Bottom navigation shell
│   │   ├── job_search_screen.dart ← Search + Filters (local JSON)
│   │   ├── recommendation_screen.dart ← ML recommendations (Flask)
│   │   ├── skill_gap_screen.dart  ← Skill gap analyzer
│   │   └── profile_screen.dart    ← Profile management
│   ├── widgets/
│   │   ├── job_card.dart
│   │   └── filter_bottom_sheet.dart
│   └── utils/
│       ├── app_constants.dart     ← Flask URL, asset paths
│       └── app_theme.dart         ← Material 3 theme
├── assets/
│   └── data/
│       └── jobs.json              ← Pre-processed dataset (Flutter loads this)
├── backend/
│   ├── preprocess_dataset.py      ← Kaggle CSV → jobs.json
│   └── app.py                     ← Flask ML API
└── pubspec.yaml
```

---

## Why Flutter can't use Kaggle CSV directly

```
Kaggle CSV (raw data)
       │
       ▼  Python (preprocess_dataset.py)
       │  • Remove nulls
       │  • Lowercase skills
       │  • Normalize salary/experience
       │  • Select 6 key columns
       │
       ├──► jobs.json ──► Flutter assets/ ──► Job Search & Filters (offline)
       │
       └──► Same data served via Flask ──► /recommend (TF-IDF + Cosine Similarity)
```

Flutter is a mobile runtime — it has no pandas, no numpy, no Python.
The preprocessing script converts the CSV to typed JSON once.
Flutter loads it instantly from the APK bundle using `rootBundle.loadString()`.

---

## PART 1 — Firebase Setup

### Step 1: Create Firebase Project
1. Go to https://console.firebase.google.com
2. Click **Add project** → name it `smart-job-recommender`
3. Disable Google Analytics (optional) → Create project

### Step 2: Enable Authentication
1. In Firebase Console → **Authentication** → **Get started**
2. Click **Sign-in method** → Enable **Email/Password** → Save

### Step 3: Enable Firestore
1. Firebase Console → **Firestore Database** → **Create database**
2. Choose **Start in test mode** → Select your region → Done

### Step 4: Add Android App
1. Firebase Console → Project Overview → **Add app** → Android icon
2. Package name: `com.example.smart_job_recommender`
3. Download `google-services.json`
4. Place it in: `android/app/google-services.json`

### Step 5: Configure Android build files

**android/build.gradle** — add inside `buildscript > dependencies`:
```gradle
classpath 'com.google.gms:google-services:4.4.0'
```

**android/app/build.gradle** — add at bottom:
```gradle
apply plugin: 'com.google.gms.google-services'
```

Also ensure `minSdkVersion 21` (or higher) in `android/app/build.gradle`.

### Step 6: FlutterFire CLI (generates firebase_options.dart)
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# From your Flutter project root:
firebase login
flutterfire configure
# Select your project, tick Android (and iOS if needed)
# This auto-generates lib/firebase_options.dart
```

Then update `main.dart`:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

---

## PART 2 — Python Backend Setup

### Step 1: Install dependencies
```bash
cd backend/
pip install flask flask-cors scikit-learn pandas
```

### Step 2: (Optional) Download real Kaggle dataset
- Visit: https://www.kaggle.com/datasets/ravindrasinghrana/job-description-dataset
- Download CSV → rename to `job_descriptions.csv`
- Place in `backend/` folder

### Step 3: Preprocess dataset → generate jobs.json
```bash
python preprocess_dataset.py
```
Output: `jobs.json` (25 sample jobs, or your real Kaggle data)

### Step 4: Copy jobs.json to Flutter assets
```bash
cp jobs.json ../assets/data/jobs.json
```

### Step 5: Start Flask server
```bash
python app.py
```
You should see:
```
✅ TF-IDF matrix built: 25 jobs × 312 features
 * Running on http://0.0.0.0:5000
```

### Step 6: Test endpoints manually
```bash
# Health check
curl http://localhost:5000/health

# Recommendations
curl -X POST http://localhost:5000/recommend \
  -H "Content-Type: application/json" \
  -d '{"skills": ["flutter", "dart", "firebase"]}'

# Skill gap
curl -X POST http://localhost:5000/skill_gap \
  -H "Content-Type: application/json" \
  -d '{"user_skills": ["flutter", "dart"], "job_id": 1}'
```

---

## PART 3 — Flutter App Setup & Run

### Step 1: Install Flutter packages
```bash
flutter pub get
```

### Step 2: Configure Flask URL (IMPORTANT)
Open `lib/utils/app_constants.dart`:

```dart
// For Android EMULATOR (emulator treats 10.0.2.2 as your PC's localhost):
static const String flaskBaseUrl = 'http://10.0.2.2:5000';

// For PHYSICAL DEVICE on same WiFi:
// Find your PC's local IP: run `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
// static const String flaskBaseUrl = 'http://192.168.1.XXX:5000';
```

### Step 3: Run in Android Studio
1. Open Android Studio → Open the `smart_job_recommender` folder
2. Wait for Gradle sync to finish
3. Open AVD Manager → Start an Android emulator (API 30+)
   OR plug in a physical Android device with USB debugging ON
4. Click the **Run ▶** button (or press `Shift+F10`)

### Step 4: Run from terminal
```bash
flutter devices          # lists available devices
flutter run              # runs on connected device/emulator
flutter run --release    # production build (faster)
```

---

## PART 4 — Android permissions (for network)

Ensure `android/app/src/main/AndroidManifest.xml` has:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
It's usually there by default. Also for HTTP (not HTTPS) on Android 9+, add inside `<application>`:
```xml
android:usesCleartextTraffic="true"
```

---

## PART 5 — How ML Recommendations Work

```
User Profile (skills: ["flutter", "dart", "firebase"])
        │
        ▼  HTTP POST /recommend  (job_service.dart)
Flask Backend (app.py)
        │
        ├─ TF-IDF Vectorizer fitted on all 25 job descriptions + skills
        │   Each job becomes a vector of word importance weights
        │
        ├─ User skills → transformed into same TF-IDF vector space
        │
        ├─ Cosine Similarity computed between user vector & all job vectors
        │   similarity = (A · B) / (|A| × |B|)  → range [0, 1]
        │
        └─ Top-5 jobs sorted by similarity → returned with match_percentage
        │
        ▼  Flutter parses JSON → displays in recommendation_screen.dart
```

---

## PART 6 — Firestore Data Structure

```
users/                          (collection)
  └── {uid}/                    (document = user's Firebase UID)
        name: "Ahmed Khan"
        email: "ahmed@gmail.com"
        skills: ["flutter", "dart", "firebase"]
        experience: 2
        preferred_role: "Flutter Developer"
```

---

## Common Issues & Fixes

| Problem | Fix |
|---------|-----|
| `google-services.json not found` | Place it in `android/app/` not project root |
| `Connection refused` on emulator | Use `10.0.2.2:5000` not `localhost:5000` |
| `Connection refused` on real device | Use your PC's LAN IP (e.g. `192.168.1.5:5000`) |
| `Cleartext HTTP not permitted` | Add `android:usesCleartextTraffic="true"` to AndroidManifest |
| `minSdkVersion` error | Set `minSdkVersion 21` in android/app/build.gradle |
| `firebase_options.dart missing` | Run `flutterfire configure` |
| Flask `jobs.json not found` | Run `python preprocess_dataset.py` first |
| Skill gap shows empty | Make sure Flask is running; app falls back to local compute |

---

## Running Everything Together (Checklist)

```
[ ] 1. Firebase project created + google-services.json in android/app/
[ ] 2. flutterfire configure run → firebase_options.dart generated
[ ] 3. cd backend && python preprocess_dataset.py  → jobs.json created
[ ] 4. cp backend/jobs.json assets/data/jobs.json
[ ] 5. python backend/app.py  → Flask running on :5000
[ ] 6. flutter pub get
[ ] 7. flutter run  (emulator or device)
[ ] 8. Sign up → add skills in Profile → tap "For You" tab for ML recommendations
```
