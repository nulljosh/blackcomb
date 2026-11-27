# Blackcomb loop handoff (2026-11-26, evening)

## What the loop is
Close every gap in the mobbin matrix in `roadmap.md` against Safari, Chrome, Orion, DuckDuckGo and the rest, QA each row live on the Mac (automation API on a `BLACKCOMB_PROFILE=qa` copy), ship, until the browser is A+.

## Where things stand
- Mac 1.1.0 and iOS 1.0.0 are both READY_FOR_SALE on App Store Connect (checked 2026-11-26).
- The next version is built, tagged and uploaded for iOS and Mac, not submitted. It carries HTTPS first, tab overview, Translate Page (on device), tab groups, the welcome screen and the start-page launch. Matrix rows 1 to 9 are done.
- The Mac build carries the Automation feature (network.server entitlement, off by default), so submitting it needs Joshua's yes.
- Landing shows falling snow and a line when it is snowing at Whistler. README is short with a screenshot. Four clean Mac screenshots are in launch/gallery. A 9:16 promo ad is rendered.
- Grade: A. Left for A+: iPhone visual QA in the simulator, App Store preview video (iPhone simulator recording at device size), translate visible text first on long pages.

## Next, in order
1. Joshua's yes, then submit 1.2.0 for review on iOS and Mac with the new listing copy and screenshots.
2. App Store preview video from an iPhone simulator recording at device size.
3. iPhone QA in the simulator (only with fresh session usage): start page, tab overview, Pair, downloads to Files, dark mode.

## Restart prompt
```
/loop /mobbin  until A+
ultrathink
```
