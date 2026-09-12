import { unstable_cache } from "next/cache";
import { type NextRequest, NextResponse } from "next/server";
import type { CheckoutSessionBillingAddress } from "dodopayments/resources/checkout-sessions";

import { getDodoClient, getDodoProductId } from "../../lib/dodo";
import {
  basePriceQuote,
  normalizeCountryCode,
  parsePriceQuote,
} from "../../lib/pricing";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const browserCacheHeader = "private, max-age=900";

const getLocalizedPrice = unstable_cache(
  async (productId: string, country: string) => {
    const preview = await getDodoClient().checkoutSessions.preview({
      product_cart: [{ product_id: productId, quantity: 1 }],
      billing_address: {
        country: country as CheckoutSessionBillingAddress["country"],
      },
    });
    const quote = parsePriceQuote({
      amount: preview.total_price,
      currency: preview.currency,
      country: preview.billing_country,
    });

    if (!quote) {
      throw new Error("Dodo returned an invalid pricing preview.");
    }

    return quote;
  },
  ["assist-ppp-price"],
  { revalidate: 900 },
);

export async function GET(request: NextRequest) {
  const country = normalizeCountryCode(
    request.headers.get("x-vercel-ip-country"),
  );

  if (!country) {
    return NextResponse.json(basePriceQuote, {
      headers: { "Cache-Control": browserCacheHeader },
    });
  }

  try {
    const quote = await getLocalizedPrice(getDodoProductId(), country);

    return NextResponse.json(quote, {
      headers: { "Cache-Control": browserCacheHeader },
    });
  } catch (error) {
    console.error("Dodo pricing preview error", error);

    return NextResponse.json(
      { error: "Regional pricing is temporarily unavailable." },
      {
        status: 502,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }
}
