import type { Metadata } from "next";
import { Analytics } from "@vercel/analytics/next";
import { Inter } from "next/font/google";
import "./globals.css";
import { HOME_DESCRIPTION, HOME_TITLE, SITE_NAME, SITE_URL } from "./productContent";

const inter = Inter({
  subsets: ["latin"],
  style: ["normal", "italic"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-sans"
});

const socialImageUrl = `${SITE_URL}/og-image.png`;

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: HOME_TITLE,
    template: "%s | Assist"
  },
  description: HOME_DESCRIPTION,
  applicationName: SITE_NAME,
  category: "Productivity",
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "48x48" },
      { url: "/assist-icon.png", sizes: "512x512", type: "image/png" }
    ],
    apple: "/assist-icon.png"
  },
  openGraph: {
    title: HOME_TITLE,
    description: HOME_DESCRIPTION,
    url: SITE_URL,
    siteName: SITE_NAME,
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
    title: HOME_TITLE,
    description: HOME_DESCRIPTION,
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
