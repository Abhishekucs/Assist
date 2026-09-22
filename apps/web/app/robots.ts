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
        disallow: ["/api/", "/purchase/"]
      },
      {
        userAgent: "*",
        allow: "/",
        disallow: ["/api/", "/purchase/"]
      }
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL
  };
}
