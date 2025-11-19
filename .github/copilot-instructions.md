## Quick orientation

This repository contains two cooperating projects:
- `intencion_siembra/` — Flutter mobile app (Dart 3.x) that uses Hive for local storage, SharedPreferences for simple prefs, and a token-based Laravel backend API.
- `exportadores/` — Laravel backend (API endpoints under `/api/*`) that serves authentication and catalog data.

AI agents should prioritize the Flutter app. Key runtime flow: user logs in (POST `/api/login`) → client saves Bearer token (`SharedPreferences` key `user_token`) → client calls `sincronizarCatalogos(token, productorId)` to populate Hive boxes → app uses local Hive boxes (e.g. `boletas`, `fincas`, `lotes`, `users`, `variedades`, etc.).

## Files to read first
- `lib/services/api_service.dart` — all HTTP calls and headers; look for `[LOGIN]` debug prints.
- `lib/services/sync_service.dart` — central catalog sync (`sincronizarCatalogos`) and typed sync helpers.
- `lib/screens/login_screen.dart` — login flow: saves token, triggers sync, and does offline bcrypt check using `users` box.
- `lib/screens/home_screen.dart` — dashboard; expects `token` and `productorId` via route args and reads `boletas` Hive box.
- `lib/models/*.dart` — Hive models (ensure unique `typeId`s and adapters registered in `lib/main.dart`).
- `lib/services/outbox_service.dart` — background outbox sync invoked on resume or pull-to-refresh.

## Important repo conventions / patterns
- Spanish identifiers and UI text are common (e.g., `productorId`, `sincronizarCatalogos`).
- Hive box names are hard-coded strings (example: `'boletas'`, `'fincas'`, `'users'`). Use the named boxes rather than inventing new ones.
- Adapters are registered in `main.dart`; never register the same adapter/typeId twice or app will crash.
- Offline login: server stores bcrypt hashes; client compares via `bcrypt` package with `BCrypt.checkpw(plain, hash)`.
- Token persistence: `SharedPreferences` key `user_token`. Last-sync timestamp saved (search for `last_sync_at`).

## Common tasks & commands
- Flutter (mobile app): in `intencion_siembra/` run `flutter pub get`, `flutter run -d <deviceId>` or `flutter logs` to stream logs.
  - Search logs for tags: `[LOGIN]` and `[SYNC]` to diagnose authentication and catalog sync results.
- Laravel (backend): in `exportadores/` typical steps are `composer install`, `php artisan migrate --seed` and `php artisan serve` (or run via XAMPP/Apache if present). API tests live under `tests/` and `phpunit.xml` is present.
- To manually verify an endpoint (example):
  - Login: `curl -X POST "http://<host>/api/login" -d "email=...&password=..."` → expects JSON with `token` and `user.productor_id`.
  - Catalog: `curl -H "Authorization: Bearer <token>" "http://<host>/api/fincas?productor_id=<id>"`

## Debugging tips specific to this codebase
- If only one catalog (e.g. `fincas`) is saved, run app and capture `[SYNC]` lines — they show per-collection counts. Use `flutter run` and paste those lines.
- Common runtime errors: duplicate Hive adapter registration, missing route args (HomeScreen expects `token` and `productorId`), and RenderFlex overflow on small screens — wrap long Column content in `SingleChildScrollView`.
- When editing models, update the Hive `typeId` carefully and re-run the app; mismatched typeIds cause silent decode failures.

## What to change and where (examples)
- Add a new API call: put it in `lib/services/api_service.dart`, return parsed JSON, and call it from `sync_service.dart` to persist into the corresponding Hive box.
- Add a new Hive model: create `lib/models/your_model.dart`, give a unique `typeId`, generate/register an adapter, and register it in `lib/main.dart` before `runApp()`.

## Safety & scope
- Do not change the string names of Hive boxes or SharedPreferences keys unless migrating data intentionally.
- Prefer small, targeted edits. Tests exist in both projects; run them after changes.

If anything in this file is unclear or you want more examples (e.g., sample cURL outputs, exact log lines to look for, or a quick checklist for adding a new synchronized catalog), tell me which area to expand.
