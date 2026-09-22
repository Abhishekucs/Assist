import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";

import FeatureVideo from "./FeatureVideo";
import HeroVideo from "./HeroVideo";
import JsonLd from "./JsonLd";
import LocalizedPrice from "./LocalizedPrice";
import SiteFooter from "./SiteFooter";
import SiteHeader from "./SiteHeader";
import { heroVideo } from "./marketingMedia";
import {
  HOME_DESCRIPTION,
  HOME_TITLE,
  PRODUCT_FAQS,
  PRODUCT_FEATURES,
  SITE_URL
} from "./productContent";
import { CHECKOUT_HREF } from "./siteNavigation";
import { createPageMetadata } from "./siteMetadata";

const productHuntHref =
  "https://www.producthunt.com/products/assist-4?embed=true&utm_source=badge-featured&utm_medium=badge&utm_campaign=badge-assist-4";
const productHuntBadgeSrc =
  "https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1242727&theme=light&t=1788689369583";

export const metadata: Metadata = createPageMetadata({
  title: HOME_TITLE,
  description: HOME_DESCRIPTION,
  path: "/",
  absoluteTitle: true
});

const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      "@id": `${SITE_URL}/#app`,
      name: "Assist",
      operatingSystem: "macOS 14 or later",
      applicationCategory: "UtilitiesApplication",
      description:
        "Assist is a native, local-first Mac app for full-screen screenshot capture and editing, voice-powered screen annotation, and clipboard history from the notch.",
      url: SITE_URL,
      image: `${SITE_URL}/og-image.png`,
      publisher: { "@id": `${SITE_URL}/#organization` },
      softwareRequirements:
        "macOS 14 or later; Apple silicon is required for optional local voice transcription",
      featureList: [
        "Full-screen screenshot capture with Control and Option",
        "Quick screenshot editing with crop, blur, and backdrops",
        "Voice-powered screen annotation",
        "Local Whisper transcription on Apple silicon",
        "Local clipboard text history",
        "Screenshot, annotation, transcript, and copied-text history",
        "Copy and drag from the Mac notch",
        "Local-first storage"
      ]
    },
    {
      "@type": "Organization",
      "@id": `${SITE_URL}/#organization`,
      name: "Assist",
      legalName: "Thinking Sound Lab Private Limited",
      url: SITE_URL,
      logo: `${SITE_URL}/assist-icon.png`
    },
    {
      "@type": "WebSite",
      "@id": `${SITE_URL}/#website`,
      name: "Assist",
      url: SITE_URL,
      publisher: { "@id": `${SITE_URL}/#organization` },
      inLanguage: "en"
    },
    {
      "@type": "FAQPage",
      "@id": `${SITE_URL}/#faq`,
      mainEntity: PRODUCT_FAQS.map((item) => ({
        "@type": "Question",
        name: item.question,
        acceptedAnswer: {
          "@type": "Answer",
          text: item.answer
        }
      }))
    }
  ]
};

export default function Home() {
  const screenshots = PRODUCT_FEATURES[0];
  const voiceAnnotation = PRODUCT_FEATURES[1];
  const clipboard = PRODUCT_FEATURES[2];

  return (
    <main id="top">
      <JsonLd data={structuredData} />
      <SiteHeader activePath="/" />

      <section className="hero">
        <div className="hero-content">
          <h1 className="hero-title">
            <span>Capture it.</span>
            <span>Say what matters.</span>
          </h1>
          <p className="hero-copy">
            Assist brings screenshot capture and editing, local voice annotation,
            and clipboard history to your Mac notch. Your captures and copied text
            stay on your Mac until you choose where they go.
          </p>
          <div className="hero-actions">
            <a className="hero-download-button" href={CHECKOUT_HREF}>
              <span aria-hidden="true"></span>
              <span>Download for Mac</span>
            </a>
            <Link className="hero-fun-link" href="/keyboard-sound-tester">Try Fun mode</Link>
          </div>
          <p className="hero-platform-note">macOS 14+ · Apple silicon for voice</p>
          <a
            className="product-hunt-badge"
            href={productHuntHref}
            target="_blank"
            rel="noopener noreferrer"
            aria-label="View Assist on Product Hunt"
          >
            <img
              src={productHuntBadgeSrc}
              alt="Assist — Voice Screenshot and Clipboard on Product Hunt"
              width="250"
              height="54"
            />
          </a>
        </div>
        <HeroVideo src={heroVideo} />
      </section>

      <section className="capability-section">
        <div className="trusted-by" aria-label="Companies where Assist users work">
          <p>Trusted by people at</p>
          <div className="trusted-companies">
            <span><Image src="/brands/apple.svg" alt="" width={18} height={18} />Apple</span>
            <span><Image src="/brands/microsoft.svg" alt="" width={18} height={18} />Microsoft</span>
            <span><Image src="/brands/meta.svg" alt="" width={18} height={18} />Meta</span>
            <span><Image src="/brands/amazon.svg" alt="" width={18} height={18} />Amazon</span>
            <span><Image src="/brands/tiktok.svg" alt="" width={18} height={18} />TikTok</span>
            <span className="character-ai">(character.ai)</span>
            <span><Image src="/brands/mistral-ai.svg" alt="" width={18} height={18} />Mistral AI</span>
            <span><Image src="/brands/doordash.svg" alt="" width={18} height={18} />DoorDash</span>
          </div>
        </div>
      </section>

      <section id="features" className="feature-showcase" aria-label="Assist features">
        <article id={screenshots.id} className="workflow-section workflow-split">
          <div className="workflow-copy">
            <h2>Capture. Edit.</h2>
            <p className="workflow-description">
              Press Control + Option for a clean screenshot of the full display.
              It saves immediately, and a quick editor drops under the notch in
              case you want to crop, blur, or frame it before using it.
            </p>
            <Link className="workflow-link" href={screenshots.path}>
              Explore {screenshots.name} <span aria-hidden="true">→</span>
            </Link>
          </div>
          <div className="workflow-media workflow-media-video" role="img" aria-label={screenshots.videoLabel}>
            <FeatureVideo src={screenshots.video} />
          </div>
        </article>

        <article id={voiceAnnotation.id} className="workflow-section workflow-split workflow-split-reverse">
          <div className="workflow-copy">
            <h2>Point. Speak. Done.</h2>
            <p className="workflow-description">
              Hold Option anywhere on macOS to draw over what you see. Speak while
              you annotate and Assist adds a local transcript to the same capture,
              so the image and your intent stay together.
            </p>
            <Link className="workflow-link" href={voiceAnnotation.path}>
              Explore {voiceAnnotation.name} <span aria-hidden="true">→</span>
            </Link>
          </div>
          <div className="workflow-media workflow-media-video" role="img" aria-label={voiceAnnotation.videoLabel}>
            <FeatureVideo src={voiceAnnotation.video} />
          </div>
        </article>

        <article id={clipboard.id} className="workflow-section workflow-split">
          <div className="workflow-copy">
            <h2>Copy once. Reuse anytime.</h2>
            <p className="workflow-description">
              Assist keeps copied text beside your screenshots in one local shelf.
              Open the notch, narrow the view to All, Text, or Images, and put an
              item back into your workflow in a click.
            </p>
            <Link className="workflow-link" href={clipboard.path}>
              Explore {clipboard.name} <span aria-hidden="true">→</span>
            </Link>
          </div>
          <div className="workflow-media workflow-media-video" role="img" aria-label={clipboard.videoLabel}>
            <FeatureVideo src={clipboard.video} />
          </div>
        </article>
      </section>

      <section id="pricing" className="pricing-section">
        <div className="section-heading">
          <h2>One Mac. All of Assist.</h2>
          <p>Pay once for the complete Assist experience. No subscription.</p>
        </div>

        <div className="pricing-card">
          <h3>Assist License</h3>
          <LocalizedPrice />
          <p className="pricing-license-note">1 Mac · one-time purchase · regional pricing</p>
          <ul className="pricing-features" aria-label="Included features">
            <li>Full-screen screenshot capture</li>
            <li>Quick crop, blur, and backdrop editing</li>
            <li>Voice-powered screen annotation</li>
            <li>Local clipboard history</li>
            <li>Recent screenshots and copied text</li>
            <li>Native, local-first macOS app</li>
          </ul>
          <a className="pricing-button" href={CHECKOUT_HREF}>
            <span>Get Assist</span>
          </a>
        </div>
      </section>

      <section id="faq" className="faq-section">
        <div className="faq-intro">
          <h2>Frequently asked questions</h2>
          <p>
            Screenshots, voice annotation, clipboard history, privacy, Mac
            requirements, and licensing.
          </p>
        </div>

        <div className="faq-list">
          {PRODUCT_FAQS.map((item, index) => (
            <details className="faq-item" key={item.question} open={index === 0}>
              <summary>
                <span>{item.question}</span>
                <span className="faq-state" aria-hidden="true" />
              </summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
