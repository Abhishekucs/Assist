import {
  extractLicenseKeyFromSuccessParams,
  getPaymentIdFromParams,
  getPublicError,
  savePurchaseFromDodoPaymentId,
  type PurchaseRecord,
} from "../lib/purchases";

type PurchaseResultPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

type PurchaseState = "ready" | "failed" | "attention";

type SaveResult =
  | { purchase: PurchaseRecord; error: null; state: "ready" }
  | { purchase: null; error: string; state: "failed" | "attention" };

function getReturnStatusFromParams(
  params: Record<string, string | string[] | undefined>,
) {
  const value = params.status;

  if (Array.isArray(value)) {
    if (value[0]) {
      return value[0];
    }

    return null;
  }

  if (value) {
    return value;
  }

  return null;
}

function getCopy(state: PurchaseState, purchase: PurchaseRecord | null) {
  if (state === "ready" && purchase) {
    return {
      kicker: `Payment ${purchase.status}`,
      title: "Your download is ready.",
      body: "Your purchase has been saved in Supabase. The download link below checks that saved purchase before serving the app.",
    };
  }

  if (state === "failed") {
    return {
      kicker: "Payment failed",
      title: "Payment did not complete.",
      body: "No purchase was saved and no download was created. You can return to pricing and try the payment again.",
    };
  }

  return {
    kicker: "Payment needs attention",
    title: "Purchase was not saved.",
    body: "The app could not save this purchase. The exact server error is shown below.",
  };
}

async function savePurchase(
  params: Record<string, string | string[] | undefined>,
): Promise<SaveResult> {
  const returnStatus = getReturnStatusFromParams(params);

  if (returnStatus && returnStatus !== "succeeded") {
    return {
      purchase: null,
      error: `Dodo returned payment status "${returnStatus}".`,
      state: "failed",
    };
  }

  const paymentId = getPaymentIdFromParams(params);

  if (!paymentId) {
    return {
      purchase: null,
      error: "Dodo return URL is missing payment_id.",
      state: "attention",
    };
  }

  try {
    const purchase = await savePurchaseFromDodoPaymentId(
      paymentId,
      extractLicenseKeyFromSuccessParams(params),
    );

    return { purchase, error: null, state: "ready" };
  } catch (error) {
    return { purchase: null, error: getPublicError(error), state: "attention" };
  }
}

export default async function PurchaseResultPage({
  searchParams,
}: PurchaseResultPageProps) {
  const params = await searchParams;
  const { purchase, error, state } = await savePurchase(params);
  const copy = getCopy(state, purchase);
  const downloadHref = purchase
    ? `/api/download?payment_id=${encodeURIComponent(purchase.dodo_payment_id)}`
    : null;

  return (
    <main className="purchase-page">
      <section className="purchase-card" aria-labelledby="purchase-title">
        <a className="purchase-brand" href="/" aria-label="Assist home">
          <span className="brand-mark">
            <img src="/ai-clipboard-icon.svg" alt="" width="30" height="30" />
          </span>
          <span>Assist</span>
        </a>

        <p className="purchase-kicker">{copy.kicker}</p>
        <h1 id="purchase-title">{copy.title}</h1>
        <p>{copy.body}</p>

        {downloadHref ? (
          <a className="purchase-download-button" href={downloadHref}>
            <span aria-hidden="true"></span>
            <span>Download Assist for macOS</span>
          </a>
        ) : (
          <p className="purchase-warning">{error}</p>
        )}

        <a className="purchase-back-link" href={state === "failed" ? "/#pricing" : "/"}>
          {state === "failed" ? "Back to pricing" : "Back to home"}
        </a>
      </section>
    </main>
  );
}
