import { NextRequest, NextResponse } from "next/server";

import { getDodoClient, getDodoProductId } from "../../../lib/dodo";
import {
  getPublicError,
  getSuccessfulPurchaseByLicenseKey,
  normalizeLicenseKey,
} from "../../../lib/purchases";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type LicenseVerifyRequest = {
  license_key?: unknown;
  licenseKey?: unknown;
  license_key_instance_id?: unknown;
  licenseKeyInstanceId?: unknown;
  device_name?: unknown;
  deviceName?: unknown;
  app_version?: unknown;
  appVersion?: unknown;
};

function stringField(
  body: LicenseVerifyRequest,
  snakeKey: keyof LicenseVerifyRequest,
  camelKey: keyof LicenseVerifyRequest,
) {
  const value = body[snakeKey] ?? body[camelKey];

  return typeof value === "string" ? value.trim() : "";
}

function jsonError(message: string, status: number) {
  return NextResponse.json({ valid: false, error: message }, { status });
}

async function parseBody(request: NextRequest): Promise<LicenseVerifyRequest> {
  try {
    const body = await request.json();

    return typeof body === "object" && body !== null ? body : {};
  } catch {
    return {};
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await parseBody(request);
    const rawLicenseKey = stringField(body, "license_key", "licenseKey");

    if (!rawLicenseKey) {
      return jsonError("License key is required.", 400);
    }

    const licenseKey = normalizeLicenseKey(rawLicenseKey);

    if (licenseKey.length < 6 || licenseKey.length > 200) {
      return jsonError("License key format is invalid.", 400);
    }

    const licenseKeyInstanceId = stringField(
      body,
      "license_key_instance_id",
      "licenseKeyInstanceId",
    );
    const client = getDodoClient();

    if (licenseKeyInstanceId) {
      const validation = await client.licenses.validate({
        license_key: licenseKey,
        license_key_instance_id: licenseKeyInstanceId,
      });

      if (!validation.valid) {
        return jsonError("License key is no longer active on this Mac.", 401);
      }

      return NextResponse.json({
        valid: true,
        license_key_instance_id: licenseKeyInstanceId,
      });
    }

    const deviceName =
      stringField(body, "device_name", "deviceName") || "Assist for macOS";
    const appVersion = stringField(body, "app_version", "appVersion");
    const activation = await client.licenses.activate({
      license_key: licenseKey,
      name: appVersion ? `${deviceName} - ${appVersion}` : deviceName,
    });
    const productId = getDodoProductId();

    if (activation.product.product_id !== productId) {
      await client.licenses
        .deactivate({
          license_key: licenseKey,
          license_key_instance_id: activation.id,
        })
        .catch((error) => {
          console.error("Dodo license rollback failed", error);
        });

      return jsonError("License key is not for Assist for macOS.", 403);
    }

    let customerEmail: string | null = activation.customer.email ?? null;

    try {
      const purchase = await getSuccessfulPurchaseByLicenseKey(licenseKey);
      customerEmail = customerEmail ?? purchase?.customer_email ?? null;
    } catch (error) {
      console.error("License purchase lookup failed", error);
    }

    return NextResponse.json({
      valid: true,
      license_key_instance_id: activation.id,
      customer_email: customerEmail,
      product_id: activation.product.product_id,
    });
  } catch (error) {
    console.error("License verification error", error);

    return jsonError(getPublicError(error), 400);
  }
}
