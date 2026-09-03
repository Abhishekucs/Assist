import type { Metadata } from "next";
import { Analytics } from "@vercel/analytics/next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  style: ["normal", "italic"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-sans"
});

const siteUrl = "https://assistapp.dev";
const siteTitle = "Assist for Mac — Voice Annotation, Screenshots & Clipboard";
const socialImageUrl = `${siteUrl}/og-image.png`;
const siteDescription =
  "Annotate your Mac screen with voice, capture full-screen screenshots, and keep copied text ready to reuse from the notch.";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: siteTitle,
    template: "%s — Assist"
  },
  description: siteDescription,
  applicationName: "Assist",
  category: "Productivity",
  keywords: [
    "Mac screenshot app",
    "crop and blur screenshots on Mac",
    "screen annotation Mac",
    "voice annotation",
    "Mac clipboard history",
    "macOS productivity app",
    "Mac notch app"
  ],
  alternates: {
    canonical: "/"
  },
  icons: {
    icon: [{ url: "/favicon.ico", sizes: "48x48" }, { url: "/assist-icon.svg", type: "image/svg+xml" }],
    apple: "/assist-icon.png"
  },
  openGraph: {
    title: siteTitle,
    description: siteDescription,
    url: siteUrl,
    siteName: "Assist",
    locale: "en_US",
    type: "website",
    images: [
      {
        url: socialImageUrl,
        width: 1200,
        height: 630,
        alt: "Assist for Mac with screenshots, annotations, and clipboard history"
      }
    ]
  },
  twitter: {
    card: "summary_large_image",
    title: siteTitle,
    description: siteDescription,
    images: [
      {
        url: socialImageUrl,
        alt: "Assist for Mac with screenshots, annotations, and clipboard history"
      }
    ]
  }
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={inter.variable}>
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  );
}
