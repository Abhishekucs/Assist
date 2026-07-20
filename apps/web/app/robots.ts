import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        disallow: ["/api/", "/purchase/"]
      }
    ],
    sitemap: "https://assistapp.dev/sitemap.xml"
  };
}
