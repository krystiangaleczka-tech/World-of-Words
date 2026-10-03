# 0007 — Permanent application identifiers

- Status: accepted (T-0026, 2026-10-03). Chris explicitly selected `com.mazen.worldofwordgame`.
- Scope: store/application identity only. This does not choose the final store-facing product name.

## Decision

Neutral production identifier on both platforms:

- Android `applicationId`: `com.mazen.worldofwordgame`
- iOS bundle ID: `com.mazen.worldofwordgame`

Throwaway S1 apps use:

- Android `applicationId`: `com.mazen.worldofwordgame.spike`
- iOS bundle ID: `com.mazen.worldofwordgame.spike`

The `.spike` ID is disposable and never becomes the production app. T-0027/T-0028 use it for all
throwaway S1 provider and store resources.

## Rationale

- The candidate is independent of the working title "World of Words", so a later trademark/store-name
  change would not force a package identity change.
- Android and iOS would share the same base identifier to reduce cross-provider configuration mistakes.
- A dedicated `.spike` namespace keeps S1 receipts, analytics, ads and test signing separate.
- The chosen `com.mazen` namespace is independent of the developer surname and was explicitly approved
  by Chris before the first production store record/upload.

## Consequences

- The first production Play Console and App Store Connect records use
  `com.mazen.worldofwordgame`.
- Later store-facing name changes do not change these identifiers.
- Provider config files must match the production or spike ID exactly.

## Revisit if

Only before the first production store record/upload, and only by explicit Chris decision. After the
first production upload, superseding this decision must not rename the existing store app identifier.
