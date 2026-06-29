# Assist Monorepo

This repository contains the Assist product split into two apps.

## Apps

```text
apps/web/     Next.js marketing, pricing, payment, and protected download site
apps/macos/   Native macOS Assist app built with Swift Package Manager
```

Vercel deploys only `apps/web/`. The Swift app source in `apps/macos/` is not
part of the marketing website build.

## Web App

```sh
cd apps/web
npm install
npm run dev
```

The web app handles:

- landing page and product marketing
- Dodo Payments checkout
- payment result pages
- Supabase purchase records
- protected app download route

The Dodo webhook endpoint is:

```text
https://assist-woad.vercel.app/api/webhooks/dodo
```

## macOS App

```sh
cd apps/macos
make build
make run
```

The macOS app handles native screenshot capture, annotation, local OCR, and the
notch-style capture shelf. See `apps/macos/README.md` for permissions, local
development, and architecture notes.

## Deployment

- GitHub `main` deploys to Vercel Production.
- Vercel project root directory must be `apps/web`.
- Production and Preview environment variables live in Vercel.
- Local web secrets live in `apps/web/.env.local`.
- Local macOS build output lives in `apps/macos/.build/`.
