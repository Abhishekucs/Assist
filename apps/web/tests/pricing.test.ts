import assert from "node:assert/strict";
import { test } from "node:test";

import {
  formatPriceQuote,
  normalizeCountryCode,
  parseDodoBasePrice,
  parsePriceQuote,
} from "../app/lib/pricing";

test("the base price is read from a Dodo one-time product", () => {
  assert.deepEqual(
    parseDodoBasePrice({
      type: "one_time_price",
      price: 1_500,
      currency: "USD",
    }),
    { amount: 1_500, currency: "USD", country: "US" },
  );
  assert.equal(
    parseDodoBasePrice({
      type: "recurring_price",
      price: 1_500,
      currency: "USD",
    }),
    null,
  );
});

test("Dodo minor-unit prices render in the localized currency", () => {
  assert.equal(
    formatPriceQuote({ amount: 49_900, currency: "INR", country: "IN" }),
    "₹499",
  );
  assert.equal(
    formatPriceQuote({ amount: 1_299, currency: "EUR", country: "DE" }),
    "€12.99",
  );
});

test("country headers are normalized and unknown locations fall back", () => {
  assert.equal(normalizeCountryCode(" in "), "IN");
  assert.equal(normalizeCountryCode("XX"), null);
  assert.equal(normalizeCountryCode("USA"), null);
  assert.equal(normalizeCountryCode(null), null);
});

test("untrusted pricing responses are validated before display", () => {
  assert.deepEqual(
    parsePriceQuote({ amount: 1_000, currency: "usd", country: "us" }),
    { amount: 1_000, currency: "USD", country: "US" },
  );
  assert.equal(
    parsePriceQuote({ amount: -1, currency: "USD", country: "US" }),
    null,
  );
  assert.equal(
    parsePriceQuote({ amount: 1_000, currency: "invalid", country: "US" }),
    null,
  );
});
