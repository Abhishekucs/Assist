import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const homeLastModified = new Date();
  const legalLastModified = new Date("2026-07-24T00:00:00.000Z");

  return [
    {
      url: "https://assistapp.dev",
      lastModified: homeLastModified,
      changeFrequency: "weekly",
      priority: 1
    },
    {
      url: "https://assistapp.dev/privacy",
      lastModified: legalLastModified,
      changeFrequency: "yearly",
      priority: 0.4
    },
    {
      url: "https://assistapp.dev/terms",
      lastModified: legalLastModified,
      changeFrequency: "yearly",
      priority: 0.4
    }
  ];
}
