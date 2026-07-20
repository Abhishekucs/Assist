import type { Metadata } from "next";
import { Analytics } from "@vercel/analytics/next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  style: ["normal", "italic"],
  weight: ["400", "500", "700"],
  variable: "--font-sans"
});

const siteUrl = "https://assistapp.dev";
const siteDescription =
  "Assist is a native macOS app for screenshots, annotations, and clipboard history. Capture, annotate, and reuse screenshots and copied text from a notch-style shelf. One-time purchase, local-first.";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "Assist — Screenshot, Annotation & Clipboard History for macOS",
    template: "%s — Assist"
  },
  description: siteDescription,
  alternates: {
    canonical: "/"
  },
  icons: {
    icon: [{ url: "/favicon.ico", sizes: "48x48" }, { url: "/assist-icon.svg", type: "image/svg+xml" }],
    apple: "/assist-icon.png"
  },
  openGraph: {
    title: "Assist — Screenshot, Annotation & Clipboard History for macOS",
    description: siteDescription,
    url: siteUrl,
    siteName: "Assist",
    type: "website",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "Assist notch shelf with recent screenshots and copied text on macOS"
      }
    ]
  },
  twitter: {
    card: "summary_large_image",
    title: "Assist — Screenshot, Annotation & Clipboard History for macOS",
    description: siteDescription,
    images: ["/og-image.png"]
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
