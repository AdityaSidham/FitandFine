<a id="readme-top"></a>

<div align="center">

<a href="https://adityasidham.site/FitandFine.html"><img src=".github/readme/banner.jpg" alt="FitandFine. Nutrition tracking for iOS that adapts to what you actually eat. Built by Aditya Sidham." width="100%"></a>

<br>

![iOS 17.6+](https://img.shields.io/badge/iOS-17.6%2B-ECE9E1?style=flat-square&logo=apple&logoColor=ECE9E1&labelColor=0D1424)
![Swift](https://img.shields.io/badge/Swift-SwiftUI%20%2B%20SwiftData-F05138?style=flat-square&logo=swift&logoColor=white&labelColor=0D1424)
![FastAPI](https://img.shields.io/badge/FastAPI-async-009688?style=flat-square&logo=fastapi&logoColor=white&labelColor=0D1424)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=flat-square&logo=postgresql&logoColor=white&labelColor=0D1424)
![Redis](https://img.shields.io/badge/Redis-7-FF4438?style=flat-square&logo=redis&logoColor=white&labelColor=0D1424)
![Celery](https://img.shields.io/badge/Celery-workers-37814A?style=flat-square&logo=celery&logoColor=white&labelColor=0D1424)
![Gemini](https://img.shields.io/badge/Gemini-2.0%20Flash-8E75B2?style=flat-square&logo=googlegemini&logoColor=white&labelColor=0D1424)

**[Case study](https://adityasidham.site/FitandFine.html)** &nbsp;|&nbsp; **[Screens](#screens)** &nbsp;|&nbsp; **[Architecture](#architecture)** &nbsp;|&nbsp; **[AI agents](#the-four-ai-agents)** &nbsp;|&nbsp; **[Run it](#getting-started)** &nbsp;|&nbsp; **[API](#api-reference)**

</div>

<br>

Most nutrition apps are good at recording what happened. They're less useful when a routine changes, the first calorie estimate is wrong, or logging gets too slow to keep up. **FitandFine closes the gap between tracking and adapting.**

It's a native SwiftUI app with a FastAPI backend. Scan a barcode or photograph a label, log meals in seconds, pull steps and sleep from Apple Health, and get a coach that answers from your own food log. Four AI agents read labels, review your week, suggest meals that fit what's left of your macros, and propose calorie changes that you approve before anything moves.

I designed and built all of it, solo: the iOS app, the backend, the data model and the AI layer.

| **&lt;500 ms** | **50,000+** | **85%+** | **4** |
|:---:|:---:|:---:|:---:|
| barcode to food card | USDA food records | label-field accuracy | AI agents |

<details>
<summary><b>Table of contents</b></summary>

<br>

- [Screens](#screens)
- [Features](#features)
- [Architecture](#architecture)
- [The four AI agents](#the-four-ai-agents)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Environment variables](#environment-variables)
- [API reference](#api-reference)
- [Project structure](#project-structure)
- [Tech stack](#tech-stack)
- [Roadmap](#roadmap)
- [Author](#author)

</details>

## Screens

<p align="center">
  <img src=".github/readme/screens.jpg" alt="Four FitandFine screens on iPhone: the dashboard with calorie ring, macros and streak; the food log grouped by meal; the FitCoach chat answering a protein question from the user's own logs; and analytics with a 30-day calorie trend and macro split" width="100%">
</p>

<details>
<summary>Full-size simulator screenshots</summary>

<br>

| Dashboard | Food log | Food detail |
|---|---|---|
| ![Dashboard](screenshots/01-dashboard.png) | ![Food log](screenshots/02-food-log.png) | ![Food log detail](screenshots/03-food-log-detail.png) |

| FitCoach | Analytics |
|---|---|
| ![AI coach](screenshots/04-coach.png) | ![Analytics](screenshots/05-analytics.png) |

</details>

<p align="right"><a href="#readme-top">Back to top</a></p>

## Features

| Feature | What it does |
|---|---|
| **Barcode scanner** | Real-time EAN/UPC scanning with AVFoundation. Lookups go Redis cache, then the local database, then Open Food Facts, then USDA FoodData Central, and land on a food card in under 500 ms. |
| **Label scanning** | Photograph a nutrition label and Gemini Vision returns structured macros with a confidence score. High-confidence results save straight away; anything less goes to a review screen first. |
| **FitCoach** | A multi-turn coach that streams answers over Server-Sent Events and grounds them in your logged food, goals and recent history. |
| **Weekly analysis** | Reviews your last 7 days against your goal and returns findings rated info, warning or critical. |
| **Meal suggestions** | Proposes real meals that fill the macros you have left today. |
| **Adaptive targets** | Compares your actual weight trend with what your logged calories predict, spots plateaus, and proposes a specific change. Nothing applies until you confirm it. |
| **Apple Health** | Reads steps, active calories and sleep through HealthKit. |
| **Streaks** | A chain-dot streak tracker built around "don't break the chain." |
| **Offline cache** | SwiftData keeps recent foods and logs available without a connection. |

## Architecture

```mermaid
flowchart LR
    subgraph iOS["iOS app: SwiftUI + MVVM-C"]
        V[Views] --> VM[ViewModels] --> NC[NetworkClient]
        HK[HealthKit] --> VM
        SD[(SwiftData cache)] <--> VM
    end
    NC -- "REST + SSE" --> API
    subgraph BE["FastAPI backend"]
        API[api/v1 routers] --> SVC[Services]
        SVC --> REPO[Repositories]
        API -. "label-scan jobs" .-> CEL[Celery workers]
    end
    REPO --> PG[(PostgreSQL 16)]
    SVC <--> RD[(Redis 7)]
    CEL --> RD
    SVC --> GEM{{Gemini 2.0 Flash}}
    CEL --> GEM
    SVC --> EXT[Open Food Facts + USDA]
```

- **iOS:** SwiftUI with MVVM plus coordinators for navigation, SwiftData for the offline cache, AVFoundation for the camera, HealthKit for activity and sleep, Swift Charts for analytics.
- **Backend:** async FastAPI, layered as routers, services and repositories over SQLAlchemy 2.0 and PostgreSQL, with Alembic migrations and Pydantic v2 schemas.
- **Async work:** label scans can run as Celery jobs on Redis, so the app never waits on a slow model call.
- **Caching:** Redis holds barcode lookups for 72 hours, searches for 6, recommendations for 4 and weekly analyses for 8 days.

<p align="right"><a href="#readme-top">Back to top</a></p>

## The four AI agents

Each agent is a service with its own system prompt and JSON output, running on Gemini 2.0 Flash through `app/services/ai_service.py`. The coach sits on top and talks to the user.

| Agent | Service | Input | Output |
|---|---|---|---|
| **Label parser** | `label_scan_service.py` | A label photo (Gemini Vision) | Structured nutrition JSON and a confidence score. At 90% or higher it parses as high confidence, from 70% it asks for a review, and below that it asks you to verify. The Celery path auto-saves at 85% or higher. |
| **Diet analysis** | `diet_analysis_service.py` | 7 days of logs and the active goal | Findings with severity ratings and an adherence picture |
| **Recommendations** | `recommendation_service.py` | Remaining daily macros and preferences | Meal suggestions with macro math |
| **Progress evaluator** | `progress_evaluator_service.py` | Weeks of weight logs and average intake | Linear-regression trend vs. expected change (7,700 kcal ≈ 1 kg), classified as on track, plateau or off track, plus a proposed calorie adjustment |
| *FitCoach (on top)* | `coach_service.py` | Your message, history and log context | A streamed answer over SSE; conversations persist as JSONB |

Goal changes from the progress evaluator only apply through `POST /ai/progress-evaluation/apply`, after the user confirms.

## Requirements

**iOS app**
- Xcode 16 or later (the project was last opened in Xcode 26), deploying to iOS 17.6 or later
- A physical iPhone for the camera features (barcode and label scanning)
- A free Apple developer account is enough to install on your own device

**Backend**
- Python 3.11 or later
- PostgreSQL 15 or later and Redis 7 (or Docker)
- A Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey) (the free tier works)
- A USDA FoodData Central API key (optional, for the USDA fallback)

## Getting started

```bash
git clone https://github.com/AdityaSidham/FitandFine.git
cd FitandFine
```

### Backend

**Option A: Docker (Postgres, Redis, API and a Celery worker)**

```bash
cd fitandfine-backend
cp .env.example .env          # add your GEMINI_API_KEY
docker compose up --build
docker compose exec api alembic upgrade head
```

**Option B: run it yourself**

```bash
cd fitandfine-backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # fill in DATABASE_URL, SECRET_KEY, GEMINI_API_KEY

docker compose up -d db redis # or use local Postgres and Redis
alembic upgrade head
uvicorn app.main:app --reload --port 8000

# in a second terminal, for queued label scans
celery -A app.tasks.celery_app worker --loglevel=info --queues=ocr,analytics,default
```

Interactive API docs are at `http://localhost:8000/docs`. To check every Phase 1 endpoint end to end, run `python test_phase1.py` while the server is up.

### iOS app

```bash
open FitandFine-iOS/FitandFineIOS/FitandFineIOS.xcodeproj
```

1. Select the `FitandFineIOS` target, open **Signing & Capabilities** and choose your team.
2. The backend address switches automatically: `localhost:8000` in the simulator, and the LAN address in `Networking/NetworkClient.swift` on a device. Change that address to your Mac's IP.
3. Press **⌘R**. On first launch the app asks for camera and Health access. **Continue as Guest** skips sign-in.

The simulator runs everything except the camera.

## Environment variables

`fitandfine-backend/.env` (start from [`.env.example`](fitandfine-backend/.env.example), then add `GEMINI_API_KEY`, which it doesn't list yet):

| Variable | Required | Notes |
|---|:---:|---|
| `DATABASE_URL` | yes | `postgresql+asyncpg://fitandfine:fitandfine_dev@localhost:5432/fitandfine` |
| `SECRET_KEY` | yes | 32+ characters, signs JWTs |
| `GEMINI_API_KEY` | for AI | Powers the agents, the coach and label scanning |
| `GEMINI_MODEL` |  | Defaults to `gemini-2.0-flash`, which Google listed for shutdown from June 1, 2026. Set a current Flash model if calls fail. |
| `REDIS_URL` |  | Defaults to `redis://localhost:6379/0` |
| `USDA_API_KEY` |  | USDA FoodData Central fallback |
| `AWS_*`, `S3_BUCKET_NAME` |  | Label image storage |
| `AI_COACH_MESSAGES_PER_DAY`, `LABEL_SCANS_PER_DAY`, ... |  | Per-user rate limits |

<p align="right"><a href="#readme-top">Back to top</a></p>

## API reference

Everything is under `/api/v1`. The full, interactive list is at `/docs`.

| Method | Endpoint | What it does |
|---|---|---|
| `POST` | `/auth/dev-login` | Guest session for local development |
| `POST` | `/auth/apple`, `/auth/google` | Sign in, returns access and refresh tokens |
| `POST` | `/auth/refresh`, `/auth/logout` | Rotate or revoke tokens |
| `GET` | `/foods/barcode/{barcode}` | Cache, then DB, then Open Food Facts, then USDA |
| `GET` | `/foods/search?q=` | Food search |
| `POST` | `/foods/manual` | Add a custom food |
| `POST` | `/scan/label` | Label photo to parsed nutrition (Gemini Vision) |
| `POST` | `/scan/confirm` | Save a reviewed scan as a food |
| `POST` | `/foods/label-scan` | Queue a label scan on Celery, poll `/foods/label-scan/{scan_id}` |
| `GET` / `POST` | `/logs/daily` | A day's entries with macro totals / add an entry |
| `PUT` / `DELETE` | `/logs/daily/{log_id}` | Edit or remove an entry |
| `GET` | `/logs/analytics` | Daily trends for the charts |
| `GET` / `POST` | `/goals/` | Active goal and calculated targets / set a new goal |
| `POST` / `GET` | `/weight/`, `/weight/history` | Log weight / history with trend |
| `POST` | `/ai/coach/message` | FitCoach, streamed over SSE |
| `GET` | `/ai/weekly-report` | Diet analysis for the last 7 days |
| `GET` | `/ai/recommendations` | Meals for your remaining macros |
| `GET` | `/ai/progress-evaluation` | Trend check and proposed adjustment |
| `POST` | `/ai/progress-evaluation/apply` | Apply an adjustment the user approved |

## Project structure

```text
FitandFine/
├── FitandFine-iOS/
│   └── FitandFineIOS/                 Xcode project (open FitandFineIOS.xcodeproj)
│       └── FitandFineIOS/
│           ├── App/                   entry point and lifecycle
│           ├── Coordinators/          MVVM-C navigation
│           ├── ViewModels/
│           ├── Views/
│           │   ├── Dashboard/         calorie ring, macros, streak, activity, sleep
│           │   ├── FoodLog/  Food/    log by meal, food detail
│           │   ├── Scanner/           barcode + label scan
│           │   ├── Coach/             FitCoach chat, weekly report, progress evaluation
│           │   ├── Analytics/         Swift Charts trends and macro split
│           │   ├── Onboarding/  Profile/  Auth/
│           │   └── Common/            DesignSystem.swift
│           ├── Models/  Networking/
│           └── Services/              HealthKitManager
├── fitandfine-backend/
│   ├── app/
│   │   ├── api/v1/                    auth, users, foods, logs, goals, weight, scan, ai
│   │   ├── services/                  the agents, coach, food DB, macros, cache
│   │   ├── repositories/              SQLAlchemy async data access
│   │   ├── models/  schemas/          ORM models, Pydantic v2 schemas
│   │   └── tasks/                     Celery app, label-scan and analytics jobs
│   ├── alembic/                       migrations
│   ├── docker-compose.yml             Postgres, Redis, API, worker
│   └── test_phase1.py                 end-to-end endpoint checks
├── fitandfine-preview.html            clickable UI prototype, open in a browser
└── screenshots/
```

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| iOS UI | Swift 5.9, SwiftUI | Declarative, native performance |
| Navigation | MVVM-C | Keeps SwiftUI navigation out of the views |
| Local data | SwiftData | Offline cache with modern Swift |
| Camera, health | AVFoundation, HealthKit | Real-time barcodes, steps, sleep, active calories |
| Charts | Swift Charts | Native, animatable trends |
| API | FastAPI, Pydantic v2 | Async, typed, self-documenting |
| AI | Gemini 2.0 Flash (text + vision) | Structured JSON output on a free tier |
| Database | PostgreSQL 16, SQLAlchemy 2.0, Alembic | Relational integrity, JSONB for agent output |
| Cache, queue | Redis 7, Celery | Barcode cache, rate limits, background scans |
| Food data | Open Food Facts, USDA FoodData Central | Broad barcode coverage with a trusted fallback |

## Roadmap

- [x] Barcode scanning with Open Food Facts and USDA lookup
- [x] Food log with swipe to delete
- [x] FitCoach over SSE
- [x] Weekly diet analysis
- [x] Streaks, Apple Health (steps, sleep, active calories)
- [x] Label scanning with Gemini Vision
- [x] Adaptive calorie targets with user approval
- [ ] Tesseract fallback for label scans when the model is unavailable
- [ ] Photo-based meal estimates
- [ ] Meal planning
- [ ] Home Screen widget and Apple Watch companion

<p align="right"><a href="#readme-top">Back to top</a></p>

## Author

**Aditya Sidham**, applied AI, iOS and backend engineer in Los Angeles.

[![Website](https://img.shields.io/badge/adityasidham.site-7C93FF?style=for-the-badge&labelColor=0D1424)](https://adityasidham.site)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/adityasidham/)
[![GitHub](https://img.shields.io/badge/More%20projects-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/AdityaSidham)

Found a bug or have an idea? [Open an issue](https://github.com/AdityaSidham/FitandFine/issues).
