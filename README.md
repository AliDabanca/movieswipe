# MovieSwipe 🎬

A modern, social, and AI-powered movie discovery platform built with **Flutter** (mobile) and **FastAPI** (backend) following Clean Architecture principles. Features a Tinder-style swipe interface, semantic vector-based recommendations (pgvector), social DM movie sharing, and rich user analytics.

## ✨ Key Features

| Category | Features |
| :--- | :--- |
| 🎬 **Movie Discovery** | Tinder-style swipe cards, AI-powered personalized feed, Explainable AI ("Why recommended"), Smart AI Discovery (semantic search), dice roll random suggestion |
| 📋 **Watchlist** | Collections, watch status tracking, animated progress indicators, movie detail pages |
| 👥 **Social** | Follow system, DM movie card sharing, emoji reactions, external sharing (WhatsApp, Instagram etc.), friend profiles, notifications |
| 📊 **Analytics** | Genre DNA radar chart, mood aura visualization, weekly activity charts, daily swipe streak gamification |
| 🔐 **Auth** | Supabase Auth, JWT middleware, interactive onboarding (cold-start solver) |

## 🏗️ Architecture

- **Frontend:** Flutter with Clean Architecture (Domain/Data/Presentation layers)
- **Backend:** FastAPI with Clean Architecture
- **State Management:** BLoC pattern (`flutter_bloc`) + Provider
- **Dependency Injection:** GetIt (Flutter), manual DI (Backend)
- **Database:** Supabase PostgreSQL + pgvector (384-dim HNSW vector search)
- **Cache:** Redis
- **ML/NLP:** Sentence-Transformers (all-MiniLM-L6-v2)
- **Error Handling:** Functional (`dartz` Either type)

## 🚀 Quick Start for Team Members

### Prerequisites

- **Flutter:** >= 3.10.8
- **Python:** 3.10+
- **Git:** Latest version
- **Redis:** (Optional, for caching)

### 1️⃣ Clone the Repository

```bash
git clone <repository-url>
cd movieswipe
```

### 2️⃣ Backend Setup

#### Install Dependencies

```bash
cd backend

# Create virtual environment (recommended)
python -m venv .venv

# Activate virtual environment
# Windows:
.venv\Scripts\activate
# Mac/Linux:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

#### Configure Environment

```bash
# Copy example file
cp .env.example .env

# Edit .env and update with your settings
# No changes needed for basic local development
```

#### Run Backend

```bash
# Make sure you're in backend/ directory
python -m uvicorn app.presentation.api.main:app --host 0.0.0.0 --port 8000
```

Backend will be available at: `http://localhost:8000`

API Documentation: `http://localhost:8000/docs`

### 3️⃣ Flutter Setup

#### Install Dependencies

```bash
# From project root
flutter pub get
```

#### Configure Environment

**Find Your Local IP Address:**

```bash
# Windows
ipconfig | findstr /i "IPv4"

# Mac/Linux
ifconfig | grep "inet "
```

**Create Development Environment File:**

```bash
# Copy example file
cp .env.example .env.dev

# Edit .env.dev and replace <YOUR_LOCAL_IP> with your actual IP
# Example: BASE_URL=http://192.168.1.100:8000
```

**Important Notes:**
- For **Android Emulator:** Use `BASE_URL=http://10.0.2.2:8000`
- For **iOS Simulator:** Use `BASE_URL=http://localhost:8000`
- For **Physical Device:** Use your computer's local IP (both devices must be on same WiFi)

#### Run Flutter App

```bash
# Development (default, loads .env.dev)
flutter run --dart-define=FLAVOR=dev

# Or simply:
flutter run
```

**Select Your Device:**
- Physical device
- Emulator/Simulator
- Windows desktop (`-d windows`)
- Chrome (`-d chrome`)

## 🌍 Multiple Environments

The project supports three environments:

| Environment | File | Usage |
|------------|------|-------|
| Development | `.env.dev` | Local testing with local backend |
| Test | `.env.test` | Testing with test server |
| Production | `.env.prod` | Production deployment |

**Switch Environments:**

```bash
# Development
flutter run --dart-define=FLAVOR=dev

# Test
flutter run --dart-define=FLAVOR=test

# Production
flutter run --dart-define=FLAVOR=prod
```

## 📱 Testing on Physical Device

### Important: Network Setup

1. **Connect to Same WiFi:** Ensure your phone and computer are on the **same WiFi network**
2. **Get Your IP:** Run `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
3. **Update .env.dev:** Set `BASE_URL=http://YOUR_LOCAL_IP:8000`
4. **Firewall:** Allow port 8000 through Windows Firewall

**Windows Firewall Rule (PowerShell as Admin):**

```powershell
New-NetFirewallRule -DisplayName "MovieSwipe Backend" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
```

Or temporarily disable Windows Firewall for testing.

### Test Connection

Before running the app, test backend connectivity from phone's browser:

```
http://YOUR_LOCAL_IP:8000
```

You should see a JSON response with API info.

## 🛠️ Development Workflow

### Backend Changes

1. Make changes in `backend/app/`
2. Backend auto-reloads (uvicorn with `--reload`)
3. Test at `http://localhost:8000/docs`

### Flutter Changes

1. Make changes in `lib/`
2. Hot reload: Press `r` in terminal or save file
3. Hot restart: Press `R` in terminal

## 📁 Project Structure

```
movieswipe/
├── lib/                          # Flutter app
│   ├── core/                     # Core utilities (config, DI, errors, theme, providers)
│   └── features/                 # Feature-driven Clean Architecture modules
│       ├── auth/                 # Authentication & registration
│       ├── movies/               # Swipe feed, search, details, collections, smart discovery
│       ├── social/               # DMs, movie sharing, chat reactions, friend profiles
│       ├── users/                # Profile, analytics (DNA, aura, activity, streak), about
│       ├── onboarding/           # Interactive mood survey & genre selection
│       └── navigation/           # Global routing & shell navigation
│
├── backend/                      # FastAPI backend
│   └── app/
│       ├── core/                 # Config, DB (Supabase + retry), security (JWT)
│       ├── domain/               # Business entities
│       ├── data/                 # Pydantic models & repos
│       ├── services/             # Business logic (recommendations, social, DM, sync, etc.)
│       └── presentation/         # API routes (10 modules)
│
├── docs/                         # Documentation
│   └── GRADUATION_REPORT.md      # Full academic graduation report
│
├── .env.dev / .env.test / .env.prod  # Environment files (gitignored)
├── .env.example                       # Template for team
├── PROGRESS.md                        # Development progress & changelog
├── PROJECT_CONTEXT.md                 # Technical context for developers
├── OPTIMIZATIONS.md                   # Performance optimization plan
└── AGENTS.md                          # AI agent workflow rules
```

## 🧪 Testing

### Backend

```bash
cd backend
pytest
```

### Flutter

```bash
flutter test
flutter analyze
```

## 🐛 Troubleshooting

### "Connection refused" or "Network error"

✅ **Check:**
1. Backend is running (`http://localhost:8000` works in browser)
2. `.env.dev` has correct IP for your setup
3. Phone and PC on same WiFi (for physical device)
4. Windows Firewall allows port 8000

### "Module not found" (Python)

```bash
# Reinstall dependencies
pip install -r requirements.txt
```

### "Package not found" (Flutter)

```bash
flutter pub get
flutter clean
flutter pub get
```

### Backend won't start

```bash
# Check if port 8000 is already in use
# Windows:
netstat -ano | findstr :8000

# Kill process if needed
taskkill /PID <process_id> /F
```

## 🤝 Contributing

1. Create a new branch for your feature
2. Follow Clean Architecture principles
3. Maintain SOLID principles
4. Use `flutter_bloc` for complex state, `provider` for simple DI
5. Use `Equatable` for all models/entities (BLoC state comparisons)
6. Use `dartz` Either for error handling in data/domain layers
7. Test your changes (`flutter analyze` must pass with 0 errors)
8. Submit a pull request

## 📝 Notes

- Never commit `.env`, `.env.dev`, `.env.test`, or `.env.prod` files
- Always use `.env.example` as template
- Keep IP addresses and secrets out of Git
- Use `--dart-define=FLAVOR=xxx` to switch environments
- All FastAPI endpoints must use Pydantic models for validation
- All database operations must be async (SQLAlchemy asyncio)

---

## 👥 Developers

- **Ali DABANCA** — Full-Stack Developer
- **Mustafa Onur BAYRAM** — Full-Stack Developer

---

**Need Help?** Check the troubleshooting section or reach out to the team! 🚀
