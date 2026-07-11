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

export const metadata: Metadata = {
  title: "Assist",
  description:
    "Assist is a native macOS capture tool for screenshots, annotations, and copied text history.",
  icons: {
    icon: "/assist-icon.svg",
    apple: "/assist-icon.svg"
  },
  openGraph: {
    title: "Assist",
    description:
      "A native macOS capture tool for screenshots, annotations, and copied text history.",
    type: "website"
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
