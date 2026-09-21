import type { MetadataRoute } from "next";

import { heroVideo } from "./marketingMedia";
import { PRODUCT_FEATURES, SITE_URL } from "./productContent";

const productLastModified = "2026-09-21";
const legalLastModified = "2026-08-27";
const absoluteUrl = (path: string) => new URL(path, SITE_URL).href;

const featurePages: MetadataRoute.Sitemap = PRODUCT_FEATURES.map((feature) => ({
  url: absoluteUrl(feature.path),
  lastModified: productLastModified,
  changeFrequency: "monthly",
  priority: 0.9,
  images: [`${SITE_URL}/og-image.png`],
  videos: [
    {
      title: `${feature.name} in Assist for Mac`,
      description: feature.metadataDescription,
      thumbnail_loc: `${SITE_URL}/og-image.png`,
      content_loc: absoluteUrl(feature.video),
      family_friendly: "yes"
    }
  ]
}));

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: `${SITE_URL}/`,
      lastModified: productLastModified,
      changeFrequency: "monthly",
      priority: 1,
      images: [
        `${SITE_URL}/og-image.png`,
        `${SITE_URL}/assist-icon.png`
      ],
      videos: [
        {
          title: "Assist for Mac workflow demonstration",
          description:
            "An overview of Assist screenshot capture, voice annotation, and clipboard history workflows in the Mac notch.",
          thumbnail_loc: `${SITE_URL}/og-image.png`,
          content_loc: absoluteUrl(heroVideo),
          family_friendly: "yes"
        }
      ]
    },
    ...featurePages,
    {
      url: `${SITE_URL}/keyboard-sound-tester`,
      lastModified: productLastModified,
      changeFrequency: "monthly",
      priority: 0.5
    },
    {
      url: `${SITE_URL}/privacy`,
      lastModified: legalLastModified,
      changeFrequency: "yearly",
      priority: 0.3
    },
    {
      url: `${SITE_URL}/terms`,
      lastModified: legalLastModified,
      changeFrequency: "yearly",
      priority: 0.3
    }
  ];
}
