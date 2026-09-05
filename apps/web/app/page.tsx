import Image from "next/image";
import FeatureVideo from "./FeatureVideo";
import HeroVideo from "./HeroVideo";
import { marketingVideos } from "./marketingMedia";
import MobileMenu from "./MobileMenu";

const checkoutHref = "/api/checkout";
const siteUrl = "https://assistapp.dev";
const currentPrice = 20;

const faqItems = [
  {
    question: "What does Assist for Mac do?",
    answer:
      "Assist combines three Mac workflows in the notch: voice-powered screen annotation, clean full-screen screenshots, and clipboard history. Recent screenshots, annotations, transcripts, and copied text stay ready to reuse."
  },
  {
    question: "How does voice-powered screen annotation work?",
    answer:
      "Hold Option anywhere on macOS, draw over the screen, and speak while you point things out. Release Option to save the annotated screenshot with its optional local transcript, ready to copy together."
  },
  {
    question: "Does Assist send my voice recording to the cloud?",
    answer:
      "No. Voice transcription runs locally with WhisperKit on Apple silicon. Raw audio stays in memory only while transcription finishes and is never saved; Assist stores only the resulting transcript and its status."
  },
  {
    question: "How do I take a full-screen screenshot?",
    answer:
      "Press Control + Option to capture the full display immediately without entering annotation mode. The screenshot is saved right away and appears in your history under All, where you can preview, copy, or drag it into another app."
  },
  {
    question: "Can I crop or blur a screenshot after taking it?",
    answer:
      "Yes. A quick editor appears under the notch after each Control + Option capture. Hover it to crop to a free or fixed aspect ratio, blur anything private with three brush sizes, or add a gradient or wallpaper backdrop with padding, rounded corners, and a shadow. Expand the card for a closer look, save to replace the capture, or close it to keep the original."
  },
  {
    question: "What happens if I ignore the quick editor?",
    answer:
      "Nothing is lost. The original screenshot is already saved, so the editor closes after about five seconds if you never hover it. Once you hover, it stays visible while your pointer is over it; leaving closes the editor and discards any unsaved draft, while saving first replaces the original capture with your edits."
  },
  {
    question: "How does clipboard history work?",
    answer:
      "Copy text as usual and Assist keeps it in your local history alongside your screenshots. Hover the notch, then use All, Text, or Images to filter what you need, copy it again, or drag it into another app. You can delete individual items whenever you want."
  },
  {
    question: "Where does Assist store my screenshots and history?",
    answer:
      "Screenshots, copied text, history, and optional transcripts are stored locally on your Mac. Assist does not OCR or interpret screenshots; you choose when to copy or drag the original capture into another app."
  },
  {
    question: "What are the Mac requirements?",
    answer:
      "Assist requires macOS 14 Sonoma or later. Screenshots and clipboard history work on supported Macs; optional local voice transcription requires Apple silicon and a one-time Whisper model download."
  },
  {
    question: "Which macOS permissions does Assist need?",
    answer:
      "Screen Recording is required for screenshots. Accessibility or Input Monitoring lets Assist detect the Option and Control + Option shortcuts. Microphone access is optional and requested only when you enable voice transcription."
  },
  {
    question: "Is Assist a subscription?",
    answer:
      `No. Assist is $${currentPrice} for one Mac as a one-time purchase. There is no recurring subscription.`
  }
];

const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      "@id": `${siteUrl}/#app`,
      name: "Assist",
      operatingSystem: "macOS 14 or later",
      applicationCategory: "UtilitiesApplication",
      description:
        "Assist is a native Mac app for voice-powered screen annotation, full-screen screenshots, and clipboard history from the notch.",
      url: siteUrl,
      image: `${siteUrl}/og-image.png`,
      softwareRequirements:
        "macOS 14 or later; Apple silicon is required for local voice transcription",
      offers: {
        "@type": "Offer",
        price: String(currentPrice),
        priceCurrency: "USD",
        category: "one-time purchase",
        availability: "https://schema.org/InStock"
      },
      featureList: [
        "Voice-powered screen annotation",
        "Local Whisper transcription on Apple silicon",
        "Full-screen screenshot capture with Control and Option",
        "Quick screenshot editing with crop, blur, and backdrops",
        "Local clipboard text history",
        "Screenshot and copied-text history",
        "Drag and drop from the notch",
        "Local-first storage"
      ]
    },
    {
      "@type": "Organization",
      "@id": `${siteUrl}/#organization`,
      name: "Assist",
      url: siteUrl,
      logo: `${siteUrl}/assist-icon.png`
    },
    {
      "@type": "WebSite",
      "@id": `${siteUrl}/#website`,
      name: "Assist",
      url: siteUrl,
      publisher: { "@id": `${siteUrl}/#organization` }
    },
    {
      "@type": "FAQPage",
      "@id": `${siteUrl}/#faq`,
      mainEntity: faqItems.map((item) => ({
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
  return (
    <main>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <header className="site-header" aria-label="Site header">
        <nav className="header-pill" aria-label="Primary navigation">
          <a className="brand" href="#top" aria-label="Assist home">
            <span className="brand-mark">
              <Image src="/assist-icon.png" alt="" width={30} height={30} />
            </span>
            <span>Assist</span>
          </a>
          <div className="nav-links">
            <a href="#features">Features</a>
            <a href="#faq">FAQ</a>
            <a href="#pricing">Pricing</a>
          </div>
          <a className="download-button" href={checkoutHref} aria-label="Download Assist">
            <span aria-hidden="true"></span>
            <span>Download</span>
          </a>
          <MobileMenu />
        </nav>
      </header>

      <section id="top" className="hero">
        <div className="hero-content">
          <h1 className="hero-title">
            <span>Screenshots that</span>
            <span>say more.</span>
          </h1>
          <p className="hero-copy">
            Hold Option to draw on your screen and explain it aloud. Assist saves
            your annotated screenshot with a local transcript, ready to share.
          </p>
          <div className="hero-actions">
            <a className="hero-download-button" href={checkoutHref}>
              <span aria-hidden="true"></span>
              <span>Download for Mac</span>
            </a>
          </div>
          <p className="hero-platform-note">macOS 14+ · Apple silicon for voice</p>
        </div>
        <HeroVideo src={marketingVideos.hero} />
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
        <article id="voice-annotation" className="workflow-section workflow-split">
          <div className="workflow-copy">
            <h2>Point. Speak. Done.</h2>
            <p className="workflow-description">
              Hold Option anywhere on macOS to draw over what you see. Speak while
              you annotate and Assist adds a local transcript to the same capture,
              so the image and your intent stay together.
            </p>
          </div>
          <div className="workflow-media workflow-media-video" aria-hidden="true">
            <FeatureVideo src={marketingVideos.annotation} />
          </div>
        </article>

        <article id="screenshots" className="workflow-section workflow-split workflow-split-reverse">
          <div className="workflow-copy">
            <h2>Capture. Edit.</h2>
            <p className="workflow-description">
              Press Control + Option for a clean screenshot of the full display.
              It saves immediately, and a quick editor drops under the notch in
              case you want to crop, blur, or frame it before using it.
            </p>
          </div>
          <div className="workflow-media workflow-media-video" aria-hidden="true">
            <FeatureVideo src={marketingVideos.screenshot} />
          </div>
        </article>

        <article id="clipboard" className="workflow-section workflow-split">
          <div className="workflow-copy">
            <h2>Copy once. Reuse anytime.</h2>
            <p className="workflow-description">
              Assist keeps copied text beside your screenshots in one local shelf.
              Open the notch, narrow the view to All, Text, or Images, and put an
              item back into your workflow in a click.
            </p>
          </div>
          <div className="workflow-media workflow-media-video" aria-hidden="true">
            <FeatureVideo src={marketingVideos.clipboard} />
          </div>
        </article>
      </section>

      <section id="pricing" className="pricing-section">
        <div className="section-heading">
          <h2>One Mac. All three workflows.</h2>
          <p>Pay once for the complete Assist experience. No subscription.</p>
        </div>

        <div className="pricing-card">
          <h3>Assist License</h3>

          <div className="pricing-price" aria-label={`$${currentPrice}`}>
            <strong>${currentPrice}</strong>
          </div>

          <p className="pricing-license-note">1 Mac · one-time purchase</p>

          <ul className="pricing-features" aria-label="Included features">
            <li>Voice-powered screen annotation</li>
            <li>Full-screen screenshot capture</li>
            <li>Quick crop, blur, and backdrop editing</li>
            <li>Local clipboard history</li>
            <li>Recent screenshots and copied text</li>
            <li>Native, local-first macOS app</li>
          </ul>

          <a className="pricing-button" href={checkoutHref}>
            <span>Get Assist</span>
          </a>
        </div>
      </section>

      <section id="faq" className="faq-section">
        <div className="faq-intro">
          <h2>Frequently asked questions</h2>
          <p>
            Voice annotation, screenshots, clipboard history, privacy, Mac
            requirements, and licensing.
          </p>
        </div>

        <div className="faq-list">
          {faqItems.map((item, index) => (
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

      <footer className="site-footer">
        <div className="footer-cta">
          <Image className="footer-cta-icon" src="/assist-icon.png" alt="" width={72} height={72} />
          <h2>Keep every capture one gesture away.</h2>
          <p>Voice annotation, clean screenshots, and clipboard history, built for your Mac.</p>
          <a className="footer-cta-button" href={checkoutHref}>
            <span aria-hidden="true"></span>
            <span>Get Assist for Mac</span>
          </a>
        </div>

        <div className="footer-links-wrap">
          <div className="footer-brand-block">
            <a className="footer-brand" href="#top" aria-label="Assist home">
              <span className="brand-mark">
                <Image src="/assist-icon.png" alt="" width={30} height={30} />
              </span>
              <span>Assist</span>
            </a>
            <p>Voice annotation, screenshots, and clipboard history, right from your Mac notch.</p>
          </div>

          <nav className="footer-link-grid" aria-label="Footer navigation">
            <div>
              <h3>Product</h3>
              <a href="#voice-annotation">Voice annotation</a>
              <a href="#screenshots">Screenshots</a>
              <a href="#clipboard">Clipboard</a>
            </div>
            <div>
              <h3>Buy</h3>
              <a href="#pricing">Pricing</a>
              <a href="#faq">FAQ</a>
              <a href={checkoutHref}>Download</a>
            </div>
            <div>
              <h3>Company</h3>
              <a href="mailto:abhishek@thinkingsoundlab.com">Contact</a>
              <a href="/llms.txt">LLM.txt</a>
            </div>
            <div>
              <h3>Legal</h3>
              <a href="/privacy">Privacy policy</a>
              <a href="/terms">Terms of use</a>
            </div>
          </nav>
        </div>

        <div className="footer-bottom">
          <p>© 2026 Assist. All rights reserved.</p>
          <a href="#top">Back to top</a>
        </div>
      </footer>
    </main>
  );
}
