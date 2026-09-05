import type { MetadataRoute } from "next";
import { marketingVideos } from "./marketingMedia";

const siteUrl = "https://assistapp.dev";
const homeLastModified = "2026-09-05";
const legalLastModified = "2026-08-27";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: `${siteUrl}/`,
      lastModified: homeLastModified,
      images: [
        `${siteUrl}/og-image.png`,
        `${siteUrl}/assist-icon.png`,
        `${siteUrl}/hero-meadow.png`
      ],
      videos: [
        {
          title: "Assist for Mac workflow demonstration",
          description:
            "An overview of Assist workflows in the Mac notch, including capture, annotation, and clipboard history.",
          thumbnail_loc: `${siteUrl}/og-image.png`,
          content_loc: marketingVideos.hero,
          family_friendly: "yes"
        },
        {
          title: "Voice-powered screen annotation in Assist for Mac",
          description:
            "A demonstration of drawing over the Mac screen and saving the annotation with a local voice transcript.",
          thumbnail_loc: `${siteUrl}/og-image.png`,
          content_loc: marketingVideos.annotation,
          family_friendly: "yes"
        },
        {
          title: "Full-screen screenshot capture and editing in Assist for Mac",
          description:
            "A demonstration of capturing a Mac display and using the quick editor to crop, blur, or frame the screenshot.",
          thumbnail_loc: `${siteUrl}/og-image.png`,
          content_loc: marketingVideos.screenshot,
          family_friendly: "yes"
        },
        {
          title: "Clipboard history in Assist for Mac",
          description:
            "A demonstration of copying an item once and reusing it from the Assist clipboard history.",
          thumbnail_loc: `${siteUrl}/og-image.png`,
          content_loc: marketingVideos.clipboard,
          family_friendly: "yes"
        }
      ]
    },
    {
      url: `${siteUrl}/privacy`,
      lastModified: legalLastModified
    },
    {
      url: `${siteUrl}/terms`,
      lastModified: legalLastModified
    }
  ];
}
