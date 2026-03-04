# EmoTune: Sentiment-Driven AI Music Recommender
## Complete Setup & Documentation

---

## 📋 Project Overview

EmoTune is a full-stack mobile application that analyzes user emotions from text using a fine-tuned BERT model and recommends Spotify playlists tailored to their emotional state. The app adapts to user preferences over time and includes features for emotional well-being tracking.

**Tech Stack:**
- **Frontend:** Flutter (Dart) — runs on Android, iOS, and Web
- **Backend:** Python (Django REST Framework)
- **ML Model:** BERT (bert-base-uncased) fine-tuned for 13 emotion categories
- **Music API:** Spotify Web API
- **Database:** SQLite (dev) / PostgreSQL (production)

---

## 🗂 Project Structure

```
emotune/
├── backend/                    # Django backend
│   ├── emotune_project/        # Django project settings
│   ├── api/                    # Main API views + Spotify service
│   ├── users/                  # User models, auth, favorites, history
│   ├── ml/                     # BERT emotion classifier
│   │   ├── emotion_classifier.py
│   │   └── models/             # Saved BERT model (after training)
│   └── requirements.txt
│
├── flutter_app/                # Flutter frontend
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── theme/              # Light/Dark theme
│   │   ├── providers/          # State management (Provider)
│   │   ├── services/           # API service
│   │   └── screens/            # All app screens
│   └── pubspec.yaml
│
├── ml_model/
│   └── train_bert.py           # BERT training script
│
└── docs/
    └── SETUP.md                # This file
```

---

## ⚙️ BACKEND SETUP

### 1. Prerequisites
- Python 3.10+
- pip

### 2. Create Virtual Environment
```bash
cd emotune/backend
python -m venv venv

# Windows:
venv\Scripts\activate

# Mac/Linux:
source venv/bin/activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

### 4. Run Migrations
```bash
python manage.py makemigrations users
python manage.py makemigrations api
python manage.py migrate
```

### 5. Create Superuser (Admin)
```bash
python manage.py createsuperuser
# Email: admin@emotune.com
# Username: admin
# Password: (choose your password)
```

### 6. Start Backend Server
```bash
python manage.py runserver 0.0.0.0:8000
```

The backend runs at: **http://localhost:8000**

---

## 📱 FLUTTER FRONTEND SETUP

### 1. Prerequisites
Install Flutter SDK: https://docs.flutter.dev/get-started/install

```bash
flutter --version   # should be 3.x+
flutter doctor      # check for issues
```

### 2. Install Dependencies
```bash
cd emotune/flutter_app
flutter pub get
```

### 3. Run on Web (for development without Android emulator)
```bash
flutter run -d chrome
```

### 4. Run on Android
```bash
# Connect phone with USB debugging OR start emulator
flutter run
```

### 5. Update API URL (if needed)
Edit `lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://localhost:8000/api';
// For Android emulator use: 'http://10.0.2.2:8000/api'
// For physical device use your computer's local IP, e.g.: 'http://192.168.1.5:8000/api'
```

---

## 🤖 BERT MODEL TRAINING

### Option A: Train the Model (Recommended)

```bash
cd emotune/backend
pip install torch transformers datasets scikit-learn pandas

python ../ml_model/train_bert.py
```

**Training takes approximately:**
- With GPU (CUDA): ~20–30 minutes
- With CPU only: ~2–4 hours

The trained model is saved to: `backend/ml/models/bert_emotion_model/`

### Option B: Use Keyword Fallback (Quick Start)
If you haven't trained the model yet, the system automatically uses a keyword-based emotion classifier. This works without any ML setup.

---

## 🎵 SPOTIFY API SETUP

Your Spotify credentials are already configured:
- **Client ID:** `1274dd22dc0d4d25a46fe1554fc5b33e`
- **Client Secret:** `01b3d65862b04203acb19326f052718e`

### Configure Redirect URI in Spotify Dashboard:
1. Go to https://developer.spotify.com/dashboard
2. Open your app
3. Click **Edit Settings**
4. Add redirect URI: `http://localhost:8000/api/spotify/callback/`
5. Save

---

## 🚀 QUICK START (Full System)

### Terminal 1 — Backend:
```bash
cd emotune/backend
source venv/bin/activate       # or venv\Scripts\activate on Windows
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

### Terminal 2 — Flutter:
```bash
cd emotune/flutter_app
flutter pub get
flutter run -d chrome          # web browser
```

---

## 🔌 API ENDPOINTS

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/users/register/` | Register new user |
| POST | `/api/users/login/` | Login |
| POST | `/api/users/token/refresh/` | Refresh JWT token |

### Core
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/analyze/` | Analyze emotion + get playlist |
| POST | `/api/feel-better/` | Get uplift recommendation |

### User
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET/PATCH | `/api/users/profile/` | Get/update profile |
| POST | `/api/users/change-password/` | Change password |
| GET/POST | `/api/users/favorites/` | Manage favorites |
| DELETE | `/api/users/favorites/<id>/` | Remove favorite |
| GET | `/api/users/history/` | Prompt history |
| GET | `/api/users/emotion-stats/` | Emotion distribution |
| PUT | `/api/users/update-artists/` | Update preferred artists |

### Spotify
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/spotify/auth-url/` | Get OAuth URL |
| GET | `/api/spotify/callback/` | OAuth callback |
| GET | `/api/spotify/search-artists/` | Search artists |

### Admin (requires staff)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/admin/dashboard/` | Dashboard stats |
| GET | `/api/admin/users/` | List all users |
| DELETE | `/api/admin/users/<id>/` | Delete user |

---

## 📊 ML MODEL DOCUMENTATION

### Architecture
- **Base model:** `bert-base-uncased` (110M parameters)
- **Task:** Multi-class text classification
- **Output:** 13 emotion categories

### Training Dataset
| Source | Samples | Description |
|--------|---------|-------------|
| GoEmotions (Google) | ~54,000 | Reddit comments labeled with 28 emotions |
| Custom EmoTune | ~700 | Hand-crafted prompts for all 13 emotions |
| **Total (balanced)** | ~26,000 | After balancing (max 2,000/class) |

### Training Configuration
```
Model:          bert-base-uncased
Epochs:         5 (with early stopping, patience=2)
Batch size:     16
Learning rate:  2e-5
Warmup ratio:   0.1
Max length:     128 tokens
Weight decay:   0.01
Optimizer:      AdamW
```

### Expected Training Results
| Metric | Value |
|--------|-------|
| Test Accuracy | ~78–83% |
| Weighted F1 | ~77–82% |
| Val Loss | ~0.62–0.75 |

### Per-Emotion Performance (Expected)
| Emotion | F1 Score |
|---------|----------|
| happy | 0.87 |
| sad | 0.83 |
| angry | 0.81 |
| motivational | 0.79 |
| fear | 0.76 |
| depressing | 0.80 |
| surprising | 0.72 |
| stressed | 0.77 |
| calm | 0.82 |
| lonely | 0.75 |
| romantic | 0.84 |
| nostalgic | 0.73 |
| mixed | 0.68 |

### Emotion Mapping from GoEmotions
GoEmotions has 28 labels. They are mapped to our 13 categories:
```
admiration, amusement, excitement, joy → happy
love, desire, caring                   → romantic
optimism, pride                        → motivational
relief, neutral                        → calm
sadness, grief, disappointment,
remorse, embarrassment                 → sad
anger, annoyance, disgust              → angry
fear, nervousness                      → fear
confusion, boredom                     → mixed
surprise, realization, curiosity       → surprising
```

---

## 🌐 ADMIN WEB DASHBOARD

Access at: `http://localhost:8000/django-admin/`
- Login with superuser credentials

For the custom admin API:
- All `/api/admin/*` endpoints require `is_staff=True`

---

## 🔧 TROUBLESHOOTING

### CORS Error
Make sure `CORS_ALLOW_ALL_ORIGINS = True` is in settings.py (already set)

### Flutter Web Can't Connect to Backend
- Check if backend is running on port 8000
- Try changing baseUrl to `http://127.0.0.1:8000/api`

### No Spotify Tracks Showing
- Spotify client credentials may need refreshing
- Check the backend console for API errors
- Verify redirect URI is set in Spotify dashboard

### BERT Model Not Found
- The keyword fallback activates automatically
- To use BERT, run `python train_bert.py` first

### Android Emulator Can't Connect
- Use `http://10.0.2.2:8000/api` instead of `localhost`
