import { NextRequest, NextResponse } from "next/server";

import { getDodoClient, requiredEnv } from "../../../lib/dodo";
import {
  getPublicError,
  recordDodoWebhookEvent,
  saveLicenseKeyForDodoPayment,
  savePurchaseFromDodoPayment,
} from "../../../lib/purchases";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function headerRecord(headers: Headers) {
  return Object.fromEntries(headers.entries());
}

function getPaymentIdFromWebhookData(data: unknown) {
  if (
    typeof data === "object" &&
    data !== null &&
    "payment_id" in data &&
    typeof data.payment_id === "string"
  ) {
    return data.payment_id;
  }

  return null;
}

function getLicenseKeyFromWebhookData(data: unknown) {
  if (typeof data !== "object" || data === null) {
    return null;
  }

  if ("key" in data && typeof data.key === "string") {
    return data.key;
  }

  if (
    "license_key" in data &&
    typeof data.license_key === "object" &&
    data.license_key !== null &&
    "key" in data.license_key &&
    typeof data.license_key.key === "string"
  ) {
    return data.license_key.key;
  }

  return null;
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.text();
    const event = getDodoClient().webhooks.unwrap(body, {
      headers: headerRecord(request.headers),
      key: requiredEnv("DODO_PAYMENTS_WEBHOOK_KEY"),
    });
    const paymentId = getPaymentIdFromWebhookData(event.data);

    try {
      await recordDodoWebhookEvent(request.headers, event.type, paymentId, event);
    } catch (error) {
      console.error("Dodo webhook event recording failed", error);
    }

    if (
      (event.type === "license_key.created" ||
        event.type === "entitlement_grant.delivered") &&
      paymentId
    ) {
      const licenseKey = getLicenseKeyFromWebhookData(event.data);

      if (licenseKey) {
        const purchase = await saveLicenseKeyForDodoPayment(paymentId, licenseKey);

        return NextResponse.json({
          received: true,
          purchase_id: purchase.id,
          payment_id: purchase.dodo_payment_id,
          license_key_saved: true,
        });
      }
    }

    if (event.type !== "payment.succeeded") {
      return NextResponse.json({ received: true, event_type: event.type });
    }

    const purchase = await savePurchaseFromDodoPayment(event.data, null);

    return NextResponse.json({
      received: true,
      purchase_id: purchase.id,
      payment_id: purchase.dodo_payment_id,
    });
  } catch (error) {
    console.error("Dodo webhook error", error);

    return NextResponse.json({ error: getPublicError(error) }, { status: 400 });
  }
}
