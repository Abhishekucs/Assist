# Assist

A Next.js landing page for selling and downloading Assist for macOS.

## Fun mode

Open `/fun` from the desktop or mobile navigation, or the homepage's Try Fun mode
link. Visitors can choose all 14 app sound packs and seven keyboard designs, follow
the prewritten words, or tap the on-screen keys. Tests last 15 seconds
and start on the first character. Correct, incorrect, and missed letters are marked;
Space advances to the next word, and Backspace allows corrections. Live WPM counts
correct characters divided by five per active minute. Accuracy includes corrected
mistakes. Losing focus pauses the test; input resumes it. Results freeze at the
deadline, and Restart creates a fresh passage and clears the score. Paste and
drop are disabled in the test. Focusing the words unlocks browser audio; sound
and volume controls are independent of the design. The physical-key preview uses
a US layout. Typed text is kept only in component memory and never stored or sent
to a server. The regular website does not listen for keyboard feedback.

The browser loads the selected pack's 12 samples in parallel, decodes them once,
and reuses them for overlapping key presses and releases. Switching packs or
pausing invalidates pending loads so old sounds cannot play later. Tab/window
blur clears held keys and pauses audio; leaving the page closes its audio context.
Playback resumes through an explicit interaction. Nothing plays automatically on
page load. Typing and visualization remain responsive while audio loads or fails.

`public/keyboard-sounds` contains byte-identical copies of the licensed assets
bundled with the Mac app, including source manifests and notices. After changing
the native catalog, update `app/fun/catalog.json`, run `npm run keyboard:sync`,
then `npm run keyboard:check`. No network is used by the sync script. The source
recordings and reference coverage are documented in
`../macos/docs/keyboard-catalog.md`. Browser output may sound different with
different speakers or browser audio processing.

Validation: `npm test`, `npm run keyboard:check`, `npm run typecheck`, and
`npm run build`. Browser checks cover activation, typing, switching packs and
designs, muting, tap keys, and responsive navigation. Microphone, payment, and
purchase activation are not needed to use Fun mode.

## Run Locally

```sh
cd apps/web
npm ci --workspaces=false
npm run dev
```

## Paid Download Flow

The app download is protected by Dodo Payments. The CTA buttons send buyers to
`/api/checkout`, which creates a server-side Dodo checkout session and redirects
to the hosted checkout page. After payment, Dodo returns the buyer to
`/purchase/result`. That page verifies the Dodo payment server-side, saves the
purchase to Supabase, and shows the download button. The download button calls
`/api/download`, which checks the saved Supabase purchase before streaming the
app file.

For Dodo to issue a license key, the Assist product must have an automatic
**License Key** entitlement attached in the Dodo dashboard. Without that product
configuration, Dodo can complete the payment without returning a license key.

The Dodo webhook endpoint is:

```text
/api/webhooks/dodo
```

It verifies Dodo webhook signatures and saves `payment.succeeded` purchases to
Supabase. It also saves Dodo `license_key.created` and
`entitlement_grant.delivered` license keys onto the matching purchase row when
those events are delivered.

The macOS app activation endpoint is:

```text
/api/license/verify
```

It activates a new Dodo license key or validates an existing Dodo license key
instance for a previously activated Mac.

The download route only serves the file when:

- Supabase has a purchase for the Dodo payment id
- the saved purchase status is `succeeded`
- the saved product matches `DODO_PAYMENTS_PRODUCT_ID`
- either `ASSIST_DOWNLOAD_URL` points to an HTTPS installer URL, or the app
  binary exists in `private-downloads/`

Required server-side environment variables:

```sh
DODO_PAYMENTS_API_KEY=
DODO_PAYMENTS_WEBHOOK_KEY=
DODO_PAYMENTS_PRODUCT_ID=
# Use test_mode locally and in previews. Vercel Production must use live_mode.
DODO_PAYMENTS_ENVIRONMENT=test_mode
ASSIST_REQUIRE_DODO_LIVE_MODE=0
DODO_PAYMENTS_RETURN_URL=http://localhost:3000/purchase/result
DODO_PAYMENTS_CANCEL_URL=http://localhost:3000/#pricing
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
ASSIST_DOWNLOAD_URL=https://github.com/Abhishekucs/Assist/releases/latest/download/Assist.dmg
ASSIST_DOWNLOAD_FILE=Assist.dmg
ASSIST_DOWNLOAD_FILENAME=Assist.dmg
```

Create the Supabase tables by running the SQL in
`apps/web/supabase/schema.sql` inside the Supabase SQL editor.

Production can set `ASSIST_DOWNLOAD_URL` to the stable GitHub Release asset.
For local file serving, keep the `.dmg`, `.zip`, or `.pkg` in
`private-downloads/`, not `public/`. `ASSIST_DOWNLOAD_FILE` is resolved inside
that folder and the folder is gitignored so the app binary is not committed or
publicly fetchable.

## Production Dodo Setup

If Production returns:

```json
{
  "error": "Production checkout requires DODO_PAYMENTS_ENVIRONMENT=live_mode"
}
```

the deployed checkout is running with a non-live Dodo environment. Set the
Production-scoped Vercel variables to live Dodo values, then redeploy:

```sh
cd apps/web
printf "live_mode" | npx vercel@latest env update DODO_PAYMENTS_ENVIRONMENT production --yes
printf "<live Dodo API key>" | npx vercel@latest env update DODO_PAYMENTS_API_KEY production --yes
printf "<live Dodo webhook key>" | npx vercel@latest env add DODO_PAYMENTS_WEBHOOK_KEY production
printf "<live Dodo product id>" | npx vercel@latest env update DODO_PAYMENTS_PRODUCT_ID production --yes
printf "https://assist-woad.vercel.app/purchase/result" | npx vercel@latest env update DODO_PAYMENTS_RETURN_URL production --yes
printf "https://assist-woad.vercel.app/#pricing" | npx vercel@latest env update DODO_PAYMENTS_CANCEL_URL production --yes
npx vercel@latest --prod
```

Keep `DODO_PAYMENTS_ENVIRONMENT=test_mode` for local development and preview
deployments so test checkouts never create live payments.

Production deployments must set `DODO_PAYMENTS_ENVIRONMENT=live_mode`. Vercel
production deployments reject `test_mode` automatically through `VERCEL_ENV`;
other hosts can set `ASSIST_REQUIRE_DODO_LIVE_MODE=1` for the same guard.
