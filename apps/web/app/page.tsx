import FeatureVideo from "./FeatureVideo";
import MobileMenu from "./MobileMenu";

const checkoutHref = "/api/checkout";
const siteUrl = "https://assistapp.dev";
const currentPrice = 20;
const featureVideos = {
  annotation:
    "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/annotationedit.mp4",
  screenshot:
    "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/fullscreenedit.mp4"
};

const faqItems = [
  {
    question: "What does Assist for Mac do?",
    answer:
      "Assist combines three Mac workflows in the notch: voice-powered screen annotation, clean full-screen screenshots, and clipboard history. Recent screenshots, annotations, transcripts, and copied text stay ready to reuse."
  },
  {
    question: "How does voice-powered screen annotation work?",
    answer:
      "Hold Option anywhere on macOS, draw over the screen, and speak while you point things out. Release Option to save the annotated screenshot with its optional local transcript, ready to copy as structured context."
  },
  {
    question: "Does Assist send my voice recording to the cloud?",
    answer:
      "No. Voice transcription runs locally with WhisperKit on Apple silicon. Raw audio stays in memory only while transcription finishes and is never saved; Assist stores only the resulting transcript and its status."
  },
  {
    question: "How do I take a full-screen screenshot?",
    answer:
      "Press Control + Option to capture the full display immediately without entering annotation mode. The screenshot is saved right away and appears in Recent Items, where you can preview, copy, or drag it into another app."
  },
  {
    question: "Can I crop or blur a screenshot after taking it?",
    answer:
      "Yes. A quick editor appears under the notch after each Control + Option capture. Hover it to crop to a free or fixed aspect ratio, blur anything private with three brush sizes, or add a gradient or wallpaper backdrop with padding, rounded corners, and a shadow. Expand the card for a closer look, save to replace the capture, or close it to keep the original."
  },
  {
    question: "What happens if I ignore the quick editor?",
    answer:
      "Nothing is lost. The original screenshot is already saved, so the editor closes on its own after about five seconds if you never hover it, and it follows your pointer away once you do. If you have started editing, it stays put until you save it or close it, so a stray pointer cannot discard your work."
  },
  {
    question: "How does clipboard history work?",
    answer:
      "Copy text as usual and Assist keeps it in your local history alongside your screenshots. Hover the notch to find recent items, copy them again, or drag them into another app. You can delete individual items whenever you want."
  },
  {
    question: "Where does Assist store my screenshots and context?",
    answer:
      "Screenshots, copied text, history, and optional transcripts are stored locally on your Mac. Assist does not OCR or interpret screenshots; you choose when to copy or drag the original context into another app."
  },
  {
    question: "What are the Mac requirements?",
    answer:
      "Assist requires macOS 14 Sonoma or later. Screenshots and clipboard history work on supported Macs; optional local voice transcription requires Apple silicon and a one-time Whisper model download."
  },
  {
    question: "Which macOS permissions does Assist need?",
    answer:
      "Screen Recording is required for screenshots. Accessibility or Input Monitoring lets Assist detect the Option and Control + Option shortcuts. Microphone access is optional and requested only when you enable voice context."
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
              <img src="/assist-icon.svg" alt="" width="30" height="30" />
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
        <div className="hero-video-frame">
          <video
            className="hero-video"
            src={featureVideos.annotation}
            aria-label="Assist capturing a voice-powered screen annotation"
            autoPlay
            loop
            muted
            playsInline
            preload="auto"
          />
        </div>
      </section>
      <section id="features" className="capability-section">
        <div className="trusted-by" aria-label="Companies where Assist users work">
          <p>Trusted by people at</p>
          <div className="trusted-companies">
            <span><img src="/brands/apple.svg" alt="" />Apple</span>
            <span><img src="/brands/microsoft.svg" alt="" />Microsoft</span>
            <span><img src="/brands/meta.svg" alt="" />Meta</span>
            <span><img src="/brands/amazon.svg" alt="" />Amazon</span>
            <span><img src="/brands/tiktok.svg" alt="" />TikTok</span>
            <span className="character-ai">(character.ai)</span>
            <span><img src="/brands/mistral-ai.svg" alt="" />Mistral AI</span>
            <span><img src="/brands/doordash.svg" alt="" />DoorDash</span>
          </div>
        </div>

        <div className="capability-intro">
          <p className="section-kicker">One notch. Three focused workflows.</p>
          <h2>The context layer for work on your Mac.</h2>
          <p>
            Capture what you see, add what you mean, and keep the things you copy
            close at hand.
          </p>
        </div>

        <div className="capability-grid" aria-label="Assist main features">
          <article className="capability-card">
            <h3>Voice-powered annotation</h3>
            <p>Hold Option to draw on the screen and speak your intent into the same locally prepared capture.</p>
          </article>
          <article className="capability-card">
            <h3>Instant full-screen screenshots</h3>
            <p>Press Control + Option to save a clean screenshot, then crop, blur, or frame it in the quick editor under the notch.</p>
          </article>
          <article className="capability-card">
            <h3>Clipboard history</h3>
            <p>Keep copied text alongside your captures. Find it in Recent Items, copy it again, or drag it into another app.</p>
          </article>
        </div>
      </section>

      <section className="feature-showcase" aria-labelledby="feature-tour-title">
        <div className="feature-showcase-intro">
          <p className="section-kicker">A closer look</p>
          <h2 id="feature-tour-title">Capture it. Explain it.</h2>
          <p>
            Take a clean screenshot or add drawings and a local voice transcript.
            Both are ready to copy or drag from the notch.
          </p>
        </div>

        <article className="feature-panel feature-panel-wide">
          <div className="feature-copy-block">
            <p className="feature-kicker">Voice annotation for Mac</p>
            <h3>Point at the screen. Say what you mean.</h3>
            <p className="feature-description">
              Hold Option anywhere on macOS to draw over what you see. Speak while
              you annotate and Assist adds a local transcript to the same capture,
              so the image and your intent stay together.
            </p>
            <ul className="feature-detail-list">
              <li>
                <strong>Draw with one hold</strong>
                <span>Hold Option, move the pointer, and release to save the annotated screenshot.</span>
              </li>
              <li>
                <strong>Transcribe locally</strong>
                <span>Optional Whisper transcription runs on Apple silicon, and raw audio is never saved.</span>
              </li>
              <li>
                <strong>Copy useful context</strong>
                <span>Reuse the original image and structured Markdown in chats, documents, and other apps.</span>
              </li>
            </ul>
          </div>
          <div className="feature-visual feature-video-visual" aria-hidden="true">
            <FeatureVideo src={featureVideos.annotation} />
          </div>
        </article>

        <article className="feature-panel feature-panel-wide">
          <div className="feature-copy-block">
            <p className="feature-kicker">Full-screen screenshots</p>
            <h3>Capture the screen before the moment passes.</h3>
            <p className="feature-description">
              Press Control + Option for a clean screenshot of the full display.
              It saves immediately, and a quick editor drops under the notch in
              case you want to crop, blur, or frame it before you share.
            </p>
            <ul className="feature-detail-list">
              <li>
                <strong>One global shortcut</strong>
                <span>Capture the full screen from any app without breaking your current flow.</span>
              </li>
              <li>
                <strong>Crop, blur, and frame</strong>
                <span>Trim the shot, blur what should stay private, or drop it on a backdrop—then expand for a closer look.</span>
              </li>
              <li>
                <strong>Drag into any workflow</strong>
                <span>Drop recent captures into messages, documents, or design tools.</span>
              </li>
            </ul>
          </div>
          <div className="feature-visual feature-video-visual" aria-hidden="true">
            <FeatureVideo src={featureVideos.screenshot} />
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
        <div className="footer-links-wrap">
          <div className="footer-brand-block">
            <a className="footer-brand" href="#top" aria-label="Assist home">
              <span className="brand-mark">
                <img src="/assist-icon.svg" alt="" width="30" height="30" />
              </span>
              <span>Assist</span>
            </a>
            <p>Voice annotation, screenshots, and clipboard history—right from your Mac notch.</p>
          </div>

          <nav className="footer-link-grid" aria-label="Footer navigation">
            <div>
              <h3>Menu</h3>
              <a href="#top">Home</a>
              <a href="#features">Features</a>
              <a href="#pricing">Pricing</a>
              <a href="#faq">FAQ</a>
            </div>
            <div>
              <h3>Company</h3>
              <a href="mailto:abhishek@thinkingsoundlab.com">Contact</a>
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
          <p>Built for focused Mac workflows.</p>
        </div>
      </footer>
    </main>
  );
}
