# MotivPlan

Planning quotidien en séquence, capture en un geste, aucune culpabilisation. App iOS native (SwiftUI, SwiftData) et backend de synchronisation FastAPI.

Documentation : [cahier des charges](docs/cahier-des-charges.md), [plan de développement](docs/plan-dev.md), [décisions d'architecture](docs/decisions.md).

## Structure

```
docs/       cahier des charges, plan, ADR
ios/        projet XcodeGen, app, widget, packages Swift
backend/    API FastAPI (uv, Docker)
```

## iOS (Mac, Xcode 27, macOS 26.6+)

```bash
brew install xcodegen
cd ios
xcodegen generate          # produit MotivPlan.xcodeproj, jamais édité à la main
open MotivPlan.xcodeproj
```

Avant le premier build sur appareil : renseigner `DEVELOPMENT_TEAM` dans `ios/project.yml` (compte Apple Developer payant recommandé).

Tests des packages :

```bash
cd ios/Packages/TimelineEngine && swift test   # aussi sous Windows
cd ios/Packages/MotivPlanCore && swift test    # macOS uniquement
```

## Backend (Windows, macOS ou Linux)

```bash
cd backend
uv sync
uv run pytest
uv run uvicorn app.main:app --reload    # http://localhost:8000/health
docker compose up --build               # même API en conteneur
```
