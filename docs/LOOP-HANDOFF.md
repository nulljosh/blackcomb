# Blackcomb loop handoff (2026-11-07, evening)

## Where things stand
- Mac 1.0.0 is LIVE (READY_FOR_SALE, build 202610181700). The old handoff below this line in git history is stale.
- Mac 1.1.0 (build 202611072030, tag v1.1.0) submitted 2026-11-07 20:45 PT, submission 3d40eb2a, WAITING_FOR_REVIEW. Ships automation (network.server, explained in review notes) and downloads (files.downloads.read-write).
- iOS 1.0.0 still WAITING_FOR_REVIEW with build 202610181830 (submitted 2026-11-04). Its listing description is stale ("Lucarne", DuckDuckGo): fix it in the next iOS version, it is locked while in review. metadata/version/1.1.0/en-US.json has the current copy.
- /Applications/Madobe.app is the root-owned App Store copy of Mac 1.0.0 (same bundle id). It is unregistered from Launch Services and the Dock points at /Applications/Blackcomb.app (local Release build). Deleting it needs Joshua's admin password.

## Next
1. Gap matrix rows 6 to 9 in roadmap.md (HTTPS upgrade, iPhone tab grid, translate, tab groups).
2. New Mac and iOS screenshots showing the unified title bar, Favorites with icons, suggestions.
3. When iOS 1.0.0 resolves: ship iOS 1.1.0 with the new description.
4. QA on iPhone simulator: Pair, start page, downloads to Files, dark mode.
