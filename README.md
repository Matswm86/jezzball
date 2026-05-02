# JezzBall

Faithful Android remake of the 1992 Microsoft Entertainment Pack 3 classic.
EGA palette (black field, cyan walls, red atoms), 50 levels, no ads, no IAP.

## Gameplay

Tap the field to start a wall growing in two directions from your tap.
Cap off 75% of the field while bouncing atoms can't reach the growing wall heads.
Toggle build orientation (vertical / horizontal) with the bottom-left button.

- Level **N** spawns **N** atoms.
- Lives per level: `max(3, N + 2)`.
- Win at 75% capture; out of lives = retry.

## Build

Godot 4.6.2 + GitHub Actions. Push to `main` builds an APK and posts it to the
rolling `latest` GitHub release. Tag `vX.Y.Z` for a stable release.

The CI uses an `ANDROID_DEBUG_KEYSTORE_BASE64` repo secret for a stable
debug-signed APK so reinstalls don't fail with signature-mismatch.

## Status

v0.1.0 (initial port). Single-screen, portrait, no sound yet.
