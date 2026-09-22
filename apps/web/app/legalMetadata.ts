import type { Metadata } from "next";

import { SITE_URL } from "./productContent";

const socialImageUrl = `${SITE_URL}/og-image.png`;

export function createLegalMetadata(
  title: string,
  description: string,
  path: "/privacy" | "/terms"
): Metadata {
  const url = `${SITE_URL}${path}`;

  return {
    title,
    description,
    alternates: {
      canonical: path
    },
    openGraph: {
      title: `${title} | Assist`,
      description,
      url,
      siteName: "Assist",
      locale: "en_US",
      type: "website",
      images: [
        {
          url: socialImageUrl,
          width: 1200,
          height: 630,
          alt: "Assist for Mac with screenshots, annotations, and clipboard history"
        }
      ]
    },
    twitter: {
      card: "summary_large_image",
      title: `${title} | Assist`,
      description,
      images: [
        {
          url: socialImageUrl,
          alt: "Assist for Mac with screenshots, annotations, and clipboard history"
        }
      ]
    }
  };
}
