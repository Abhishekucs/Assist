import {
  extractLicenseKeyFromSuccessParams,
  getPaymentIdFromParams,
  getPublicError,
  savePurchaseFromDodoPaymentId,
  type PurchaseRecord,
} from "../../lib/purchases";

type SuccessPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

type SaveResult =
  | { purchase: PurchaseRecord; error: null }
  | { purchase: null; error: string };

async function savePurchase(
  params: Record<string, string | string[] | undefined>,
): Promise<SaveResult> {
  const paymentId = getPaymentIdFromParams(params);

  if (!paymentId) {
    return { purchase: null, error: "Dodo return URL is missing payment_id." };
  }

  try {
    const purchase = await savePurchaseFromDodoPaymentId(
      paymentId,
      extractLicenseKeyFromSuccessParams(params),
    );

    return { purchase, error: null };
  } catch (error) {
    return { purchase: null, error: getPublicError(error) };
  }
}

export default async function PurchaseSuccess({ searchParams }: SuccessPageProps) {
  const params = await searchParams;
  const { purchase, error } = await savePurchase(params);
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

        <p className="purchase-kicker">
          {purchase ? `Payment ${purchase.status}` : "Payment needs attention"}
        </p>
        <h1 id="purchase-title">
          {purchase ? "Your download is ready." : "Purchase was not saved."}
        </h1>
        <p>
          {purchase
            ? "Your purchase has been saved in Supabase. The download link below checks that saved purchase before serving the app."
            : "The app could not save this purchase. The exact server error is shown below."}
        </p>

        {downloadHref ? (
          <a className="purchase-download-button" href={downloadHref}>
            <span aria-hidden="true"></span>
            <span>Download Assist for macOS</span>
          </a>
        ) : (
          <p className="purchase-warning">{error}</p>
        )}

        <a className="purchase-back-link" href="/">
          Back to home
        </a>
      </section>
    </main>
  );
}
