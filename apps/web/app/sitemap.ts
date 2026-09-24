import type { MetadataRoute } from "next";

import { MODULE_WALKTHROUGH } from "./moduleContent";
import { PRODUCT_FEATURES, SITE_URL } from "./productContent";
import { MODULES_SOCIAL_IMAGE } from "./siteMetadata";

const moduleLastModified = "2026-09-24";
const legalLastModified = "2026-09-23";
const absoluteUrl = (path: string) => new URL(path, SITE_URL).href;
const featureLastModified = {
  "/screenshots": "2026-09-23",
  "/voice-annotation": "2026-09-23",
  "/clipboard": "2026-09-24"
} as const;

const featurePages: MetadataRoute.Sitemap = PRODUCT_FEATURES.map((feature) => ({
  url: absoluteUrl(feature.path),
  lastModified: featureLastModified[feature.path],
  videos: [
    {
      title: `${feature.name} in Assist for Mac`,
      description: feature.metadataDescription,
      thumbnail_loc: absoluteUrl(feature.path === "/clipboard" ? MODULES_SOCIAL_IMAGE.url : "/og-image.png"),
      content_loc: absoluteUrl(feature.video),
      family_friendly: "yes"
    }
  ]
}));

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: `${SITE_URL}/`,
      lastModified: moduleLastModified,
      images: [
        `${SITE_URL}/assist-icon.png`,
        ...MODULE_WALKTHROUGH.map((module) => absoluteUrl(`/modules/${module.screenshot}`))
      ]
    },
    ...featurePages,
    {
      url: `${SITE_URL}/modules`,
      lastModified: moduleLastModified
    },
    {
      url: `${SITE_URL}/keyboard-sound-tester`,
      lastModified: "2026-09-22"
    },
    {
      url: `${SITE_URL}/privacy`,
      lastModified: legalLastModified
    },
    {
      url: `${SITE_URL}/terms`,
      lastModified: legalLastModified
    }
  ];
}
