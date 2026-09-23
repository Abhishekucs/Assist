import type { Metadata } from "next";

import { SITE_NAME, SITE_URL } from "./productContent";

const socialImage = {
  url: "/og-image.png",
  width: 1200,
  height: 630,
  alt: "Assist for Mac with screenshots, voice annotation, and clipboard history"
};

type PageMetadataOptions = {
  title: string;
  description: string;
  path: "/" | "/screenshots" | "/voice-annotation" | "/clipboard" | "/modules";
  absoluteTitle?: boolean;
};

export function createPageMetadata({
  title,
  description,
  path,
  absoluteTitle = false
}: PageMetadataOptions): Metadata {
  const url = `${SITE_URL}${path === "/" ? "" : path}`;
  const socialTitle = absoluteTitle ? title : `${title} | ${SITE_NAME}`;

  return {
    title: absoluteTitle ? { absolute: title } : title,
    description,
    alternates: { canonical: path },
    openGraph: {
      title: socialTitle,
      description,
      url,
      siteName: SITE_NAME,
      locale: "en_US",
      type: "website",
      images: [socialImage]
    },
    twitter: {
      card: "summary_large_image",
      title: socialTitle,
      description,
      images: [socialImage]
    }
  };
}
