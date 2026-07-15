# Secret Browser

A privacy-first, cross-platform browser (Android · iOS · macOS · Windows) built
with Flutter. One code base, three pillars:

1. **Local anonymous browsing** — nothing about your browsing is written to
   disk: no history, no persistent cookies, no on-disk cache. Every WebView runs
   incognito with in-memory-only state.
2. **Always-visible panic button** — a floating red "X" that stays on top of
   everything and can be dragged anywhere.
3. **Wipe + close** — tapping the X (or pressing the shortcut) instantly wipes
   all browsing data and then closes the app.

> ⚠️ **Honest privacy limit — read this.**
> Secret Browser gives you **local** anonymity: it stops browsing traces from
> being stored **on the device**. It does **not** hide your IP address from the
> websites you visit or from your Internet provider, and it is **not** Tor and
> **not** a VPN. Network-level anonymity (hiding your IP) is on the
> [roadmap](#roadmap--out-of-scope), not implemented yet.

---

## How the privacy guarantees work

| Concern | How it's handled |
|---|---|
| Cookies | `incognito: true` keeps them in memory; wiped on panic and on boot |
| HTTP cache | `cacheEnabled: false` + `InAppWebViewController.clearAllCache()` on wipe |
| Web SQL database | `databaseEnabled: false` (no on-disk DB) |
| DOM storage | on at runtime so sites work; `localStorage`/`sessionStorage` cleared on wipe |
| Third-party cookies | blocked (`thirdPartyCookiesEnabled: false`) |
| Tracking | `DNT: 1` request header |
| Telemetry | **none** — no analytics, crash reporting, or "phone home" of any kind |
| History/tabs | in memory only; never serialized to disk |

A **preventive wipe** runs at every startup, so even a crash can't leave stale
data behind. Because incognito-profile isolation has known bugs on some
platforms (WKWebView, WebView2), the app **also** clears cookies, cache and web
storage explicitly rather than trusting the incognito flag alone.

## Wipe + close behavior per platform

The wipe order is always the same (stop loads → clear history → clear DOM
storage → delete cookies/cache/web storage → drop tabs → close). Each step is
independently guarded: if one step fails the rest still run — **the wipe never
aborts halfway**.

| Platform | On wipe |
|---|---|
| Android | `SystemNavigator.pop()` then `exit(0)` — the app really closes |
| Windows | `exit(0)` — the app really closes |
| macOS | `exit(0)` — the app really closes |
| iOS | The app is **not** self-terminated (Apple rejects apps that call `exit`). Instead it wipes and swaps to an inert **decoy calculator** screen. |

## Panic triggers

- **Tap the floating red "X"** — single tap, no confirmation dialog.
- **`Ctrl` / `Cmd` + `Shift` + `X`** — global keyboard shortcut.
- **`Esc` pressed twice quickly** (within 600 ms) — alternative shortcut.

All three run the exact same wipe. Keyboard shortcuts work natively on desktop
and with a physical keyboard on mobile. (When a native WebView holds keyboard
focus it may swallow key events before Flutter sees them — the floating button
always works.)

---

## Getting started

Requires the **Flutter SDK** (stable channel). Verify your setup with
`flutter doctor`.

```bash
flutter pub get
flutter run -d macos      # or: -d windows, or an Android/iOS device id
```

### Per-platform build

| Platform | Command | Toolchain needed |
|---|---|---|
| Android | `flutter build apk` | Android Studio + SDK (minSdk 19+) |
| iOS | `flutter build ios` | Mac + Xcode + Apple Developer account |
| macOS | `flutter build macos` | Mac + Xcode (deployment target 10.15+) |
| Windows | `flutter build windows` | Visual Studio with the "Desktop C++" workload (for the WebView2 backend) |

Native configuration already applied: Android `INTERNET` permission, macOS
`com.apple.security.network.client` entitlement (Debug + Release), and
`NSAllowsArbitraryLoads` on iOS/macOS so the browser can open any site. The
Windows WebView2 backend is provided by the `flutter_inappwebview` plugin.

Compiling, signing and publishing depend on those toolchains being installed on
your machine — this project ships all of the code, not the SDKs.

## Tech stack

- **Flutter** (stable), Dart null-safety.
- **[`flutter_inappwebview`](https://pub.dev/packages/flutter_inappwebview) `^6.1.5`**
  — the only WebView package covering all four targets with fine-grained
  cookie/cache control and incognito.
- **[`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) `^3.3.2`**
  — state management; no loose global mutable state.

## Project layout

```
lib/
  main.dart                     # bootstrap + preventive wipe + ProviderScope
  app.dart                      # MaterialApp (dark), providers, panic wiring
  core/
    privacy_config.dart         # anonymous WebView settings + cleaners + preventive wipe
    panic_service.dart          # the wipe+close heart of the app (guarded, tested)
    platform_exit.dart          # per-platform close + iOS decoy screen
    keyboard_shortcuts.dart     # Ctrl/Cmd+Shift+X and double-Esc
  features/
    browser/                    # tab manager, WebView screen, address bar
    panic/                      # floating draggable X button + overlay
  widgets/                      # shared UI (anonymous badge)
test/
  panic_service_test.dart       # wipe ordering, per-step failure, idempotency
  privacy_config_test.dart      # anonymous settings + DNT
  widget_test.dart              # boot / new-tab smoke tests
```

## Testing

```bash
flutter analyze   # zero errors/warnings
flutter test      # all green
```

## Roadmap / out of scope

Not implemented yet (deliberately):

- **Network anonymity (Tor/VPN)** to hide your IP — the biggest limitation above.
- Sync, bookmarks, extensions.
- Ad/tracker blocker (possible phase 2).
- Store publishing (App Store / Play / Microsoft Store) — needs developer
  accounts and signing.

## Principles

- **Privacy over convenience.** When in doubt, persist nothing.
- **The wipe never fails silently.** A failed step is logged and skipped; the
  wipe continues and still closes.
- **Zero telemetry.** No library that "phones home".
- **Honesty.** We don't promise network anonymity the app doesn't deliver.
