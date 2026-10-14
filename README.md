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
uv run pytest                                        # SQLite en mémoire
MOTIVPLAN_TEST_DATABASE_URL=postgresql+psycopg://... uv run pytest   # même suite sur Postgres
MOTIVPLAN_API_TOKEN=dev uv run uvicorn app.main:app --reload         # http://localhost:8000/docs
```

API : `GET /health` (sans jeton), `POST /sync`, routes de débogage `GET /tasks`, `/sections`, `/sessions`, `/days/{yyyy-mm-dd}`, `/progress`. Toutes sauf `/health` exigent `Authorization: Bearer <MOTIVPLAN_API_TOKEN>`.

Nouvelle migration après un changement de modèle : `uv run alembic revision --autogenerate -m "..."`, puis remplacer `app.db.UTCDateTime(...)` par `sa.DateTime(timezone=True)` dans le fichier généré. `tests/test_migrations.py` échoue si migrations et modèles divergent.

### Déploiement sur le VPS

1. Installer Docker, cloner le repo dans `/opt/motivplan`, pointer le DNS du domaine vers le VPS.
2. `cd backend && cp .env.example .env`, puis remplir `DOMAIN`, `POSTGRES_PASSWORD`, `MOTIVPLAN_API_TOKEN`.
3. `docker compose up -d --build` : Postgres, API (migrations appliquées au démarrage) et Caddy (HTTPS automatique).
4. Sauvegarde quotidienne : `crontab -e`, puis `0 3 * * * cd /opt/motivplan/backend && ./scripts/backup.sh >> backups/backup.log 2>&1`.
5. Restauration : `gzip -dc backups/<fichier>.sql.gz | docker compose exec -T postgres psql -U motivplan -d motivplan`.
