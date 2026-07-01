# Assist

A Next.js landing page for selling and downloading Assist for macOS.

## Run Locally

```sh
cd apps/web
npm install
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

The Dodo webhook endpoint is:

```text
/api/webhooks/dodo
```

It verifies Dodo webhook signatures and saves `payment.succeeded` purchases to
Supabase.

The download route only serves the file when:

- Supabase has a purchase for the Dodo payment id
- the saved purchase status is `succeeded`
- the saved product matches `DODO_PAYMENTS_PRODUCT_ID`
- the app binary exists in `private-downloads/`

Required server-side environment variables:

```sh
DODO_PAYMENTS_API_KEY=
DODO_PAYMENTS_WEBHOOK_KEY=
DODO_PAYMENTS_PRODUCT_ID=
DODO_PAYMENTS_ENVIRONMENT=test_mode
DODO_PAYMENTS_RETURN_URL=http://localhost:3000/purchase/result
DODO_PAYMENTS_CANCEL_URL=http://localhost:3000/#pricing
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
ASSIST_DOWNLOAD_FILE=Assist.dmg
ASSIST_DOWNLOAD_FILENAME=Assist.dmg
```

Create the Supabase tables by running the SQL in
`apps/web/supabase/schema.sql` inside the Supabase SQL editor.

Keep the `.dmg`, `.zip`, or `.pkg` in `private-downloads/`, not `public/`.
`ASSIST_DOWNLOAD_FILE` is resolved inside that folder and the folder is
gitignored so the app binary is not committed or publicly fetchable.
