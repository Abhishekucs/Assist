import { unstable_cache } from "next/cache";
import { type NextRequest, NextResponse } from "next/server";
import type { CheckoutSessionBillingAddress } from "dodopayments/resources/checkout-sessions";

import { getDodoClient, getDodoProductId } from "../../lib/dodo";
import {
  normalizeCountryCode,
  parseDodoBasePrice,
  parsePriceQuote,
} from "../../lib/pricing";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const browserCacheHeader = "private, no-store";
const priceCacheSeconds = 300;

const getBasePrice = unstable_cache(
  async (productId: string) => {
    const product = await getDodoClient().products.retrieve(productId);
    const quote = parseDodoBasePrice(product.price);

    if (!quote) {
      throw new Error("Dodo returned an invalid one-time product price.");
    }

    return quote;
  },
  ["assist-base-price"],
  { revalidate: priceCacheSeconds },
);

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
  { revalidate: priceCacheSeconds },
);

export async function GET(request: NextRequest) {
  const country = normalizeCountryCode(
    request.headers.get("x-vercel-ip-country"),
  );

  try {
    const productId = getDodoProductId();
    const quote = country
      ? await getLocalizedPrice(productId, country)
      : await getBasePrice(productId);

    return NextResponse.json(quote, {
      headers: { "Cache-Control": browserCacheHeader },
    });
  } catch (error) {
    console.error("Dodo pricing error", error);

    return NextResponse.json(
      { error: "Regional pricing is temporarily unavailable." },
      {
        status: 502,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }
}
