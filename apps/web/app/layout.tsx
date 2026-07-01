import type { Metadata } from "next";
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
    "Assist is a native macOS capture tool for screenshots, annotations, and agent-ready context.",
  icons: {
    icon: "/ai-clipboard-icon.svg",
    apple: "/ai-clipboard-icon.svg"
  },
  openGraph: {
    title: "Assist",
    description:
      "A native macOS capture tool for screenshots, annotations, and agent-ready context.",
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
      <body>{children}</body>
    </html>
  );
}
