"use client";

import { useEffect, useState } from "react";

import {
  basePriceQuote,
  formatPriceQuote,
  parsePriceQuote,
  type PriceQuote,
} from "./lib/pricing";

export default function LocalizedPrice() {
  const [quote, setQuote] = useState<PriceQuote>(basePriceQuote);

  useEffect(() => {
    const controller = new AbortController();

    void fetch("/api/pricing", {
      credentials: "same-origin",
      signal: controller.signal,
    })
      .then(async (response) => {
        if (!response.ok) {
          return null;
        }

        return parsePriceQuote(await response.json());
      })
      .then((localizedQuote) => {
        if (localizedQuote) {
          setQuote(localizedQuote);
        }
      })
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === "AbortError") {
          return;
        }
      });

    return () => controller.abort();
  }, []);

  const displayPrice = formatPriceQuote(quote);

  return (
    <div className="pricing-price" aria-label={displayPrice} aria-live="polite">
      <strong>{displayPrice}</strong>
    </div>
  );
}
