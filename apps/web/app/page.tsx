import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";

import FeatureVideo from "./FeatureVideo";
import JsonLd from "./JsonLd";
import LocalizedPrice from "./LocalizedPrice";
import SiteFooter from "./SiteFooter";
import SiteHeader from "./SiteHeader";
import { MODULE_WALKTHROUGH } from "./moduleContent";
import {
  HOME_DESCRIPTION,
  HOME_TITLE,
  PRODUCT_FAQS,
  PRODUCT_FEATURES,
  SITE_URL
} from "./productContent";
import { CHECKOUT_HREF } from "./siteNavigation";
import { createPageMetadata, MODULES_SOCIAL_IMAGE } from "./siteMetadata";

const productHuntHref =
  "https://www.producthunt.com/products/assist-4?embed=true&utm_source=badge-featured&utm_medium=badge&utm_campaign=badge-assist-4";
const productHuntBadgeSrc =
  "https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1242727&theme=light&t=1788689369583";

export const metadata: Metadata = createPageMetadata({
  title: HOME_TITLE,
  description: HOME_DESCRIPTION,
  path: "/",
  absoluteTitle: true,
  image: MODULES_SOCIAL_IMAGE
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
        "Assist is a native Mac app for screenshot capture and editing, voice-powered screen annotation, clipboard history, and configurable notch modules.",
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
        "Local clipboard history for text, links, and images",
        "Screenshot, annotation, transcript, and copied-item history",
        "Copy and drag from the Mac notch",
        "Notch modules for notes, timers, calendar, media, system stats, screen time, and image conversion",
        "Optional revenue summaries and local Claude Code and Codex token activity",
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
      "@type": "WebPage",
      "@id": `${SITE_URL}/#webpage`,
      url: `${SITE_URL}/`,
      name: HOME_TITLE,
      description: HOME_DESCRIPTION,
      isPartOf: { "@id": `${SITE_URL}/#website` },
      mainEntity: { "@id": `${SITE_URL}/#app` },
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

  return (
    <main id="top">
      <JsonLd data={structuredData} />
      <SiteHeader activePath="/" />

      <section className="hero">
        <div className="hero-content">
          <h1 className="hero-title">
            <span>One notch.</span>
            <span>Everyday tools.</span>
          </h1>
          <p className="hero-copy">
            Clipboard, files, notes, focus timers, and more—right where you need
            them. Assist keeps your tools close and your flow uninterrupted.
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
        <video
          className="hero-video"
          controls
          playsInline
          preload="metadata"
          poster="/videos/notch-modules-poster.jpg"
          aria-label="Assist notch modules product walkthrough"
        >
          <source src="/videos/notch-modules-demo.mp4" type="video/mp4" />
          Your browser does not support video playback.
        </video>
        <details className="hero-video-description">
          <summary>Read the video walkthrough</summary>
          <ol>
            <li>0:00–0:14 — Browse clipboard history, place files on the Shelf, and write a note.</li>
            <li>0:15–0:31 — Start a focus timer and stopwatch, with hydration reminders alongside them.</li>
            <li>0:32–0:51 — View upcoming calendar events and manage reminders.</li>
            <li>0:52–1:06 — Control music playback and see live system statistics.</li>
            <li>1:07–1:23 — Switch between Screen Time, image conversion, revenue, and AI usage.</li>
            <li>1:24–1:55 — Explore module settings, Screen Time history, and keyboard sounds.</li>
          </ol>
        </details>
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

      <section id="features" className="module-walkthrough" aria-labelledby="modules-title">
        <div className="module-walkthrough-intro">
          <h2 id="modules-title">Make the notch yours.</h2>
          <p>Eleven modules, one place to find them. Enable the ones that fit your day.</p>
        </div>
        <div className="module-walkthrough-list">
          {MODULE_WALKTHROUGH.map((module, index) => (
            <article
              id={module.id}
              key={module.id}
              className={`workflow-section workflow-split${index % 2 === 1 ? " workflow-split-reverse" : ""}`}
            >
              <div className="workflow-copy">
                <h2>{module.heading}</h2>
                <p className="workflow-description">{module.description}</p>
                {"path" in module ? (
                  <Link className="workflow-link" href={module.path}>
                    Explore {module.name} <span aria-hidden="true">→</span>
                  </Link>
                ) : null}
                {"alertScreenshot" in module ? (
                  <a className="workflow-link" href={`/modules/${module.alertScreenshot}`} target="_blank" rel="noopener noreferrer">
                    See the hydration alert <span aria-hidden="true">↗</span>
                  </a>
                ) : null}
              </div>
              <a
                className="workflow-media module-preview"
                href={`/modules/${module.screenshot}`}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={`Open the ${module.name} image at full size`}
              >
                <Image
                  src={`/modules/${module.screenshot}`}
                  alt={module.alt}
                  width={1332}
                  height={468}
                  sizes="(max-width: 900px) 100vw, 570px"
                />
              </a>
            </article>
          ))}
        </div>
      </section>

      <section className="feature-showcase capture-showcase" aria-label="Capture and annotation">
        <div className="module-walkthrough-intro">
          <h2>Capture the moment, too.</h2>
          <p>Screenshots and voice annotations live beside your clipboard history.</p>
        </div>
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
            <li>Configurable notch modules</li>
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
            Screenshots, voice annotation, notch modules, privacy, Mac
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
