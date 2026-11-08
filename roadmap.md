# Blackcomb roadmap

## Next
- [ ] Share extension: send a link from Safari to a Blackcomb tab or the second Pair pane. Dropped from 1.0.0 because it needs an app group and a signed extension target.
- [ ] kmp/ port for Android/Windows/Linux (see native fleet rollout)

## Gap matrix (mobbin pass 2026-11-07)
Compared against App Store screens of Safari, Chrome, Edge, Firefox, Brave, DuckDuckGo, Orion, Arc Search, Opera, Aloha. One row per minor version, daily use first. Skipped on purpose: sync, VPN, AI chat, extensions, password manager, ads.

| # | Gap | Who has it | Size | Status |
|---|-----|-----------|------|--------|
| 1 | Downloads: save files (Mac ~/Downloads, iOS Files), a Downloads list | all ten | M | done in 1.1.0 |
| 2 | Address bar suggestions from your own history and bookmarks as you type | Safari, Chrome, Edge, Firefox, Orion | M | done in 1.1.0 |
| 3 | Keyboard: reopen closed tab (Shift-Cmd-T), Cmd-1..9 tabs, Cmd +/- zoom, Ctrl-Tab | Safari, Chrome, Orion (Mac) | S | done in 1.1.0 |
| 4 | Site icons on Favorites tiles and tabs, fetched from the site itself and kept on the device | Safari, Chrome, Orion, DDG | M | done in 1.1.0 |
| 5 | Fire button: close every tab and clear site data in one step | DuckDuckGo, Brave | S | done in 1.1.0 |
| 6 | Automatic HTTPS upgrade | Orion, DuckDuckGo, Brave | S | done (next build) |
| 7 | Tab overview grid with search (iPhone and iPad; Shift-Cmd-Backslash on Mac) | Safari, Chrome, Orion, Edge | L | done (next build) |
| 8 | Translate the page on device (Translation framework; Control-Cmd-T) | Chrome, Safari, Edge | L | done (next build); a long page takes ~30 s, translate visible text first if that bothers anyone |
| 9 | Tab groups | Safari, Orion | L | todo |
| - | Unified title bar, tab close buttons, default Favorites, blue icon in dark mode | Safari | S | done (bd2fe27 and next) |

## Ingested 2026-10-30

## Ingested 2026-11-03
- [x] (2026-11-07: handled, iOS 1.0.0 resubmitted 2026-11-04 and waiting for review; GitHub issue #8 still open, closing it was blocked) App Review sent an "issue with your submission" email (Nov 1-2): read the reason in Resolution Center (asc web review show), no reply without Joshua's yes

## Ingested 2026-11-06
- [ ] Needs better icon.
