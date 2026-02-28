# AGENTS.md

## Must-follow constraints
- **Backend Architecture**: Every FastAPI endpoint **must** use Pydantic models for request/response validation.
- **Async Database**: All SQLAlchemy operations **must** use the `asyncio` extension; never use synchronous DB calls.
- **Vector Ops**: All vector-related operations (pgvector) **must** be asynchronous.
- **Flutter Architecture**: Maintain the strict `data/domain/presentation` layer separation for all features.
- **Error Handling**: Use `dartz` (`Either`) for functional error handling in the Flutter domain/data layers.
- **Environment**: Do not hardcode secrets. Use the specific `.env` file corresponding to the environment (dev/prod/test).

## Validation before finishing
- **Backend**: Run `pytest` if adding logic to the API.
- **Frontend**: `flutter analyze` must pass with zero errors.
- **Dependencies**: New backend packages must be added to `backend/requirements.txt`. New Flutter packages must be added to `pubspec.yaml`.

## Repo-specific conventions
- **Dependency Injection**: Use `get_it` for service locator pattern in Flutter.
- **State Management**: Prefer `flutter_bloc` for complex feature logic; `provider` is reserved for simple dependency injection or light state.
- **Models**: Use `Equatable` for all Flutter models/entities to ensure proper Bloc state comparisons.

## Important locations
- **Backend Core**: `backend/app/core/` for config, security, and shared utilities.
- **API Routes**: `backend/app/presentation/` contains the FastAPI routers.
- **Flutter Features**: `lib/features/` is the primary work area for app logic.

## Change safety rules
- **Supabase**: Do not modify existing table schemas without checking for breaking changes in the Flutter `data` layer.
- **TMDB API**: Any changes to movie fetching logic must respect TMDB rate limits and match existing Pydantic models in `backend/app/data/models/`.
- **Backward Compatibility**: API response structures must remain backward compatible unless a full migration is requested.
