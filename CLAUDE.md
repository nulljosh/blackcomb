# Blackcomb

v1.0.0, WebKit browser. Named after the mountain above Whistler (Blackcomb, 2026-10-18; before that Madobe, Lucarne, Nook). Bundle id stays com.nulljosh.lucarne and the Cloudflare Worker stays `madobe`; everything else says Blackcomb. One xcodegen target for iOS and macOS, a handful of SwiftUI files. No web build (it's a browser). Plain English words and Vancouver's best-known peaks (Grouse, Seymour, Cypress) are all taken on the App Store; the probe log is in memory.

## Files

- `ios/App/BlackcombApp.swift`: app entry and the menu commands (New Tab, Private Tab, Find, Bookmarks, History, Settings).
- `ios/App/Browser.swift`: `resolve()` (input to URL, uses the chosen `SearchEngine`), `Page` (one `WKWebView` + navigation/UI delegate; opens `target=_blank` links as tabs, hands mailto:/tel: to the system), `Tabs` (open tabs, restored at launch, private tabs never restored).
- `ios/App/Library.swift`: bookmarks and history as two JSON files in Application Support (history capped at 500, newest first, repeat visits move to the top).
- `ios/App/Services.swift`: `Settings` (engine, homepage, tracker blocking), `ContentBlocker` (WebKit content rule list of ad and tracking hosts), `Services` (shared state and the open sheet).
- `ios/App/Views.swift`: browser chrome, tab strip, find bar, Bookmarks, History and Settings screens.
- `ios/App/SiteRules.swift`: per-site rules (`SiteRule`, `SiteKey`, `SiteRules` store, image-block rule JSON, `RuleListHost`) and the Site Rules sheet. Applied in `Page.decide` (scripts, dark user script, zoom) and a content rule list (images).
- `ios/App/Start.swift`: the start page a new tab shows (search, reading list, bookmarks, recent, what the app does). Shown while `page.web.url` is nil; an empty homepage setting means the start page.
- `ios/App/Reader.swift`: the reading list. `Page.textScript`/`pageText()` pull the article text, `Library.savePage` keeps it in `saved.json`, `ReaderView` reads it offline with a text size and read-aloud (`Speaker`, AVSpeechSynthesizer).
- `ios/App/Pair.swift`: `PairModel` (split, swap, layout rule) shared; `PairView` is iOS only.
- `ios/App/Float.swift`: `FloatPrefs` (opacity, click-through, saved frame) shared; `FloatController` and `FloatView` (floating NSPanel plus menu bar item) are macOS only.
- `ios/App/Intents.swift`: App Intents (Open in Blackcomb; Open in Float Window on Mac). Links queue in `Services.incoming`.
- `BLACKCOMB_PROFILE=name` env var gives a throwaway library, defaults and cookie store for QA runs.
- `ios/Tests/BlackcombTests.swift`: resolve, tabs, library, settings, and a real WebKit compile of the blocker rules.
- `worker/index.js`: `/go?u=` demo proxy for the landing (strips frame-blocking headers; GET, iframe-only, no cookies, frame sandboxed without allow-same-origin).
- `landing/`: the page IS a browser (bar + iframe through /go, index.html); hero copy lives in start.html; `privacy.html` and `support.html` are the URLs App Store Connect uses. Deployed via `deploy.sh`.

## Build

```bash
cd ios && xcodegen generate
xcodebuild test -project Blackcomb.xcodeproj -scheme Blackcomb -destination 'platform=macOS'
xcodebuild build -project Blackcomb.xcodeproj -scheme Blackcomb -destination 'generic/platform=iOS Simulator'
```

## Rules

- WebKit does the browsing and the OS keeps its own data. History and bookmarks are ours, stay on the device, and are never sent anywhere. Private tabs use a non-persistent data store and record nothing.
- Why this is no longer "one file, nothing saved": Apple rejected 1.0.0 under 4.3(a) (spam: looks like other apps) and macOS under 4.2 (minimum functionality: not different from a web view). The fix is real native features, not metadata. Keep `landing/privacy.html` true whenever storage changes.
- Keep `landing/support.html` a real support page: App Review rejected the old support URL (1.5) for not offering a way to ask for help.
- ASC record 6809355192 (created 2026-09-07, iOS platform added; macOS platform added later, both 1.0.0). Bundle com.nulljosh.lucarne. Installed name must match the App Store name: `CFBundleName` and `CFBundleDisplayName` are both Blackcomb (2.3.8 rejected a build that still said Lucarne). Rename the ASC listing only in the same step as attaching a build that carries the new name; the iOS build in review still installs as Madobe.

## The loop

Current resume state: `docs/LOOP-HANDOFF.md`.
