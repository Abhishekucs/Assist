import ClipRow from "./ClipRow";
import MobileMenu from "./MobileMenu";

const checkoutHref = "/api/checkout";

export default function Home() {
  return (
    <main>
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
              <span>RECENT ITEMS</span>
              <div className="notch-tools">
                <span className="tool-icon filter-icon" />
                <span className="tool-icon image-icon" />
                <span className="tool-icon folder-icon" />
                <span className="tool-icon copy-icon" />
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
            <p className="feature-kicker">Full screen memory</p>
            <h3>Take full screen screenshots</h3>
            <p>
              Press Control + Option to capture the whole desktop in one
              motion, without starting annotation.
            </p>
          </div>
          <div className="feature-visual full-capture-visual" aria-hidden="true">
            <div className="feature-desktop">
              <div className="desktop-window desktop-window-main">
                <span />
                <span />
                <span />
              </div>
              <div className="desktop-window desktop-window-side">
                <span />
                <span />
              </div>
              <div className="capture-outline">
                <span className="capture-corner corner-tl" />
                <span className="capture-corner corner-tr" />
                <span className="capture-corner corner-bl" />
                <span className="capture-corner corner-br" />
              </div>
              <div className="feature-notch">
                <span>RECENT ITEMS</span>
                <div className="feature-notch-row">
                  <i />
                  <i />
                  <i />
                  <i />
                </div>
              </div>
            </div>
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
            <div className="feature-visual annotate-visual" aria-hidden="true">
              <div className="annotation-canvas">
                <span className="annotation-line line-one" />
                <span className="annotation-line line-two" />
                <span className="annotation-dot" />
                <div className="annotation-card">
                  <span />
                  <span />
                  <span />
                </div>
              </div>
            </div>
          </article>

          <article className="feature-panel">
            <div className="feature-copy-block">
              <p className="feature-kicker">Notch shelf</p>
              <h3>Drag and drop from notch</h3>
              <p>
                Keep your last captures close and drop them straight into the
                app that needs them.
              </p>
            </div>
            <div className="feature-visual drag-visual" aria-hidden="true">
              <div className="mini-notch-shelf">
                <span />
                <span />
                <span />
              </div>
              <div className="dragged-card">
                <span />
                <span />
              </div>
              <div className="drop-target">
                <span />
              </div>
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

          <div className="pricing-price" aria-label="$15">
            <span>$</span>
            <strong>15</strong>
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
            Assist features and future 1.x updates.
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
          <details className="faq-item" open>
            <summary>
              <span>What is Assist?</span>
              <span className="faq-icon" aria-hidden="true" />
            </summary>
            <p>
              Assist is a native macOS capture tool that keeps screenshots,
              annotations, and copied text close to your workflow through a
              notch-style shelf.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>Where is my captured context stored?</span>
              <span className="faq-icon" aria-hidden="true" />
            </summary>
            <p>
              Assist is designed to be local-first, so your screenshots and
              copied items stay on your Mac unless you choose to share or export
              them.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>Does Assist upload my screenshots?</span>
              <span className="faq-icon" aria-hidden="true" />
            </summary>
            <p>
              No automatic upload is required for the core workflow. Capture,
              annotate, and reuse items from your Mac without sending your
              history to a cloud service.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>What can I capture?</span>
              <span className="faq-icon" aria-hidden="true" />
            </summary>
            <p>
              You can capture full screen screenshots with Control + Option,
              create annotated screenshots by holding Option, and save copied
              text for reuse.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>Can I drag captures into other apps?</span>
              <span className="faq-icon" aria-hidden="true" />
            </summary>
            <p>
              Yes. The notch shelf is built so recent captures can be dragged
              straight into documents, chats, design tools, and developer
              workflows.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>Is Assist a subscription?</span>
              <span className="faq-icon" aria-hidden="true" />
            </summary>
            <p>
              No. The pricing model is a one-time license for macOS, with
              lifetime access to the included feature set.
            </p>
          </details>
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
