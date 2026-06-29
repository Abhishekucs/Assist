import { NextRequest, NextResponse } from "next/server";

import { getDodoClient, getDodoProductId, requiredEnv } from "../../lib/dodo";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  try {
    const productId = getDodoProductId();
    const returnUrl = requiredEnv("DODO_PAYMENTS_RETURN_URL");
    const cancelUrl = requiredEnv("DODO_PAYMENTS_CANCEL_URL");

    const session = await getDodoClient().checkoutSessions.create({
      product_cart: [{ product_id: productId, quantity: 1 }],
      return_url: returnUrl,
      cancel_url: cancelUrl,
      metadata: {
        app: "assist",
        product: "assist-macos",
        origin: request.nextUrl.origin,
      },
      customization: {
        theme: "dark",
      },
      feature_flags: {
        redirect_immediately: true,
      },
    });

    if (!session.checkout_url) {
      return NextResponse.json(
        { error: "Dodo did not return a checkout URL." },
        { status: 502 },
      );
    }

    return NextResponse.redirect(session.checkout_url, 303);
  } catch (error) {
    console.error("Dodo checkout error", error);

    return NextResponse.json(
      { error: error instanceof Error ? error.message : String(error) },
      { status: 500 },
    );
  }
}
