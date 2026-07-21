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
const siteDescription =
  "Assist is a Dynamic Island for Codex and Claude Code on macOS. Monitor tasks, approve requests, answer agent questions, and reuse screenshots and copied text from the notch.";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "Assist — Dynamic Island for Your Coding Agents",
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
    title: "Assist — Dynamic Island for Your Coding Agents",
    description: siteDescription,
    url: siteUrl,
    siteName: "Assist",
    type: "website",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "Assist showing coding-agent tasks and recent context in the Mac notch"
      }
    ]
  },
  twitter: {
    card: "summary_large_image",
    title: "Assist — Dynamic Island for Your Coding Agents",
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
