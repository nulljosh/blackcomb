# Reply to App Review, macOS 1.0.0 (draft, not sent)

Thread cfe87cee on ASC app 6809355192. Apple rejected the 2026-10-06 Mac submission on 2026-10-11 under 4.2 (minimum functionality, "primarily an integration of DuckDuckGo") and 4.3 (spam) with the nine questions. Needs Joshua's yes before it goes out. Send with:

```
asc web review reply --app 6809355192 --thread cfe87cee-2545-32ca-a87a-76c4318a0cac --message-file docs/REVIEW-REPLY.md
```

(only the text below the line, and check the exact flags with `asc web review reply --help` first)

---

Thank you for the review. Build 202610181700 replaces the one you reviewed and changes what you see at launch, so the answers below describe that build. The app is now named Blackcomb (it was Madobe); the App Store name and the installed name match.

On 4.2. The build you reviewed opened on a DuckDuckGo page, which is why it read as an integration of a search engine. The new build opens on a native start page instead, and the native functionality is on that page, in the menus and in the ... menu on every tab:

1. Float (View menu, Shift-Command-F, or ... menu, Float This Page). The page moves into a small window that stays above every other app on every Space and never takes focus. It has an opacity slider, a click-through mode where mouse clicks pass through to the app underneath, a menu bar item, and it remembers its size and place. Safari has no always-on-top page window.
2. Reading list (Bookmarks menu, Save for Later, Command-S). The page's title, address and text are stored on the device. The reader shows them in native text with an adjustable size, works with no connection, and reads the text aloud with the system voice. The start page lists the saved pages.
3. Site rules (Site menu, Option-Command-S). For the open site and its subdomains: page zoom, a dark appearance, and blocking images, scripts or pop-ups. Applied through WebKit content rules, a user script and page preferences, stored on the device.
4. The start page itself: search in the chosen engine (Google by default, or DuckDuckGo, Brave, Ecosia, Startpage), the reading list, bookmarks, recent pages.
5. Tracker and ad blocking with WebKit content rules (on by default), private tabs on a non-persistent data store, bookmarks, history (searchable, clearable), find in page, tab restore, and two Shortcuts actions (Open in Blackcomb, Open in Float Window).

On 4.3, the nine questions:

1. What it does and the problem it solves. Blackcomb is a WebKit browser for Mac whose point is keeping one page useful while you do something else. Float keeps a reference page, a stream or a chat above your work without stealing focus. The reading list keeps a page's text for later and reads it aloud. Site rules let you tame one site (zoom it, darken it, drop its images or scripts) without an extension. It is a small browser built around those three things, with the ordinary parts (tabs, bookmarks, history, private tabs, blocking) done natively.

2. Intended user. Someone on a Mac who works with a web page beside another app: a developer with documentation open, someone following a recipe or a tutorial, someone keeping a live page in view. Also people who save articles to read or listen to later, and people who want per-site control without installing extensions.

3. The gap. Safari and the other browsers on the Mac App Store have no always-on-top page window; Float is that. Per-site zoom exists in Safari, but per-site script, image and pop-up blocking and a per-site dark look need extensions. Blackcomb does all of it on the device with WebKit's own content rules and page preferences, with nothing to install and nothing sent anywhere.

4. Beta testing. The app was tested by the developer on Mac, iPhone and iPad across each build. There was no external beta. The project has an automated test suite that runs against real WebKit (tab handling, bookmarks, history, the reading list, site rules, the content blocker rules compiling in WebKit, text extraction for the reader). Changes made from that testing before this build: the start page replaced the search engine homepage, the reader got a text size control and read aloud, and the installed app name was fixed to match the store name.

5. Standalone. Blackcomb is a standalone product. The other apps on this account are not browsers and share no scope with it. The closest is Curbfind, which shows classified listings from one site in its own native views and has no general web browsing.

6. In-app purchase or feature of another app. No. None of the other apps on the account is a browser, and a browser cannot be a feature of a finance, learning or news app.

7. Shared code with other apps on the account. No shared frameworks, libraries or assets. Blackcomb is its own SwiftUI code on top of Apple's WebKit, SwiftUI, AppKit, AVFoundation and App Intents frameworks.

8. Shared code with third-party apps. None. There are no third-party SDKs, libraries or content libraries in the binary. The content blocker's host list is written into the app.

9. Client, partner or third party. No. Blackcomb is my own project, concept, code and branding, submitted under my own account.
