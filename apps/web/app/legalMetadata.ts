import type { Metadata } from "next";

const siteUrl = "https://assistapp.dev";
const socialImageUrl = `${siteUrl}/assist-social-preview.png`;

export function createLegalMetadata(
  title: string,
  description: string,
  path: "/privacy" | "/terms"
): Metadata {
  const url = `${siteUrl}${path}`;

  return {
    title,
    description,
    alternates: {
      canonical: path
    },
    openGraph: {
      title: `${title} — Assist`,
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
          alt: "Assist for Mac monitoring coding agents from the notch"
        }
      ]
    },
    twitter: {
      card: "summary_large_image",
      title: `${title} — Assist`,
      description,
      images: [
        {
          url: socialImageUrl,
          alt: "Assist for Mac monitoring coding agents from the notch"
        }
      ]
    }
  };
}
