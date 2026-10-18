#!/bin/sh
# Landing page → blackcomb.jaybulb.com
cd "$(dirname "$0")" && cp icon.svg landing/ && env -u CLOUDFLARE_API_TOKEN npx wrangler deploy
