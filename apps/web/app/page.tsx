import ClipRow from "./ClipRow";
import FeatureVideo from "./FeatureVideo";
import MobileMenu from "./MobileMenu";

const checkoutHref = "/api/checkout";
const siteUrl = "https://assistapp.dev";

const faqItems = [
  {
    question: "What is Assist?",
    answer:
      "Assist is a native macOS capture tool that keeps screenshots, annotations, and copied text close to your workflow through a notch-style shelf."
  },
  {
    question: "Where is my captured context stored?",
    answer:
      "Assist is designed to be local-first, so your screenshots and copied items stay on your Mac unless you choose to share or export them."
  },
  {
    question: "Does Assist upload my screenshots?",
    answer:
      "No automatic upload is required for the core workflow. Capture, annotate, and reuse items from your Mac without sending your history to a cloud service."
  },
  {
    question: "What can I capture?",
    answer:
      "You can capture full screen screenshots with Control + Option, create annotated screenshots by holding Option, and save copied text for reuse."
  },
  {
    question: "Can I drag captures into other apps?",
    answer:
      "Yes. The notch shelf is built so recent captures can be dragged straight into documents, chats, design tools, and developer workflows."
  },
  {
    question: "Which versions of macOS does Assist support?",
    answer: "Assist requires macOS 14 (Sonoma) or later."
  },
  {
    question: "How many Macs can I use Assist on?",
    answer:
      "An early access license covers one device. Your license key activates Assist on a single Mac."
  },
  {
    question: "Is Assist a subscription?",
    answer:
      "No. The pricing model is a one-time license for macOS, with lifetime access to the included feature set and future 1.x updates."
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
        "Assist is a native macOS app for screenshots, annotations, and clipboard history. Capture, annotate, and reuse screenshots and copied text from a notch-style shelf.",
      url: siteUrl,
      image: `${siteUrl}/og-image.png`,
      offers: {
        "@type": "Offer",
        price: "12",
        priceCurrency: "USD",
        category: "one-time purchase",
        availability: "https://schema.org/InStock"
      },
      featureList: [
        "Full screen screenshot capture",
        "Option-hold annotation",
        "Notch-style capture shelf",
        "Drag and drop from notch",
        "Copied text and screenshot history",
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

const featureVideos = {
  dragDrop:
    "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/Assist%20Demos.mp4",
  annotate:
    "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/annotationedit.mp4",
  fullScreen:
    "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/fullscreenedit.mp4"
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
          <p className="eyebrow">Screenshot memory for builders</p>
          <h1>
            <span className="headline-context">Context</span>
            <span className="headline-captured">captured.</span>
          </h1>
          <p className="hero-copy">
            Assist keeps screenshots, annotations, and copied text in a fast
            local shelf you can reuse when your workflow needs context.
          </p>
          <a className="hero-download-button" href={checkoutHref}>
            <span aria-hidden="true"></span>
            <span>Download for Mac</span>
          </a>
        </div>
        <div className="landscape" aria-hidden="true">
          <div className="glass-shell" />
          <div className="notch-preview">
            <div className="notch-bar">
              <span>Recent items</span>
              <div className="notch-tools">
                <span className="tool-icon grid-icon" />
                <span className="tool-icon image-icon" />
                <span className="tool-icon folder-icon" />
              </div>
            </div>
            <ClipRow />
          </div>
        </div>

      </section>
      <section id="features" className="clipboard-section">
        <div className="clipboard-copy">
          <h2>Your clipboard, wherever you need it</h2>
          <p>
            Use the notch shelf, drag and drop, and the full Library view to
            reuse recent screenshots, annotations, and copied text.
          </p>
          <div className="feature-tags" aria-label="Assist features">
            <span>Local first</span>
            <span>Privacy first</span>
            <span>Option to annotate</span>
            <span>Screenshots</span>
            <span>Control + Option capture</span>
            <span>Copied text</span>
            <span>Drag from notch</span>
            <span>Local library</span>
            <span>Delete history items</span>
          </div>
        </div>
      </section>

      <section className="feature-showcase" aria-label="Assist feature tour">
        <article className="feature-panel feature-panel-wide">
          <div className="feature-copy-block">
            <p className="feature-kicker">Notch shelf</p>
            <h3>Drag and drop from notch</h3>
            <p>
              Keep your last captures close and drop them straight into the
              app that needs them.
            </p>
          </div>
          <div className="feature-visual feature-video-visual" aria-hidden="true">
            <FeatureVideo src={featureVideos.dragDrop} />
          </div>
        </article>

        <div className="feature-grid">
          <article className="feature-panel">
            <div className="feature-copy-block">
              <p className="feature-kicker">Fast markup</p>
              <h3>Annotate anywhere</h3>
              <p>
                Hold Option, draw with your pointer, and release to save the
                annotated screenshot.
              </p>
            </div>
            <div className="feature-visual feature-video-visual" aria-hidden="true">
              <FeatureVideo src={featureVideos.annotate} />
            </div>
          </article>

          <article className="feature-panel">
            <div className="feature-copy-block">
              <p className="feature-kicker">Full screen memory</p>
              <h3>Take full screen screenshots</h3>
              <p>
                Press Control + Option to capture the whole desktop in one
                motion, without starting annotation.
              </p>
            </div>
            <div className="feature-visual feature-video-visual" aria-hidden="true">
              <FeatureVideo src={featureVideos.fullScreen} />
            </div>
          </article>
        </div>
      </section>

      <section id="pricing" className="pricing-section">
        <div className="section-heading">
          <p className="section-kicker">Limited offer for early users</p>
          <h2>One price. Lifetime access.</h2>
          <p>
            Get Assist for your Mac with every capture, markup, notch shelf,
            copied text item, and local history feature unlocked from day one.
          </p>
        </div>

        <div className="pricing-card">
          <div className="pricing-card-header">
            <span className="pricing-pill">Assist app for macOS</span>
            <div className="pricing-options" aria-label="Pricing options">
              <div className="pricing-option pricing-option-active">
                <span>1 device</span>
              </div>
            </div>
          </div>

          <div className="pricing-price" aria-label="$12">
            <span>$</span>
            <strong>12</strong>
          </div>

          <div className="pricing-offer">
            <span>Limited offer for early users</span>
            <strong>Early access price</strong>
          </div>

          <ul className="pricing-features" aria-label="Included features">
            <li>One-time payment</li>
            <li>All features unlocked from day one</li>
            <li>Full screen screenshot capture</li>
            <li>Option-hold annotation</li>
            <li>Control + Option clean screenshots</li>
            <li>Drag and drop from notch</li>
            <li>Copied text and screenshot history</li>
            <li>Lifetime updates included</li>
            <li>Native macOS app</li>
          </ul>

          <a className="pricing-button" href={checkoutHref}>
            <span aria-hidden="true"></span>
            <span>Download for Mac</span>
          </a>

          <p className="pricing-note">
            Prices are in USD. Early access licenses include all current
            Assist features and future 1.x updates. Requires macOS 14 or
            later.
          </p>
        </div>
      </section>

      <section id="faq" className="faq-section">
        <div className="section-heading">
          <p className="section-kicker">FAQ</p>
          <h2>Frequently Asked Questions</h2>
          <p>
            Everything you need to know before using Assist, from local storage
            to screenshots, annotations, and device support.
          </p>
        </div>

        <div className="faq-list">
          {faqItems.map((item, index) => (
            <details className="faq-item" key={item.question} open={index === 0}>
              <summary>
                <span>{item.question}</span>
                <span className="faq-icon" aria-hidden="true" />
              </summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
      </section>

      <footer className="site-footer">
        <div className="footer-app-card">
          <div className="footer-app-label">
            <span className="footer-app-dot">
              <img src="/assist-icon.svg" alt="" width="30" height="30" />
            </span>
            <span>macOS app</span>
          </div>
          <h2>
            <span>Context</span>
            <span>captured.</span>
          </h2>
          <p>
            Keep screenshots, annotations, and copied text ready whenever
            your workflow needs them.
          </p>
          <a className="footer-download-button" href={checkoutHref}>
            <span aria-hidden="true"></span>
            <span>Download</span>
          </a>
        </div>

        <div className="footer-links-wrap">
          <div className="footer-brand-block">
            <a className="footer-brand" href="#top" aria-label="Assist home">
              <span className="brand-mark">
                <img src="/assist-icon.svg" alt="" width="30" height="30" />
              </span>
              <span>Assist</span>
            </a>
            <p>Native capture memory for Mac builders.</p>
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
              <a href="#top">Contact</a>
            </div>
            <div>
              <h3>Legal</h3>
              <a href="#top">Privacy policy</a>
              <a href="#top">Terms of service</a>
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
