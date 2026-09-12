export type PriceQuote = {
  amount: number;
  currency: string;
  country: string;
};

export const basePriceQuote: PriceQuote = {
  amount: 2_000,
  currency: "USD",
  country: "US",
};

export function normalizeCountryCode(value: string | null) {
  const country = value?.trim().toUpperCase();

  if (!country || country === "XX" || !/^[A-Z]{2}$/.test(country)) {
    return null;
  }

  return country;
}

export function parsePriceQuote(value: unknown): PriceQuote | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const candidate = value as Partial<PriceQuote>;
  const country = normalizeCountryCode(
    typeof candidate.country === "string" ? candidate.country : null,
  );
  const currency =
    typeof candidate.currency === "string"
      ? candidate.currency.trim().toUpperCase()
      : "";

  if (
    !Number.isSafeInteger(candidate.amount) ||
    (candidate.amount ?? -1) < 0 ||
    !/^[A-Z]{3}$/.test(currency) ||
    !country
  ) {
    return null;
  }

  try {
    new Intl.NumberFormat("en", { style: "currency", currency }).format(0);
  } catch {
    return null;
  }

  return {
    amount: candidate.amount as number,
    currency,
    country,
  };
}

export function priceInMajorUnits(quote: PriceQuote) {
  const fractionDigits =
    new Intl.NumberFormat("en", {
      style: "currency",
      currency: quote.currency,
    }).resolvedOptions().maximumFractionDigits ?? 2;

  return quote.amount / 10 ** fractionDigits;
}

export function formatPriceQuote(quote: PriceQuote) {
  const amount = priceInMajorUnits(quote);
  const fractionDigits =
    new Intl.NumberFormat("en", {
      style: "currency",
      currency: quote.currency,
    }).resolvedOptions().maximumFractionDigits ?? 2;

  return new Intl.NumberFormat(`en-${quote.country}`, {
    style: "currency",
    currency: quote.currency,
    minimumFractionDigits: Number.isInteger(amount) ? 0 : fractionDigits,
    maximumFractionDigits: fractionDigits,
  }).format(amount);
}
