# PetalPop

PetalPop is a Flutter app with local demo mode and optional Supabase-backed
authentication and data access.

## Run locally

```powershell
flutter pub get
flutter run
```

Without Supabase build defines, the existing local/demo experience is used.

## Supabase setup

Read [Supabase setup and migration notes](docs/SUPABASE_SETUP.md) before running
the migration or configuring a Supabase project. The app requires a Supabase
URL and publishable key at build time; never use a service-role key in the app.

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Verify

```powershell
dart format lib test
flutter analyze
flutter test
```
