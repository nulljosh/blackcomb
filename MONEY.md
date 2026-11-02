# Blackcomb Money

How Blackcomb makes money. The company plan is `REVENUE.md` in the Code root; the ledger is `GTM.md`.

## Price and rail

Free on iPhone and Mac (ASC 6809355192). No Stripe, no in-app purchase, nothing charged.

## What is actually sold

Nothing. Blackcomb is a browser. WebKit does the browsing, and history and bookmarks stay on the device. The pages you load belong to their owners, and the browser does not sell them.

## Who pays and why

Nobody pays for a browser today. People use Blackcomb because it blocks the trackers, keeps the reading list on the device and sells nothing about them.

## Cost to serve

No paid API. The one server is the `/go` demo proxy on the landing Worker. It is GET-only, iframe-only and sends no cookies. Hosting is Cloudflare's free tier.

## Where we are

- 2026-09-07: the ASC record was created, with iOS and macOS platforms.
- 2026-10-18: renamed from Madobe to Blackcomb.
- Apple rejected 1.0.0 under 4.3(a), and the Mac build under 4.2. Repo notes say the Mac automation is built and held until the Mac review clears.
- Revenue: no verified number (the App Store Connect key cannot read sales yet).

## Role in the company plan

Free on purpose. GTM.md lists it as a free browser. It serves Stage 1 as the browser that comes with the grid, and it earns nothing on its own. Keeping it free is part of the trust that REVENUE.md depends on.

## Next

Nothing for money. Keep the app free and keep the Mac automation off until Joshua says yes.

## Million, billion, trillion

**A million.** Blackcomb is the browser people install because it blocks the trackers and still costs nothing.

**A billion.** Blackcomb is the browser the Joshua Tree laptop opens to, with the reading list on the machine.

**A trillion.** Blackcomb is how the web is read on every Jaybulb device, with the same privacy rules on each one.

## Change it

`asc pricing schedule create --app 6809355192 --price 0.99 --base-territory USA --start-date YYYY-MM-DD` if it ever becomes a paid app. Not planned. Only with Joshua's yes in chat.

Anyone who got Blackcomb while it was free keeps it free.

*ASC 6809355192. Verified 2026-11-02.*
