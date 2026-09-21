import type { MetadataRoute } from "next";

import { SITE_URL } from "./productContent";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: [
          "OAI-SearchBot",
          "ChatGPT-User",
          "Claude-SearchBot",
          "Claude-User"
        ],
        allow: "/",
        disallow: "/api/"
      },
      {
        userAgent: "*",
        allow: "/",
        disallow: "/api/"
      }
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL
  };
}
