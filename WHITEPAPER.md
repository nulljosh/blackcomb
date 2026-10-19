# Blackcomb Technical Whitepaper

**v1.0.0** | October 2026

A web browser that writes no browser code. Most third-party browsers exist to
add something (privacy, sync, a vertical tab sidebar), which means carrying
their own rendering or history stack to do it, and that surface is exactly
where bugs and staleness against the real web creep in. Blackcomb exists to be
the opposite: the thinnest possible chrome around the engine already on the
device, so it inherits Safari's own correctness for free. It is a
`WKWebView` inside a SwiftUI toolbar, shipped for macOS, iOS and iPadOS from
one target. It has since grown a few native features (reading list, Float, Pair, site rules) that WebKit does not offer, each kept thin.

## Core Mechanic: WebKit Is the Browser

Rendering, JavaScript, networking, cookies, back-forward cache, swipe navigation, reader-safe text sizing, password autofill and content blocking all live inside WebKit. Blackcomb does not reimplement or wrap any of it, because every one of those is a place a homemade version would be worse than the OS's own and would need its own maintenance forever. Each tab is one `WKWebView` owned by a `Page` object that also acts as its navigation delegate, mirroring five values into SwiftUI state: address, title, loading, can go back, can go forward.

## Address Resolution

One pure function, `resolve`, turns typed text into a URL. Text with a scheme loads as is. A single token with a dot gets `https://` in front. Anything else becomes a query on the chosen search engine (Google by default; DuckDuckGo, Brave, Ecosia and Startpage in Settings). It is the only logic that is not already WebKit's job, so it carries the first unit tests.

## Tabs

`Tabs` is an array of pages and a current id. Adding appends and selects; closing removes and selects the neighbour, and never closes the last one, so there is always something to look at. Normal tabs are restored at the next launch; private tabs use a non-persistent data store and are never saved.

## What Blackcomb Adds

Each addition is native and stays on the device. A start page replaces the empty tab. The reading list keeps a page's text for offline reading and read aloud. Bookmarks and history are two JSON files. Site rules set zoom, dark appearance and block images, scripts or pop-ups per host through WebKit. Tracker blocking is one WebKit content rule list. Float (Mac) keeps a tab in a see-through, click-through window above every app. Pair (iPhone and iPad) shows two pages at once. Shortcuts gets an Open in Blackcomb action. On the Mac, an optional local server (off by default, loopback only, token required) lets an agent drive the browser over MCP or REST, and never sees private tabs.

## Platform Split

The one `#if` per concern rule: `WebView` is an `NSViewRepresentable` on Mac and a `UIViewRepresentable` on iOS, because that is the one place AppKit and UIKit genuinely diverge on how a native view gets hosted. iOS wraps the content in a `NavigationStack` because that is where its toolbar lives; macOS toolbars attach to the window. Keyboard shortcuts (⌘[, ⌘], ⌘R, ⌘T, ⌘W) are declared once and work on both, so muscle memory from one platform carries to the other.

## What Is Deliberately Missing

Downloads, extensions, sync and telemetry. Each is a feature, and each is also a new place to get something wrong or a new thing to explain to a user, so each gets added when someone using Blackcomb actually wants it, not before.
