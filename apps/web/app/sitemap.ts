import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date();

  return [
    {
      url: "https://assistapp.dev",
      lastModified,
      changeFrequency: "weekly",
      priority: 1
    },
    {
      url: "https://assistapp.dev/privacy",
      lastModified,
      changeFrequency: "yearly",
      priority: 0.4
    },
    {
      url: "https://assistapp.dev/terms",
      lastModified,
      changeFrequency: "yearly",
      priority: 0.4
    }
  ];
}
