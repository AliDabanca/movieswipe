# 🎬 MovieSwipe

> A modern movie recommendation platform built with **Flutter (mobile)** and **FastAPI (backend)** following **Clean Architecture principles**.

---

## ✨ Overview

MovieSwipe is a full-stack application that provides an intuitive swipe-based movie discovery experience.
It is designed with scalability, maintainability, and clean software architecture in mind.

The project demonstrates real-world engineering practices including layered architecture, dependency injection, and modular backend design.

---

## 🚀 Features

* 🎥 Swipe-based movie discovery experience
* ❤️ Like / dislike recommendation flow
* 🔍 Search and filter movies
* ⚡ Fast and scalable FastAPI backend
* 🧱 Clean Architecture (Domain / Data / Presentation)
* 📦 Modular and testable code structure
* 🧠 Recommendation-ready backend design
* 📱 Cross-platform Flutter support (Android / iOS / Web-ready)
* 🔐 Environment-based configuration system

---

## 🏗️ Architecture

### High-Level Flow

```
Flutter App (Presentation Layer)
        ↓
BLoC State Management
        ↓
Use Cases (Domain Layer)
        ↓
Repository Layer
        ↓
FastAPI Backend
        ↓
PostgreSQL / Supabase
```

### Backend Structure

* **Presentation:** API routes (FastAPI controllers)
* **Domain:** Core business logic
* **Data:** Database models & repositories
* **Core:** Config, DI, utilities

### Mobile Structure

* **Presentation:** UI + BLoC
* **Domain:** Entities + Use cases
* **Data:** API services + models

---

## 🛠 Tech Stack

| Layer                | Technology            |
| -------------------- | --------------------- |
| Mobile               | Flutter               |
| State Management     | BLoC                  |
| Backend              | FastAPI               |
| Database             | PostgreSQL / Supabase |
| Caching              | Redis (prepared)      |
| Vector Search        | pgvector (prepared)   |
| Dependency Injection | GetIt (Flutter)       |
| API Docs             | OpenAPI / Swagger     |

---

## 📁 Project Structure

```
movieswipe/
├── lib/              # Flutter application
│   ├── core/
│   └── features/
│
├── backend/
│   └── app/
│       ├── core/
│       ├── domain/
│       ├── data/
│       └── presentation/
│
├── .env.example
├── .env.dev
├── .env.prod
└── README.md
```

---

## ⚙️ Getting Started

### 1. Clone Repository

```bash
git clone <repository-url>
cd movieswipe
```

---

### 2. Backend Setup

```bash
cd backend

python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

pip install -r requirements.txt
```

Run backend:

```bash
uvicorn app.presentation.api.main:app --reload --host 0.0.0.0 --port 8000
```

API Docs:

```
http://localhost:8000/docs
```

---

### 3. Flutter Setup

```bash
flutter pub get
flutter run
```

---

## 🌍 Environments

| Environment | File        |
| ----------- | ----------- |
| Development | `.env.dev`  |
| Test        | `.env.test` |
| Production  | `.env.prod` |

Run with flavor:

```bash
flutter run --dart-define=FLAVOR=dev
```

---

## 🧪 Testing

### Backend

```bash
pytest
```

### Flutter

```bash
flutter test
```

---

## 🚧 Roadmap

* [x] Clean Architecture setup
* [x] Flutter + FastAPI integration
* [x] Authentication system
* [x] Recommendation engine
* [x] AI-based suggestions (vector search)
* [x] Watchlist & favorites
* [ ] Offline caching support
* [ ] Deployment (Docker + Cloud)

---

## 💡 Design Principles

This project follows:

* Clean Architecture principles
* Separation of concerns
* SOLID principles
* Scalable folder structure
* Environment-based configuration

---

## 📌 Notes

* `.env` files are ignored for security reasons
* Project is structured for scalability, not just MVP
* Backend is designed to support AI-based recommendation systems
* pgvector integration is prepared for future ML features

---

## 🎯 Purpose

This project was built to demonstrate:

* Full-stack mobile + backend development skills
* Clean architecture implementation in real-world scale
* Production-ready project structuring
* API-driven system design

---

## 🤝 Contributing

1. Fork the repo
2. Create feature branch
3. Follow clean architecture rules
4. Submit pull request

---

## 📄 License

This project is for educational and portfolio purposes.
