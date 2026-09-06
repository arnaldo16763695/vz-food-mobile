# AGENTS.md

This file guides coding agents working in this Flutter mobile app repository.

## Project Snapshot

- Stack: `Flutter`, `Dart`
- Platform scope: `Android` and `iOS`
- Product scope: `customer-only`
- This app consumes the `VZ Food Mobile API`
- The backend is a separate project and exposes endpoints under `/api/mobile/...`
- Authentication is handled with `Supabase Auth`
- Mobile clients authenticate with `Supabase` access tokens sent as `Authorization: Bearer <token>`

## Product Boundary

- This mobile app is `customer-only`
- Do not build `admin`, `kitchen`, `platform`, or `staff` workflows in this repo unless the product requirement explicitly changes
- Mobile scope includes:
  - `home`
  - `marketplace`
  - `nearby branches`
  - `storefront`
  - `customer auth`
  - `bag`
  - `checkout`
  - `customer orders`
- Nearby discovery is `GPS-first`
- Nearby results must be based on real branch distance, not placeholder logic or “first active branch”

## Backend Contract

- Backend base URL should be configured by environment
- Supabase project URL and anon key should be configured by environment
- Do not hardcode production hosts, API keys, or tokens
- Do not use service-role keys in the mobile app
- Treat the backend API as the source of truth for business data and order lifecycle

## Expected Environment Variables

Use names like these in mobile configuration:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `API_BASE_URL`
- `AUTH_REDIRECT_URL`

Example intent:

- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_ANON_KEY`: public anon key for mobile auth
- `API_BASE_URL`: base URL of the web/backend project that serves `/api/mobile/...`
- `AUTH_REDIRECT_URL`: deep link Supabase Auth redirects to after email confirmation
  and password recovery (default `vzfood://auth-callback`); must be allow-listed in the
  Supabase project and registered as a native URL scheme on Android/iOS

## Current API Surfaces

Reference docs:

- Mobile API docs: `https://vzfood.ajedev.com/mobile-api-docs`
- OpenAPI spec: `https://vzfood.ajedev.com/api/mobile/openapi`

The backend currently exposes these customer-facing endpoints:

### Public

- `GET /api/mobile/home` (optional `lat`/`lng`; returns `nearbyBranches`)
- `GET /api/mobile/brands`
- `GET /api/mobile/branches/nearby?lat=...&lng=...&limit=...` (`limit` 1–50, default 20)
- `GET /api/mobile/branches/[branchId]` (branch detail: address, active flag, tenant)
- `GET /api/mobile/storefront/[tenantSlug]?branchId=...`
- `GET /api/mobile/storefront/[tenantSlug]/menu?branchId=...`
- `GET /api/mobile/storefront/[tenantSlug]/payment-settings`
- `GET /api/mobile/storefront/[tenantSlug]/search?branchId=...&q=...`
- `GET /api/mobile/openapi`

### Authenticated

- `GET /api/mobile/customer/me`
- `GET /api/mobile/storefront/[tenantSlug]/bag?branchId=...`
- `DELETE /api/mobile/storefront/[tenantSlug]/bag?branchId=...`
- `POST /api/mobile/storefront/[tenantSlug]/bag/items`
- `PATCH /api/mobile/storefront/[tenantSlug]/bag/items/[bagItemId]`
- `DELETE /api/mobile/storefront/[tenantSlug]/bag/items/[bagItemId]?branchId=...`
- `POST /api/mobile/storefront/[tenantSlug]/bag/items/[bagItemId]?branchId=...`
- `POST /api/mobile/storefront/[tenantSlug]/checkout`
- `GET /api/mobile/storefront/[tenantSlug]/orders`
- `GET /api/mobile/storefront/[tenantSlug]/orders/[orderId]`
- `POST /api/mobile/storefront/[tenantSlug]/orders/[orderId]/payment-proof`

### Payload notes

- Combo products: `StorefrontProduct.comboComponents[]` and
  `CustomerOrderDetail.items[].comboComponents[]` list `{componentProductName,
  componentVariantName?, quantity}`. Empty for non-combo products.
- `CustomerOrderDetail.items[].modifiers[]` carries the per-line modifier snapshot
  `{modifierGroupName, modifierOptionName}`.
- Bag mutations (`POST/PATCH/DELETE .../bag/items...`) return
  `{ok, error?, item?, quantity?}` — a business rejection is `ok:false` with a
  human `error`; surface it, don't assume success from a 2xx.

## Working Style

- Be senior, direct, and practical
- Keep scope tight
- Prefer simple, maintainable solutions
- Avoid speculative abstractions
- Add important comments where they help a human programmer understand architectural boundaries, non-obvious flows, or future extension points
- Write those comments to guide maintenance work, not to restate obvious code line-by-line
- Preserve a clean separation between:
  - UI
  - state
  - API client
  - auth/session
  - domain models
- Prefer explicit contracts over implicit assumptions

## Specification-Driven Development

For non-trivial work, define the target behavior before coding.

### Minimum Spec Checklist

- `Problem`: what is missing, broken, or changing?
- `Scope`: which mobile surfaces are affected?
- `Actors`: usually `customer`
- `Business Rules`: what must always remain true?
- `API Impact`: which endpoints, payloads, or auth flows are affected?
- `UI/UX Impact`: what should the customer see or be able to do?
- `Failure Modes`: what happens offline, unauthorized, or with incomplete data?
- `Verification`: what proves the change works?

## Architecture Expectations

### Layers

Prefer clear layers:

- `presentation`
- `application`
- `domain`
- `infrastructure`

At minimum, separate:

- screens/widgets
- API client code
- auth/session handling
- models/entities
- feature state

### State Management

- Use one clear state approach consistently across the repo
- Avoid mixing many state management patterns without reason
- Keep server data rules out of widget code when possible
- Do not scatter API calls directly across random widgets

### Networking

- Centralize API requests in dedicated clients/services
- Always send `Authorization: Bearer <token>` for authenticated endpoints
- Normalize API errors into app-friendly failures
- Handle timeouts, no connection, 401, 403, 404, and 500 clearly

### Auth

- Use `Supabase Auth` for customer login/session
- Keep token access centralized
- Do not duplicate session logic across screens
- Never expose privileged keys in the app

## GPS and Nearby Discovery

- Nearby branch discovery is `GPS-first`
- If GPS permission is denied, do not fake proximity
- If fallback behavior is introduced later, specify it explicitly
- Keep distance calculations aligned with backend behavior
- Nearby results should be branch-based, not brand-only

## UI/UX Principles

- Build for real mobile usage, not web screens transplanted into Flutter
- Keep flows fast and operational
- Centralize brand styles such as colors and font definitions so future rebranding does not require widget-by-widget edits
- Prioritize:
  - home discovery
  - nearby branches
  - category/menu browsing
  - bag clarity
  - checkout confidence
  - order tracking clarity
- Avoid generic placeholder-heavy UI once feature behavior is known

## Error Handling

- Fail clearly at system boundaries
- Show useful customer-facing messages
- Keep developer diagnostics precise
- Do not silently swallow API or auth failures
- Distinguish between:
  - validation errors
  - auth/session errors
  - connectivity errors
  - backend failures

## Offline and Resilience

- Assume mobile users will experience unstable connectivity
- Handle loading, retry, and empty states intentionally
- Do not assume a request always succeeds
- If caching is introduced, specify:
  - what is cached
  - when it expires
  - when it must be invalidated

## Naming

- Use names that reflect business meaning
- Prefer `branch`, `tenant`, `storefront`, `bag`, `checkout`, `order`
- Avoid vague names like `data`, `info`, `manager`, `handler` unless the scope is obvious

## What To Avoid

- Do not build admin behavior in this repo
- Do not use service-role keys
- Do not duplicate backend business rules unnecessarily
- Do not rely on hidden global state
- Do not hardcode tenant-specific behavior unless explicitly required
- Do not invent fallback proximity behavior
- Do not implement undocumented API assumptions as if they were stable contract

## Verification

Before claiming a task is done, verify what is appropriate:

- `flutter analyze`
- relevant tests
- app runs on target platform if needed
- manual validation of the affected flow
- auth flow still works
- endpoint contract still matches backend expectations

Never claim success for checks you did not run.

## Delivery Expectations

- Explain what changed
- Mention verification performed
- Mention assumptions and unresolved risks
- Suggest next steps only when useful
- Keep responses concise but complete
