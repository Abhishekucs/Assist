import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import path from "node:path";
import { Readable } from "node:stream";

import { NextRequest, NextResponse } from "next/server";

import { getDodoProductId, requiredEnv } from "../../lib/dodo";
import {
  getPublicError,
  getSuccessfulPurchase,
  markPurchaseDownloaded,
} from "../../lib/purchases";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function getConfiguredDownloadUrl() {
  const configuredUrl = process.env.ASSIST_DOWNLOAD_URL?.trim();

  if (!configuredUrl) {
    return null;
  }

  const url = new URL(configuredUrl);

  if (url.protocol !== "https:") {
    throw new Error("ASSIST_DOWNLOAD_URL must use https.");
  }

  return url;
}

function getConfiguredDownloadFile() {
  const configuredPath = requiredEnv("ASSIST_DOWNLOAD_FILE");

  const privateDownloadRoot = path.join(process.cwd(), "private-downloads");
  const relativePath = configuredPath.replace(/^private-downloads[\\/]/, "");
  const normalizedPath = path.normalize(relativePath);

  if (normalizedPath.startsWith("..") || path.isAbsolute(normalizedPath)) {
    throw new Error("ASSIST_DOWNLOAD_FILE must stay inside private-downloads/");
  }

  return path.join(privateDownloadRoot, normalizedPath);
}

function getDownloadFilename(filePath: string) {
  const filename = requiredEnv("ASSIST_DOWNLOAD_FILENAME");

  return filename.replace(/[\r\n"/\\?%*:|<>]/g, "-");
}

function getContentType(filename: string) {
  if (filename.endsWith(".dmg")) {
    return "application/x-apple-diskimage";
  }

  if (filename.endsWith(".zip")) {
    return "application/zip";
  }

  if (filename.endsWith(".pkg")) {
    return "application/octet-stream";
  }

  throw new Error(`Unsupported download file type: ${filename}`);
}

export async function GET(request: NextRequest) {
  try {
    const paymentId = request.nextUrl.searchParams.get("payment_id")?.trim();

    if (!paymentId) {
      return NextResponse.json(
        { error: "Missing payment id from Dodo checkout." },
        { status: 400 },
      );
    }

    const productId = getDodoProductId();
    const purchase = await getSuccessfulPurchase(paymentId);

    if (purchase.product_id !== productId) {
      return NextResponse.json(
        { error: `Purchase is for ${purchase.product_id}, not ${productId}.` },
        { status: 403 },
      );
    }

    if (!purchase.license_key) {
      return NextResponse.json(
        { error: "Purchase does not have an issued license key." },
        { status: 403 },
      );
    }

    const downloadUrl = getConfiguredDownloadUrl();

    if (downloadUrl) {
      await markPurchaseDownloaded(purchase);

      const response = NextResponse.redirect(downloadUrl, 303);
      response.headers.set("Cache-Control", "private, no-store");

      return response;
    }

    const filePath = getConfiguredDownloadFile();
    const fileStats = await stat(filePath);
    const filename = getDownloadFilename(filePath);
    const stream = Readable.toWeb(createReadStream(filePath));
    await markPurchaseDownloaded(purchase);

    return new NextResponse(stream as ReadableStream<Uint8Array>, {
      headers: {
        "Cache-Control": "private, no-store",
        "Content-Disposition": `attachment; filename="${filename}"`,
        "Content-Length": fileStats.size.toString(),
        "Content-Type": getContentType(filename),
      },
    });
  } catch (error) {
    console.error("Protected download error", error);

    return NextResponse.json(
      { error: getPublicError(error) },
      { status: 500 },
    );
  }
}
