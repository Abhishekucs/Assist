import { NextRequest, NextResponse } from "next/server";

import { getDodoClient, requiredEnv } from "../../../lib/dodo";
import {
  getPublicError,
  recordDodoWebhookEvent,
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

export async function POST(request: NextRequest) {
  try {
    const body = await request.text();
    const event = getDodoClient().webhooks.unwrap(body, {
      headers: headerRecord(request.headers),
      key: requiredEnv("DODO_PAYMENTS_WEBHOOK_KEY"),
    });
    const paymentId = getPaymentIdFromWebhookData(event.data);

    await recordDodoWebhookEvent(request.headers, event.type, paymentId, event);

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
