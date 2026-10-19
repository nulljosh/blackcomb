# Blackcomb (repo blackcomb) loop handoff (2026-10-18, afternoon)

## What the loop is

QA the browser to A+ as a designer and engineer, get the Mac build back through App Review, and check Atlin build 9 each tick. Nothing goes to Apple (reply or submit) without Joshua's yes.

## Where things stand

- Apple rejected the Mac submission of 2026-10-06 on 2026-10-11: 4.2 (read as a DuckDuckGo wrapper, sharing does not count) and 4.3 with the nine questions. iOS 1.0.0 is still waiting for review with the old build.
- Name: Blackcomb (Joshua wanted a Vancouver mountain, Grouse was taken; 'you decide' 2026-10-18). Build 202610181830 (iOS and Mac, uploaded, not attached) carries the tile start page and blue icon. 202610181700 carries the name. The code: native start page, reading list with offline reader and read aloud, Google as the default search engine. Builds 202610181545 (Schooner) and 202610181630 (Windrose) are rejected names: never attach either.
- The ASC listing still says Madobe, and the iOS build in review (7c794e0f) is the old build, so it installs as Madobe. Rename the listing only in the same step as attaching a build that carries the final name.
- Review notes for the Mac version describe the new build. The ASC privacy URL is https://madobe.jaybulb.com/privacy.html (read from asc). The Worker keeps the madobe host on purpose, and blackcomb.jaybulb.com serves the same page. The landing is redeployed with the new copy. privacy.html's automation line is committed but NOT deployed, on purpose, until the build that ships Mac automation.
- The reply to Apple with the nine answers WAS SENT on 2026-10-18 at 16:15 PT (thread cfe87cee, build 202610181700 named in it), and the Mac submission b7b2c4b1 went back to WAITING_FOR_REVIEW 30 seconds later. Do not send it again. Long draft: `docs/REVIEW-REPLY.md`. iOS 7c794e0f is still waiting with the old build.
- Mac automation server (MCP and REST, commit 5b5b7fc) is built and tested but NOT in any uploaded build. It adds the `network.server` entitlement: hold it until this review resolves, then ship it in the next build.
- Export options use `destination: upload`, so `xcodebuild -exportArchive` uploads straight to App Store Connect; no pkg lands on disk.

## Next, in order

0. Build 202610181830 (uploaded, not attached) carries the start page tiles and the blue icon. It predates the automation commit, so it is clean to attach once the Mac review settles.

1. Wait for Apple on the Mac resubmission (reply sent, WAITING_FOR_REVIEW). Check `asc web review show --app 6809355192 --submission b7b2c4b1-1de7-4735-95a5-eac865adaf46`. If rejected again, read the new message before replying.
2. Rename is done: folder, GitHub repo (nulljosh/blackcomb), remote and blackcomb.jaybulb.com. The Worker name stays madobe and the bundle id stays com.nulljosh.lucarne, both on purpose.
3. iOS: the build in review is the old Madobe build. Once it resolves, ship a Blackcomb build (202610181830 or later) to iOS too.
4. Ship the same build to iOS once its current submission resolves.
5. QA pass on iPhone: Pair view, reading list and reader on a phone width, dark mode.
6. Own search engine (Joshua, 2026-10-18).

## Restart prompt

```
QA Blackcomb (~/Documents/Code/blackcomb) as Jony Ive and Scott Forstall, a professional designer and engineer, until it is A+: screenshot the real Mac app (light and dark) and the iPhone simulator, list everything that is off (alignment, 8pt grid, radii, type, copy, dead states, bugs), fix it, test, re-screenshot, commit and push. The name is locked as Blackcomb; do not rename again. The Resolution Center reply was sent on 2026-10-18 at 16:15 PT, so never send it again. Do not archive or upload a Mac build from HEAD while commit 5b5b7fc (the automation, with its network.server entitlement) is in the tree: strip it or build from a branch without it. Any Apple submit waits for Joshua's yes. Each tick also check Atlin build 9 with `asc versions list --app 6824157219`; if approved, bump Atlin to build 10, archive, upload and submit iOS and Mac. Keep replies to a TLDR.
```
