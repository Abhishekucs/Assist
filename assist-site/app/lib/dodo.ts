import DodoPayments, { type ClientOptions } from "dodopayments";

type DodoEnvironment = NonNullable<ClientOptions["environment"]>;

export function requiredEnv(name: string) {
  const value = process.env[name]?.trim();

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

export function getDodoEnvironment(): DodoEnvironment {
  const environment = requiredEnv("DODO_PAYMENTS_ENVIRONMENT");

  if (environment !== "test_mode" && environment !== "live_mode") {
    throw new Error("DODO_PAYMENTS_ENVIRONMENT must be test_mode or live_mode");
  }

  return environment;
}

export function getDodoClient() {
  return new DodoPayments({
    bearerToken: requiredEnv("DODO_PAYMENTS_API_KEY"),
    environment: getDodoEnvironment(),
  });
}

export function getDodoProductId() {
  return requiredEnv("DODO_PAYMENTS_PRODUCT_ID");
}
