# Blackcomb (repo blackcomb) loop handoff (2026-10-18, afternoon)

## What the loop is

QA the browser to A+ as a designer and engineer, get the Mac build back through App Review, and check Atlin build 9 each tick. Nothing goes to Apple (reply or submit) without Joshua's yes.

## Where things stand

- Apple rejected the Mac submission of 2026-10-06 on 2026-10-11: 4.2 (read as a DuckDuckGo wrapper, sharing does not count) and 4.3 with the nine questions. iOS 1.0.0 is still waiting for review with the old build.
- Name: Blackcomb (Joshua wanted a Vancouver mountain, Grouse was taken; 'you decide' 2026-10-18). Build 202610181830 (iOS and Mac, uploaded, not attached) carries the tile start page and blue icon. 202610181700 carries the name. The code: native start page, reading list with offline reader and read aloud, Google as the default search engine. Builds 202610181545 (Schooner) and 202610181630 (Windrose) are rejected names: never attach either.
- The ASC listing still says Blackcomb because the iOS build in review installs as Blackcomb. Rename the listing only in the same step as attaching a build that carries the final name.
- Review notes for the Mac version describe the new build. The ASC privacy URL points at blackcomb.jaybulb.com/privacy.html. Landing and privacy page redeployed with the new copy.
- Draft reply to Apple with the nine answers: `docs/REVIEW-REPLY.md`. Not sent.
- Export options use `destination: upload`, so `xcodebuild -exportArchive` uploads straight to App Store Connect; no pkg lands on disk.

## Next, in order

0. Start page tiles (favorites grid, reading cards, recent, welcome list only when empty) and the blue two-layer icon are committed but NOT in build 202610181700. Ship them in the next build; do not disturb the Mac review.

1. When build 202610181700 is VALID: Joshua's yes on the reply and resubmit. Then rename the listing to Blackcomb, attach the build, send the reply (`asc web review reply`) and submit.
2. Full rename of repo surfaces to Blackcomb (folder, GitHub repo, remote, Worker and domain, docs, fleet CLAUDE.md, memory). Bundle id stays com.nulljosh.lucarne.
3. iOS: the build in review still says Blackcomb. Once it resolves, ship the Blackcomb build to iOS too.
4. Ship the same build to iOS once its current submission resolves.
5. QA pass on iPhone: Pair view, reading list and reader on a phone width, dark mode.
6. Own search engine (Joshua, 2026-10-18).

## Restart prompt

```
QA Blackcomb (~/Documents/Code/blackcomb) as Jony Ive and Scott Forstall, a professional designer and engineer, until it is A+: screenshot the real Mac app (light and dark) and the iPhone simulator, list everything that is off (alignment, 8pt grid, radii, type, copy, dead states, bugs), fix it, test, re-screenshot, commit and push. Finish the rename (probe results in the session; pick the best Apple-style name, apply it in ASC and across the repo), archive and upload the Mac build, and hold the Resolution Center reply and submit for Joshua's yes. Each tick also check Atlin build 9 with `asc versions list --app 6824157219`; if approved, bump Atlin to build 10, archive, upload and submit iOS and Mac. Keep replies to a TLDR.
```
