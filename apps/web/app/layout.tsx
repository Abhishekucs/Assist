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
const siteTitle = "Assist — Coding Agents, Screenshots & Annotation for Mac";
const socialImageUrl = `${siteUrl}/assist-social-preview.png`;
const siteDescription =
  "Assist is a Dynamic Island for Codex and Claude Code on macOS. Monitor tasks, approve requests, answer agent questions, and reuse screenshots and copied text from the notch.";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: siteTitle,
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
        alt: "Assist for Mac monitoring coding agents from the notch"
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
        alt: "Assist for Mac monitoring coding agents from the notch"
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
