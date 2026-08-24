# CLAUDE.md

This file guides Claude Code in this repository. It is derived from `AGENTS.md`,
which remains the canonical source of product/architecture rules — if the two
ever disagree, `AGENTS.md` wins and this file should be updated to match.

## Project Snapshot

- Stack: `Flutter` / `Dart` (SDK `^3.12.2`)
- Platform scope: `Android` and `iOS`
- Product scope: `customer-only` mobile app for `VZ Food`
- Consumes the `VZ Food Mobile API` (separate backend project, endpoints under `/api/mobile/...`)
- Auth: `Supabase Auth`; mobile sends `Authorization: Bearer <token>`
- Key deps: `dio` (HTTP), `go_router` (nav), `supabase_flutter` (auth), `geolocator` (GPS),
  `flutter_dotenv` (env), `image_picker`, `intl`

## Product Boundary

- Customer-only. Do **not** build admin, kitchen, platform, or staff workflows here.
- In scope: home, marketplace, nearby branches, storefront, customer auth, bag, checkout, customer orders.
- Nearby discovery is **GPS-first** and must use real branch distance — never a placeholder
  or "first active branch" fallback. If GPS permission is denied, do not fake proximity.

## Backend Contract

- Base URLs/keys come from environment, never hardcoded. Env vars: `SUPABASE_URL`,
  `SUPABASE_ANON_KEY`, `API_BASE_URL` (see `.env.example`, loaded via `flutter_dotenv`).
- Never use service-role keys in this app.
- Backend is the source of truth for business data and order lifecycle; don't duplicate its rules.
- Docs: `https://vzfood.ajedev.com/mobile-api-docs`, OpenAPI at `https://vzfood.ajedev.com/api/mobile/openapi`.
- Current endpoint surface (public + authenticated) is listed in `AGENTS.md` — check there
  before assuming a route exists, and don't implement undocumented endpoints as stable contract.

## Architecture — How This Repo Is Actually Organized

`lib/` is layered per feature under `lib/features/<feature>/`:

```
presentation/    screens & widgets
application/     controllers (plain Dart classes, no external state package)
domain/          models / payload types
infrastructure/  API clients (one *_api.dart per feature, built on dio via app_http_client)
```

Cross-cutting code lives in `lib/core/`: `auth/` (Supabase session), `network/` (http client,
error normalization), `location/` (GPS), `config/`, `theme/`, `widgets/`, `utils/`.

**State management convention (important, overrides generic Flutter advice):** this project
does **not** use Riverpod, Bloc, or Provider. Controllers are plain Dart classes injected with
their API client/service dependencies (e.g. `HomeController(this._homeApi, this._locationService)`)
that return typed result objects; screens are `StatefulWidget`s that call the controller and hold
UI state with `setState`. Keep using this pattern for consistency — don't introduce a new state
management library without an explicit product decision.

## Working Style (from AGENTS.md)

- Be senior, direct, practical. Keep scope tight; avoid speculative abstractions.
- Preserve the presentation / application / domain / infrastructure separation above.
- Prefer explicit contracts over implicit assumptions.
- Add comments only where they explain architectural boundaries, non-obvious flows, or future
  extension points — not line-by-line narration of obvious code.
- Naming: use business terms (`branch`, `tenant`, `storefront`, `bag`, `checkout`, `order`).
  Avoid vague names (`data`, `info`, `manager`, `handler`) unless scope is obvious.

## Networking & Errors

- All API calls go through the feature's `infrastructure/*_api.dart`, built on the shared
  `app_http_client.dart`. Don't call `dio`/http directly from widgets or controllers.
- Always send `Authorization: Bearer <token>` on authenticated endpoints.
- Normalize errors via `network_exception.dart`; distinguish validation, auth/session,
  connectivity, and backend (5xx) failures. Never silently swallow a failure.
- Assume unstable mobile connectivity: handle loading, retry, and empty states intentionally.

## Spec-First for Non-Trivial Work

Before coding a non-trivial change, sketch: Problem, Scope (which mobile surfaces),
Actors (usually `customer`), Business Rules, API Impact, UI/UX Impact, Failure Modes
(offline / unauthorized / partial data), Verification.

## What To Avoid

- Admin/staff behavior, service-role keys, hidden global state.
- Hardcoded tenant-specific behavior unless explicitly required.
- Invented fallback proximity/location behavior.
- New state-management libraries or architectural layers without a stated reason.

## Verification Before Claiming Done

Run what's applicable and report exactly what you ran (never claim a check you didn't run):

- `flutter analyze`
- `flutter test` (relevant tests)
- App runs on target platform, if the change needs it
- Manual check of the affected flow, including the auth path if touched
- Confirm the endpoint contract still matches backend expectations

## Delivery Expectations

- Explain what changed, what you verified, and any assumptions/unresolved risk.
- Keep responses concise but complete; suggest next steps only when useful.

## Project Skills

Local skills adapted from `.agents/skills/` (a gitignored, locally-managed skill set — see
`.claude/skills/`, itself gitignored as a derived copy) are available and auto-load by
relevance:

| Skill | Use for |
|---|---|
| `flutter-expert` | Widgets, navigation (GoRouter), performance. **Ignore its Riverpod/Bloc examples** — follow this repo's plain-controller convention instead. |
| `dart-best-practices` | Idiomatic Dart, style, effective-Dart guidance. |
| `flutter-testing` | Unit/widget/integration tests, mocking `dio`/Supabase, fixing `pumpAndSettle`/finder issues. |
| `flutter-animations` | Implicit/explicit animations, Hero transitions, staggered/physics motion. |
| `accessibility` | a11y pass on screens (labels, contrast, screen-reader/keyboard support). |
| `frontend-design` | Distinctive, non-generic UI when building new screens or components. |
| `bash-defensive-patterns` | Writing/reviewing any shell scripts (CI, tooling) in this repo. |
| `seo` | Not applicable to this mobile app (no web/SEO surface) — skip unless scope changes. |

If `.agents/skills/` is updated (new skill installed, version bump per `skills-lock.json`),
re-sync by copying the changed folder(s) into `.claude/skills/`.
