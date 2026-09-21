"use client";

import { useEffect, useState } from "react";

import {
  formatPriceQuote,
  parsePriceQuote,
  type PriceQuote,
} from "./lib/pricing";

export default function LocalizedPrice() {
  const [quote, setQuote] = useState<PriceQuote | null>(null);
  const [isLoading, setIsLoading] = useState(true);

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
      })
      .finally(() => {
        if (!controller.signal.aborted) {
          setIsLoading(false);
        }
      });

    return () => controller.abort();
  }, []);

  const displayPrice = quote ? formatPriceQuote(quote) : "Regional price";
  const accessiblePrice = quote
    ? displayPrice
    : isLoading
      ? "Loading regional price"
      : "Regional price shown at checkout";

  return (
    <div
      className={`pricing-price${quote ? "" : " is-placeholder"}`}
      aria-label={accessiblePrice}
      aria-live="polite"
    >
      <strong>{displayPrice}</strong>
    </div>
  );
}
