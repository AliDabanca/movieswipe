# MovieSwipe 🎬

A modern movie recommendation app built with Flutter (mobile) and FastAPI (backend) following Clean Architecture principles.

## 🏗️ Architecture

- **Frontend:** Flutter with Clean Architecture (Domain/Data/Presentation layers)
- **Backend:** FastAPI with Clean Architecture
- **State Management:** BLoC pattern
- **Dependency Injection:** GetIt (Flutter), manual DI (Backend)
- **Database:** Supabase/PostgreSQL with pgvector (prepared)
- **Cache:** Redis (prepared)

## 🚀 Quick Start for Team Members

### Prerequisites

- **Flutter:** >= 3.0
- **Python:** 3.10+
- **Git:** Latest version

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
├── lib/                      # Flutter app
│   ├── core/                 # Core utilities (config, DI, errors)
│   └── features/movies/      # Movie feature
│       ├── domain/           # Business logic
│       ├── data/             # Data layer
│       └── presentation/     # UI (Bloc, pages, widgets)
│
├── backend/                  # FastAPI backend
│   └── app/
│       ├── core/             # Config, DB, errors
│       ├── domain/           # Business entities
│       ├── data/             # Data models & repos
│       └── presentation/     # API routes
│
├── .env.dev                  # Dev environment (gitignored)
├── .env.test                 # Test environment (gitignored)
├── .env.prod                 # Prod environment (gitignored)
└── .env.example              # Template for team
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
4. Test your changes
5. Submit a pull request

## 📝 Notes

- Never commit `.env`, `.env.dev`, `.env.test`, or `.env.prod` files
- Always use `.env.example` as template
- Keep IP addresses and secrets out of Git
- Use `--dart-define=FLAVOR=xxx` to switch environments

## 🎯 Next Steps

After successfully running the app:

1. Explore the code structure
2. Check backend API docs at `/docs`
3. Review Clean Architecture patterns
4. Start building features!

---

**Need Help?** Check the troubleshooting section or reach out to the team! 🚀
