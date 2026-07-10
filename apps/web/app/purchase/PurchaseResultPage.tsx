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
      kicker: "Payment complete",
      title: "Your download is ready.",
      body: "Thanks for purchasing Assist. Download the macOS app below and keep it somewhere easy to find.",
      detail: null,
    };
  }

  if (state === "failed") {
    return {
      kicker: "Payment failed",
      title: "Payment did not complete.",
      body: "Please try again, or use a different payment method if the checkout keeps failing.",
      detail: null,
    };
  }

  return {
    kicker: "Payment needs attention",
    title: "We could not verify this purchase.",
    body: "Open the checkout link from your payment confirmation again, or return to pricing and start a new checkout.",
    detail: "Verification detail",
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
  const isFailed = state === "failed";

  return (
    <main className="purchase-page">
      <section
        className={`purchase-card purchase-card-${state}`}
        aria-labelledby="purchase-title"
      >
        <a className="purchase-brand" href="/" aria-label="Assist home">
          <span className="brand-mark">
            <img src="/assist-icon.svg" alt="" width="30" height="30" />
          </span>
          <span>Assist</span>
        </a>

        <div className="purchase-status-mark" aria-hidden="true">
          <span></span>
        </div>

        <p className="purchase-kicker">{copy.kicker}</p>
        <h1 id="purchase-title">{copy.title}</h1>
        <p>{copy.body}</p>

        {downloadHref ? (
          <div className="purchase-actions">
            <a className="purchase-download-button" href={downloadHref}>
              <span aria-hidden="true"></span>
              <span>Download Assist for macOS</span>
            </a>
          </div>
        ) : isFailed ? (
          <div className="purchase-actions">
            <a className="purchase-download-button" href="/api/checkout">
              <span aria-hidden="true"></span>
              <span>Try payment again</span>
            </a>
          </div>
        ) : (
          <details className="purchase-warning">
            <summary>{copy.detail}</summary>
            <p>{error}</p>
          </details>
        )}

        <a className="purchase-back-link" href={state === "failed" ? "/#pricing" : "/"}>
          {state === "failed" ? "Back to pricing" : "Back to home"}
        </a>
      </section>
    </main>
  );
}
