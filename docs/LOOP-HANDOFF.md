# Schooner (repo madobe) loop handoff (2026-10-18, afternoon)

## What the loop is

QA the browser to A+ as a designer and engineer, get the Mac build back through App Review, and check Atlin build 9 each tick. Nothing goes to Apple (reply or submit) without Joshua's yes.

## Where things stand

- Apple rejected the Mac submission of 2026-10-06 on 2026-10-11: 4.2 (read as a DuckDuckGo wrapper, sharing does not count) and 4.3 with the nine questions. iOS 1.0.0 is still waiting for review with the old build.
- Build 202610181545 is uploaded for Mac and processing: native start page (reading list, bookmarks, recent, what the app does), reading list with offline reader and read aloud, Google as the default search engine, installed name Schooner. 46 tests pass on Mac; the iOS simulator build compiles.
- The App Store listing is renamed Schooner (`asc apps rename`). Repo, folder, GitHub and madobe.jaybulb.com keep the old name until Joshua confirms the pick. Other free names from the probe: Mullion, Louver, Barque, Catboat, Purview.
- Review notes for the Mac version describe the new build. The ASC privacy URL points at madobe.jaybulb.com/privacy.html. Landing and privacy page redeployed with the new copy.
- Draft reply to Apple with the nine answers: `docs/REVIEW-REPLY.md`. Not sent.
- Export options use `destination: upload`, so `xcodebuild -exportArchive` uploads straight to App Store Connect; no pkg lands on disk.

## Next, in order

1. Do NOT attach build 202610181545: it installs as "Schooner", which Joshua rejected. The ASC listing is back to Madobe (the iOS build in review installs as Madobe; a mismatch is a 2.3.8 rejection). Once Joshua picks a name, change Info.plist, the start page header and icon, the Mac review notes, docs/REVIEW-REPLY.md and memory, bump the build, re-archive, then rename the listing and attach.
2. Joshua's yes on: the name Schooner, sending `docs/REVIEW-REPLY.md`, and resubmitting Mac. Then send the reply (`asc web review reply`) and submit.
3. If the name sticks: full rename (folder, GitHub repo, remote, Worker and domain, docs, fleet CLAUDE.md, memory).
4. Ship the same build to iOS once its current submission resolves.
5. QA pass on iPhone: Pair view, reading list and reader on a phone width, dark mode.
6. Own search engine (Joshua, 2026-10-18).

## Restart prompt

```
QA Madobe (~/Documents/Code/madobe) as Jony Ive and Scott Forstall, a professional designer and engineer, until it is A+: screenshot the real Mac app (light and dark) and the iPhone simulator, list everything that is off (alignment, 8pt grid, radii, type, copy, dead states, bugs), fix it, test, re-screenshot, commit and push. Finish the rename (probe results in the session; pick the best Apple-style name, apply it in ASC and across the repo), archive and upload the Mac build, and hold the Resolution Center reply and submit for Joshua's yes. Each tick also check Atlin build 9 with `asc versions list --app 6824157219`; if approved, bump Atlin to build 10, archive, upload and submit iOS and Mac. Keep replies to a TLDR.
```
