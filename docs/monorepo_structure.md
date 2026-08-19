# Enterprise Monorepo Structure

This document outlines the standard "market developer type" folder structure for the complete system, cleanly separating the Flutter App, Node.js Backend, and other necessary domains.

## Root Level Architecture

```text
smart_dukan/
│
├── app/                  # Flutter Mobile Application
├── backend/              # Node.js Express Backend
├── docs/                 # Documentation (App details, architecture)
├── shared/               # Shared assets, scripts, or configurations
└── .github/              # CI/CD workflows (if using GitHub Actions)
```

---

## 1. App (Flutter Mobile) - Clean Architecture
*Based on industry-standard Clean Architecture (as per your reference image).*

```text
app/
├── lib/
│   ├── src/
│   │   ├── core/         # Common utilities, error handling, app constants
│   │   │   ├── constants/
│   │   │   ├── error/
│   │   │   └── utils/
│   │   │
│   │   ├── data/         # Data sources (API, local DB), models, repositories
│   │   │   ├── models/
│   │   │   ├── datasources/
│   │   │   └── repositories/
│   │   │
│   │   ├── domain/       # Business logic (UseCases, entities, repository contracts)
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   │
│   │   └── presentation/ # All UI code: screens, widgets, navigation, styling
│   │       ├── common/   # Reusable UI elements (buttons, inputs)
│   │       ├── dialogs/  # App-wide dialogs
│   │       ├── screens/  # Top-level application screens
│   │       │   ├── auth/
│   │       │   ├── home/
│   │       │   ├── inventory/
│   │       │   ├── sales/
│   │       │   └── settings/
│   │       ├── navigation/# Routing logic (app_router, navigation_service)
│   │       └── themes/   # Light/dark themes, color schemes, typography
│   │
│   ├── app.dart          # Main application widget setup
│   └── main.dart         # Application entry point
│
└── test/                 # Testing directory
    ├── unit/
    ├── widget/
    └── integration/
```

---

## 2. Backend (Node.js/Express)
*Enterprise standard MVC/Service structure.*

```text
backend/
├── src/
│   ├── config/           # Environment variables, database connection
│   ├── controllers/      # Request handlers
│   ├── middlewares/      # Custom middlewares (auth, error handling)
│   ├── models/           # Database schemas/models (Mongoose, Sequelize, etc.)
│   ├── routes/           # API route definitions
│   ├── services/         # Core business logic (keeps controllers lean)
│   ├── utils/            # Helper functions, loggers
│   └── app.js            # Express app setup
│
├── tests/                # API and unit tests
├── .env.example
├── package.json
└── server.js             # Server entry point
```

---

## 3. Others (Docs & Shared)

```text
docs/
├── architecture/         # System diagrams, ADRs
├── api/                  # Postman collections, Swagger/OpenAPI specs
└── project_requirements.md

shared/
├── scripts/              # Useful scripts for DB seeding, deployment
└── assets/               # Shared global assets (logos, placeholders)
```
