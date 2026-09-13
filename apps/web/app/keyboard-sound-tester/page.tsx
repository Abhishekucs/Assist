import type { Metadata } from "next";
import SiteHeader from "../SiteHeader";
import KeyboardPlayground from "../fun/KeyboardPlayground";

const pageTitle = "Keyboard Sound Tester & Typing Test";
const socialTitle = `${pageTitle} | Assist`;
const pageDescription =
  "Try 14 mechanical keyboard sound packs and seven keyboard designs in a free 15-second typing test, then use your favorite across apps with Assist for Mac.";
const pageUrl = "https://assistapp.dev/keyboard-sound-tester";
const socialImage = {
  url: "/og-image.png",
  width: 1200,
  height: 630,
  alt: "Assist keyboard sound tester and typing test for Mac"
};

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: { canonical: pageUrl },
  openGraph: {
    title: socialTitle,
    description: pageDescription,
    url: pageUrl,
    siteName: "Assist",
    locale: "en_US",
    type: "website",
    images: [socialImage]
  },
  twitter: {
    card: "summary_large_image",
    title: socialTitle,
    description: pageDescription,
    images: [socialImage]
  }
};

export default function KeyboardSoundTesterPage() {
  return (
    <main>
      <SiteHeader funMode />
      <KeyboardPlayground />
    </main>
  );
}
