# FitandFine 🥑

> **AI-powered nutrition tracking & wellness coaching for iOS**

FitandFine is a production-grade iOS application that combines barcode scanning, OCR nutrition label parsing, Apple Health integration, and a multi-agent Claude AI system into a single, beautifully designed nutrition companion. It goes beyond calorie counting — adapting your targets intelligently and coaching you with your real data.

---

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
  - [Backend Setup](#backend-setup)
  - [iOS App Setup](#ios-app-setup)
- [Environment Variables](#environment-variables)
- [AI Agent System](#ai-agent-system)
- [API Reference](#api-reference)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)
- [Roadmap](#roadmap)
- [License](#license)

---

## Features

| Feature | Description |
|---|---|
| **Barcode Scanner** | Real-time EAN/UPC barcode scanning via AVFoundation — food card loads in < 500ms |
| **OCR Label Scanning** | Photograph any nutrition label → OpenCV + Tesseract → Claude AI extracts structured macros |
| **AI Nutrition Coach** | Conversational Claude-powered coach answers questions using your actual food log data |
| **Adaptive Calorie Targets** | Closed-loop system adjusts your daily target based on real weight trends vs predictions |
| **Streak Psychology** | Chain-dot streak tracker with "Don't break the chain" motivation mechanics |
| **Apple Health Integration** | Reads steps, active calories, and sleep data; writes nutrition entries back |
| **Weekly Analysis Reports** | Diet Analysis Agent identifies adherence patterns, macro imbalances, and meal timing |
| **Meal Recommendations** | Recommendation Agent suggests real meals to fill your remaining daily macros |
| **Progress Evaluation** | Detects plateaus, differentiates adherence issues from metabolic adaptation, proposes goal adjustments |
| **Offline Support** | SwiftData local cache keeps the app functional without a network connection |

---

## Screenshots

| Dashboard | Food Log | Food Detail |
|---|---|---|
| ![Dashboard](screenshots/01-dashboard.png) | ![Food Log](screenshots/02-food-log.png) | ![Food Log Detail](screenshots/03-food-log-detail.png) |

| AI Coach | Analytics |
|---|---|
| ![AI Coach](screenshots/04-coach.png) | ![Analytics](screenshots/05-analytics.png) |

---

## Architecture

```
iOS App (SwiftUI + MVVM-C)
    │
    ▼  HTTPS / REST + SSE streaming
FastAPI Backend (Python, async)
    ├── API Routers          (/auth, /foods, /logs, /goals, /ai, /analytics, /weight)
    ├── Service Layer        (OCR, food DB, macro math, S3, cache)
    ├── Agent Orchestrator   (routes requests to 4 specialized Claude agents)
    ├── Repository Layer     (SQLAlchemy async → PostgreSQL)
    └── Celery Workers       (OCR pipeline, weekly analysis scheduling)

Infrastructure:
    ├── PostgreSQL           (primary DB + read replica for analytics)
    ├── Redis                (session cache, barcode lookup, Celery broker)
    └── AWS S3               (nutrition label image storage)

AI Agents (Claude API):
    ├── Food Parser Agent    (OCR text → structured nutrition JSON)
    ├── Diet Analysis Agent  (7-day log pattern analysis)
    ├── Recommendation Agent (meal suggestions fitting remaining macros)
    └── Progress Evaluator   (plateau detection, goal adjustment proposals)
```

---

## Requirements

### iOS App
- **Xcode 15+**
- **iOS 17+** (SwiftData requires iOS 17)
- **Swift 5.9+**
- A physical iPhone for camera features (barcode + label scanning require a real camera)
- Apple Developer account (free tier works for personal testing via Xcode direct install)

### Backend
- **Python 3.11+**
- **PostgreSQL 15+**
- **Redis 7+**
- **Tesseract OCR 5+** — `brew install tesseract` on macOS
- **Anthropic API key** (Claude access)
- **AWS account** with S3 bucket (for label image storage)

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/AdityaSidham/FitandFine.git
cd FitandFine
```

---

### Backend Setup

#### Step 1 — Install system dependencies

```bash
# macOS
brew install postgresql redis tesseract

# Ubuntu / Debian
sudo apt-get install -y postgresql redis-server tesseract-ocr libpq-dev
```

#### Step 2 — Create and activate a Python virtual environment

```bash
cd fitandfine-backend
python3 -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate
```

#### Step 3 — Install Python dependencies

```bash
pip install -r requirements.txt
```

#### Step 4 — Configure environment variables

```bash
cp .env.example .env
# Edit .env with your values (see Environment Variables section below)
```

#### Step 5 — Start PostgreSQL and Redis

```bash
brew services start postgresql   # macOS
brew services start redis

# Or with Docker:
docker-compose up -d postgres redis
```

#### Step 6 — Run database migrations

```bash
alembic upgrade head
```

#### Step 7 — Seed the food database (optional but recommended)

```bash
python scripts/seed_usda_foods.py
# Imports ~50,000 common food items from USDA FoodData Central
```

#### Step 8 — Start the API server

```bash
uvicorn app.main:app --reload --port 8000
# API docs available at http://localhost:8000/docs
```

#### Step 9 — Start the Celery worker (for OCR processing)

```bash
# In a separate terminal
celery -A app.tasks.celery_app worker --loglevel=info
```

#### Step 10 — Start Celery Beat (for weekly scheduled analysis)

```bash
# In a separate terminal
celery -A app.tasks.celery_app beat --loglevel=info
```

---

### iOS App Setup

#### Step 1 — Open the project

```bash
open FitandFine-iOS/FitandFineIOS/FitandFineIOS.xcodeproj
```

#### Step 2 — Configure the API base URL

Open `FitandFine-iOS/FitandFineIOS/FitandFineIOS/Networking/NetworkClient.swift` and update:

```swift
private let baseURL = "http://localhost:8000/api/v1"
// For a deployed backend, replace with your server URL:
// private let baseURL = "https://api.yourdomain.com/api/v1"
```

#### Step 3 — Set your Team in Xcode

1. Select the `FitandFineIOS` target in Xcode
2. Go to **Signing & Capabilities**
3. Set **Team** to your Apple Developer account

#### Step 4 — Run on device or simulator

- **Simulator** — works for all UI features except camera scanning
- **Physical device** — required for barcode scanner and nutrition label OCR

Select your target device in Xcode and press **⌘R** to build and run.

#### Step 5 — Grant permissions when prompted

On first launch the app requests:
- **Camera** — barcode and label scanning
- **HealthKit** — steps, active calories, sleep data

---

## Environment Variables

Create a `.env` file in `fitandfine-backend/` with the following:

```env
# Database
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/fitandfine
DATABASE_URL_READ=postgresql+asyncpg://postgres:password@localhost:5432/fitandfine

# Redis
REDIS_URL=redis://localhost:6379/0

# Anthropic
ANTHROPIC_API_KEY=sk-ant-...

# AWS S3 (for nutrition label image storage)
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_S3_BUCKET=fitandfine-label-images
AWS_REGION=us-east-1

# JWT
JWT_SECRET_KEY=your-256-bit-secret-key-here
JWT_ALGORITHM=RS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# Apple Sign In
APPLE_TEAM_ID=YOUR_TEAM_ID
APPLE_CLIENT_ID=com.yourname.fitandfine

# App settings
DEBUG=false
LOG_LEVEL=INFO
MAX_LABEL_SCANS_PER_DAY=30
MAX_AI_COACH_MESSAGES_PER_DAY=50
```

---

## AI Agent System

FitandFine uses **4 specialized Claude agents**, each with an isolated system prompt and structured JSON I/O. Agents never call each other directly — all coordination flows through `AgentOrchestrator`.

### Agent 1 — Food Parser Agent
- **Trigger:** After Tesseract OCR completes on a nutrition label image
- **Input:** Raw OCR text + confidence score
- **Output:** Structured nutrition JSON with per-field confidence scores
- **Confidence cascade:**
  - `> 0.85` → auto-add to food log
  - `0.60–0.85` → "Review & Confirm" screen
  - `< 0.60` → prompt re-scan

### Agent 2 — Diet Analysis Agent
- **Trigger:** Weekly (Sunday 23:59 user's local timezone) or on-demand via Coach
- **Input:** 7-day food log summary, weight trend, goal parameters
- **Output:** Findings with severity ratings (info / warning / critical), adherence score

### Agent 3 — Recommendation Agent
- **Trigger:** User requests meal suggestions, or > 50% macros remaining after dinner
- **Input:** Remaining daily macros, dietary restrictions, allergies, budget
- **Output:** Meal suggestions with exact macro calculations and alternatives

### Agent 4 — Progress Evaluator Agent
- **Trigger:** Weekly (after Diet Analysis) or when weight deviation exceeds threshold
- **Input:** 4-week weight history, calorie adherence history, current goal
- **Output:** Plateau detection, adjustment recommendation (e.g. "reduce by 100 kcal/day")

### AI Coach (Orchestration Layer)
- Conversational wrapper that routes questions to relevant agents
- Streams responses back to the iOS app via **Server-Sent Events (SSE)**
- Never applies goal adjustments silently — always requires user confirmation

---

## API Reference

Full interactive documentation is available at `http://localhost:8000/docs` once the backend is running.

### Key Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/auth/apple` | Sign in with Apple → returns JWT tokens |
| `GET` | `/foods/barcode/{code}` | Look up food by barcode (cache → DB → OpenFoodFacts → USDA) |
| `GET` | `/foods/search?q={}` | Full-text food search |
| `POST` | `/foods/label-scan` | Upload nutrition label image → returns `scan_id` |
| `GET` | `/foods/label-scan/{id}` | Poll OCR scan status and result |
| `GET` | `/logs/daily?date={}` | Get food log entries for a date with macro totals |
| `POST` | `/logs/daily` | Add food entry to log |
| `DELETE` | `/logs/daily/{id}` | Remove entry (soft delete, supports undo) |
| `GET` | `/goals/` | Get current active goal and calculated targets |
| `POST` | `/ai/coach/message` | Send message to AI Coach (SSE streaming response) |
| `GET` | `/ai/recommendations` | Get meal recommendations for remaining macros |
| `GET` | `/ai/weekly-report` | Latest Diet Analysis Agent output |
| `GET` | `/analytics/macro-trends?days=30` | Daily macro breakdown for charts |
| `POST` | `/weight` | Log a weight reading |
| `GET` | `/weight/history?days=90` | Weight history + 7-day moving average |

---

## Project Structure

```
FitandFine/
├── FitandFine-iOS/
│   └── FitandFineIOS/
│       └── FitandFineIOS/
│           ├── App/                        # Entry point, app lifecycle
│           ├── Coordinators/               # MVVM-C navigation coordinators
│           │   ├── AppCoordinator.swift
│           │   ├── AuthCoordinator.swift
│           │   ├── DashboardCoordinator.swift
│           │   ├── FoodLogCoordinator.swift
│           │   └── CoachCoordinator.swift
│           ├── ViewModels/                 # @MainActor ObservableObject classes
│           ├── Views/
│           │   ├── Auth/                   # WelcomeView, SignInView
│           │   ├── Dashboard/              # DashboardView, StreakCard, SleepCard, ActivityCard
│           │   ├── FoodLog/                # FoodLogView with swipe-to-delete
│           │   ├── Coach/                  # CoachChatView (SSE streaming), WeeklyReportView
│           │   ├── Analytics/              # AnalyticsView with Swift Charts
│           │   ├── Scanner/                # BarcodeScannerView, LabelScanResultView
│           │   ├── Food/                   # FoodDetailView, ManualEntryView
│           │   ├── Profile/                # ProfileView, GoalEditView
│           │   ├── Onboarding/             # OnboardingView (profile + goal setup)
│           │   └── Common/                 # DesignSystem.swift, ViewStateModifier.swift
│           ├── Models/                     # Codable API response models
│           ├── Networking/                 # NetworkClient, APIError
│           └── Managers/                   # HealthKitManager
│
├── fitandfine-backend/
│   └── app/
│       ├── main.py                         # FastAPI app factory
│       ├── config.py                       # Pydantic Settings
│       ├── api/v1/                         # Route handlers
│       ├── agents/                         # 4 Claude agents + orchestrator
│       │   ├── base_agent.py
│       │   ├── food_parser_agent.py
│       │   ├── diet_analysis_agent.py
│       │   ├── recommendation_agent.py
│       │   ├── progress_evaluator_agent.py
│       │   ├── coach_agent.py
│       │   └── orchestrator.py
│       ├── services/                       # OCR, food DB, S3, cache, macro math
│       ├── repositories/                   # SQLAlchemy async DB access
│       ├── models/                         # SQLAlchemy ORM models
│       ├── schemas/                        # Pydantic v2 request/response schemas
│       ├── tasks/                          # Celery OCR + analytics tasks
│       └── middleware/                     # Auth, rate limiting, request ID
│
├── fitandfine-preview.html                 # Interactive UI prototype (open in browser)
└── README.md
```

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| iOS | Swift 5.9 + SwiftUI | Declarative UI, native performance |
| Navigation | MVVM-C (Coordinator pattern) | Solves SwiftUI nav complexity cleanly |
| Local persistence | SwiftData | Modern Swift, offline support |
| Camera | AVFoundation | Real-time barcode + photo capture |
| Health data | HealthKit | Steps, sleep, active calories |
| Charts | Swift Charts | Native, animatable data visualization |
| Backend | FastAPI (Python) | Async, first-class Anthropic SDK |
| AI | Claude API (Anthropic) | Multi-agent, structured tool use |
| OCR | Tesseract 5 + OpenCV | Server-side for pipeline co-location with Claude |
| Database | PostgreSQL 15 | Relational integrity, JSONB for agent outputs |
| Cache | Redis 7 | Session tokens, barcode lookup, Celery broker |
| Storage | AWS S3 | Nutrition label images |
| Background tasks | Celery + Redis | Async OCR, weekly analysis scheduling |
| Migrations | Alembic | PostgreSQL schema versioning |

---

## Roadmap

- [x] Barcode scanning + USDA food lookup
- [x] Manual food log with swipe-to-delete
- [x] AI Coach (conversational, SSE streaming)
- [x] Weekly diet analysis reports
- [x] Streak tracking with chain-dot visualization
- [x] Apple Health integration (steps, sleep, active calories)
- [x] OCR nutrition label scanning
- [x] Adaptive calorie target system
- [ ] Restaurant food photo estimation (photograph meal → macro estimate)
- [ ] Meal planning and scheduling
- [ ] Apple Watch companion app
- [ ] Home Screen widget (quick food log)
- [ ] Android version

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m "feat: add your feature"`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---



<div align="center">

  <sub>Made by <a href="https://github.com/AdityaSidham">Aditya Sidham</a></sub>
</div>
