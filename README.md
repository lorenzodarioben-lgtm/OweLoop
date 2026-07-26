# OweLoop

OweLoop is a mobile app for recording shared expenses clearly, without limits or opaque balances. It is being built for students, roommates, couples, and group travellers who need an understandable record of who paid, who owes, and why.

The initial implementation lives in [`mobile/`](mobile/). It uses Flutter, Supabase, Riverpod, and GoRouter.

## Getting started

1. Install the current stable Flutter SDK.
2. Copy `mobile/.env.example` to `mobile/.env`.
3. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` with development-project values. Do not use a Supabase service-role key in the app.
4. Run the commands from `mobile/`:

   ```sh
   flutter pub get
   flutter run
   ```

`mobile/.env` is intentionally ignored by Git. Missing or blank values produce a clear development configuration screen.

## Repository layout

- `mobile/` — Flutter Android and iOS application.
- `supabase/migrations/` — future version-controlled database migrations.
- `docs/` — product, architecture, and delivery planning.
- `.github/workflows/` — continuous integration.

See the [product requirements](docs/product-requirements.md), [architecture](docs/architecture.md), and [roadmap](docs/roadmap.md).
