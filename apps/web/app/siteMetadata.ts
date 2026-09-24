import type { Metadata } from "next";

import { SITE_NAME, SITE_URL } from "./productContent";

const socialImage = {
  url: "/og-image.png",
  width: 1200,
  height: 630,
  alt: "Assist Mac screenshot and annotation workflow"
};

export const MODULES_SOCIAL_IMAGE = {
  url: "/modules-og-image.png",
  width: 1200,
  height: 630,
  alt: "Assist for Mac showing Clipboard in the notch beside its everyday tools headline"
};

type PageMetadataOptions = {
  title: string;
  description: string;
  path: "/" | "/screenshots" | "/voice-annotation" | "/clipboard" | "/modules";
  absoluteTitle?: boolean;
  image?: typeof socialImage;
};

export function createPageMetadata({
  title,
  description,
  path,
  absoluteTitle = false,
  image = socialImage
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
      images: [image]
    },
    twitter: {
      card: "summary_large_image",
      title: socialTitle,
      description,
      images: [image]
    }
  };
}
