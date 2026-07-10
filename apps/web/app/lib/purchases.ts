import type { Payment } from "dodopayments/resources/payments";

import { getDodoClient, getDodoProductId } from "./dodo";
import { getSupabaseClient } from "./supabase";

export type PurchaseRecord = {
  id: string;
  dodo_payment_id: string;
  dodo_checkout_session_id: string;
  status: string;
  product_id: string;
  amount: number;
  currency: string;
  customer_email: string;
  customer_name: string | null;
  license_key: string | null;
  purchased_at: string;
  download_count: number;
  last_downloaded_at: string | null;
  dodo_payload: unknown;
  created_at: string;
  updated_at: string;
};

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

export function normalizeLicenseKey(value: string) {
  return value.trim().replace(/\s+/g, "").toUpperCase();
}

function requirePaymentField(value: string | null | undefined, fieldName: string) {
  if (!value) {
    throw new Error(`Dodo payment is missing ${fieldName}`);
  }

  return value;
}

function getPurchasedProduct(payment: Payment) {
  const productId = getDodoProductId();
  const product = payment.product_cart?.find((item) => item.product_id === productId);

  if (!product) {
    throw new Error(`Dodo payment ${payment.payment_id} does not include ${productId}`);
  }

  return product;
}

function requireSucceededPayment(payment: Payment) {
  if (payment.status !== "succeeded") {
    throw new Error(`Dodo payment ${payment.payment_id} status is ${payment.status}`);
  }
}

function getWebhookId(headers: Headers) {
  const webhookId = headers.get("webhook-id");

  if (!webhookId) {
    throw new Error("Dodo webhook is missing webhook-id header");
  }

  return webhookId;
}

function getLicenseKeyFromParams(
  params: Record<string, string | string[] | undefined>,
) {
  const value = params.license_key;

  if (Array.isArray(value)) {
    if (value[0]) {
      return normalizeLicenseKey(value[0]);
    }

    return null;
  }

  if (value) {
    return normalizeLicenseKey(value);
  }

  return null;
}

export function getPaymentIdFromParams(
  params: Record<string, string | string[] | undefined>,
) {
  const value = params.payment_id;

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

export async function savePurchaseFromDodoPayment(
  payment: Payment,
  licenseKey: string | null,
) {
  requireSucceededPayment(payment);

  const product = getPurchasedProduct(payment);
  const checkoutSessionId = requirePaymentField(
    payment.checkout_session_id,
    "checkout_session_id",
  );
  const purchasedAt = payment.created_at;
  const now = new Date().toISOString();
  const row: Record<string, unknown> = {
    dodo_payment_id: payment.payment_id,
    dodo_checkout_session_id: checkoutSessionId,
    status: payment.status,
    product_id: product.product_id,
    amount: payment.total_amount,
    currency: payment.currency,
    customer_email: requirePaymentField(payment.customer?.email, "customer.email"),
    customer_name: payment.customer?.name ? payment.customer.name : null,
    purchased_at: purchasedAt,
    dodo_payload: payment,
    updated_at: now,
  };

  if (licenseKey) {
    row.license_key = normalizeLicenseKey(licenseKey);
  }

  const { data, error } = await getSupabaseClient()
    .from("purchases")
    .upsert(row, { onConflict: "dodo_payment_id" })
    .select("*")
    .single<PurchaseRecord>();

  if (error) {
    throw new Error(`Supabase purchase upsert failed: ${error.message}`);
  }

  return data;
}

export async function savePurchaseFromDodoPaymentId(
  paymentId: string,
  licenseKey: string | null,
) {
  const payment = await getDodoClient().payments.retrieve(paymentId);

  return savePurchaseFromDodoPayment(payment, licenseKey);
}

export async function getSuccessfulPurchase(paymentId: string) {
  const { data, error } = await getSupabaseClient()
    .from("purchases")
    .select("*")
    .eq("dodo_payment_id", paymentId)
    .eq("status", "succeeded")
    .single<PurchaseRecord>();

  if (error) {
    throw new Error(`Supabase purchase lookup failed: ${error.message}`);
  }

  return data;
}

export async function getSuccessfulPurchaseByLicenseKey(licenseKey: string) {
  const normalizedLicenseKey = normalizeLicenseKey(licenseKey);
  const { data, error } = await getSupabaseClient()
    .from("purchases")
    .select("*")
    .eq("license_key", normalizedLicenseKey)
    .eq("status", "succeeded")
    .eq("product_id", getDodoProductId())
    .maybeSingle<PurchaseRecord>();

  if (error) {
    throw new Error(`Supabase license lookup failed: ${error.message}`);
  }

  return data;
}

export async function saveLicenseKeyForDodoPayment(
  paymentId: string,
  licenseKey: string,
) {
  const normalizedLicenseKey = normalizeLicenseKey(licenseKey);
  const { data, error } = await getSupabaseClient()
    .from("purchases")
    .update({
      license_key: normalizedLicenseKey,
      updated_at: new Date().toISOString(),
    })
    .eq("dodo_payment_id", paymentId)
    .select("*")
    .maybeSingle<PurchaseRecord>();

  if (error) {
    throw new Error(`Supabase license update failed: ${error.message}`);
  }

  if (data) {
    return data;
  }

  return savePurchaseFromDodoPaymentId(paymentId, normalizedLicenseKey);
}

export async function markPurchaseDownloaded(purchase: PurchaseRecord) {
  const { data, error } = await getSupabaseClient()
    .from("purchases")
    .update({
      download_count: purchase.download_count + 1,
      last_downloaded_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("dodo_payment_id", purchase.dodo_payment_id)
    .select("*")
    .single<PurchaseRecord>();

  if (error) {
    throw new Error(`Supabase download update failed: ${error.message}`);
  }

  return data;
}

export async function recordDodoWebhookEvent(
  requestHeaders: Headers,
  eventType: string,
  paymentId: string | null,
  payload: unknown,
) {
  const webhookId = getWebhookId(requestHeaders);
  const { error } = await getSupabaseClient().from("purchase_events").upsert(
    {
      dodo_webhook_id: webhookId,
      event_type: eventType,
      dodo_payment_id: paymentId,
      payload,
      processed_at: new Date().toISOString(),
    },
    { onConflict: "dodo_webhook_id" },
  );

  if (error) {
    throw new Error(`Supabase webhook event upsert failed: ${error.message}`);
  }
}

export function extractLicenseKeyFromSuccessParams(
  params: Record<string, string | string[] | undefined>,
) {
  return getLicenseKeyFromParams(params);
}

export function getPublicError(error: unknown) {
  return errorMessage(error);
}
