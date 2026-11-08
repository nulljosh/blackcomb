# Blackcomb loop handoff (2026-11-07, night)

## What the loop is
Close every gap in the mobbin matrix in `roadmap.md` against Safari, Chrome, Orion, DuckDuckGo and the rest, QA each row live on the Mac (automation API on a `BLACKCOMB_PROFILE=qa` copy), ship, until the browser is A+.

## Where things stand
- Mac 1.0.0 is live. Mac 1.1.0 (build 202611072030) is WAITING_FOR_REVIEW, submission 3d40eb2a: downloads, address suggestions, site icons, fire button, tab shortcuts, unified title bar, default Favorites with Google first, automation.
- Built and committed after 1.1.0, not uploaded: HTTPS first, tab overview, Translate Page (on device), tab groups. Matrix rows 1 to 9 are done.
- iOS 1.0.0 still WAITING_FOR_REVIEW on build 202610181830. Its listing copy is stale (Lucarne, DuckDuckGo); the fixed copy is `metadata/version/1.1.0/en-US.json`.
- The Dock points at `/Applications/Blackcomb.app` (local Release build). The root-owned App Store `/Applications/Madobe.app` is unregistered; deleting it needs Joshua's password.
- Grade: A. Left for A+: iPhone visual QA in the simulator, new App Store screenshots (Mac set locked while in review), translate visible text first on long pages.

## Next, in order
1. When Mac 1.1.0 is approved: ship 1.2.0 with HTTPS first, tab overview, translate, tab groups, plus new Mac screenshots.
2. When iOS 1.0.0 resolves: ship iOS 1.2.0 with the new listing copy and screenshots.
3. iPhone QA in the simulator (only with fresh session usage): start page, tab overview, Pair, downloads to Files, dark mode.

## Restart prompt
```
/loop /mobbin  until A+
ultrathink
```
