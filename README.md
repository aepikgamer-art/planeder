# Planeder ✈️💕

Tinder, but for planes. Swipe through airliners with real photos and data from
[JetAPI](https://www.jetapi.dev) (JetPhotos + FlightRadar24).

**Built entirely in GitHub Actions. No Mac required.**

## Install on your iPhone (no Mac)

1. Make sure this repo is **public**.
2. Go to **Actions** → **Build unsigned IPA** → **Run workflow** (or push a tag like `v1.0.0`).
3. Wait for the green checkmark. The workflow publishes an unsigned IPA and an
   AltStore-format source at `docs/source.json`.
4. In AltStore (or SideStore / any signing app that supports AltStore sources):
   **Sources** → **+** → add:
   `https://raw.githubusercontent.com/YOUR-USERNAME/planeder/main/docs/source.json`
5. Install **Planeder** from that source. Your Apple ID signs it locally.
   Free Apple ID = refresh every 7 days (AltStore can do this on-device).

## Updating

Push a new tag (`v1.0.1`) or re-run the workflow. The source updates itself and
your store shows an update.

## Customizing the plane pool

JetAPI only takes a registration (`?reg=N123AB`), so the deck comes from a
curated pool in `DeckViewModel.regPool`. Add your favorite tail numbers there.

## Tech

- SwiftUI, iOS 17+, real Liquid Glass (`glassEffect`) on iOS 26+, ultraThinMaterial fallback below.
- XcodeGen generates the project inside the workflow.
- Unsigned build (`CODE_SIGNING_ALLOWED=NO`) → AltStore resigns on device.
