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
          <h1 className="hero-title">
            <span>Dynamic Island for Your</span>
            <span>Coding Agents</span>
          </h1>
          <p className="hero-copy">
            Assist helps you monitor coding agents, approve requests, capture
            screenshots, and annotate—right from the notch.
          </p>
          <div className="hero-actions">
            <a className="hero-download-button" href={checkoutHref}>
              <span aria-hidden="true"></span>
              <span>Download for Mac</span>
            </a>
            <a className="hero-price-button" href="#pricing">
              <span>$12 · One-time →</span>
            </a>
          </div>
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

        <div className="capability-grid" aria-label="Assist capabilities">
          <article className="capability-card">
            <h3>Live task monitor</h3>
            <p>See Codex and Claude Code work in a vertical stack, with up to three active tasks visible at once.</p>
          </article>
          <article className="capability-card">
            <h3>Approve in place</h3>
            <p>Allow or deny agent permission requests directly from the island instead of finding the right terminal.</p>
          </article>
          <article className="capability-card">
            <h3>Answer from the notch</h3>
            <p>Respond when a coding agent asks for direction, without leaving the app or task already in front of you.</p>
          </article>
          <article className="capability-card">
            <h3>Know your runway</h3>
            <p>Keep Claude and Codex usage windows visible in both the collapsed and expanded island.</p>
          </article>
          <article className="capability-card">
            <h3>Screenshot capture</h3>
            <p>Press Control + Option to save a clean full-screen screenshot straight to your recent context.</p>
          </article>
          <article className="capability-card">
            <h3>Point out what matters</h3>
            <p>Hold Option, draw over the screen, and release to save an annotated screenshot instantly.</p>
          </article>
          <article className="capability-card">
            <h3>Copied text, remembered</h3>
            <p>Keep recent copied text beside screenshots so the exact detail you need is ready to reuse.</p>
          </article>
          <article className="capability-card">
            <h3>Move context anywhere</h3>
            <p>Drag recent items from the notch into agent prompts, documents, chats, and design tools.</p>
          </article>
          <article className="capability-card">
            <h3>Local by design</h3>
            <p>Your agent events, screenshots, annotations, and copied text stay connected locally on your Mac.</p>
          </article>
        </div>
      </section>

      <section id="pricing" className="pricing-section">
        <div className="section-heading">
          <h2>Ready to upgrade your workflow?</h2>
          <p>One-time purchase. No subscriptions.</p>
        </div>

        <div className="pricing-card">
          <h3>Assist License</h3>

          <div className="pricing-price" aria-label="$12">
            <strong>$12</strong>
          </div>

          <p className="pricing-license-note">1 Mac · one-time purchase</p>

          <ul className="pricing-features" aria-label="Included features">
            <li>Codex and Claude Code monitoring</li>
            <li>Approvals and question answering</li>
            <li>Screenshot capture and annotation</li>
            <li>Copied text and screenshot history</li>
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
            How agent monitoring, approvals, capture, privacy, and licensing
            work in Assist.
          </p>
        </div>

        <div className="faq-list">
          <details className="faq-item" open>
            <summary>
              <span>Which coding agents does Assist support?</span>
              <span className="faq-state" aria-hidden="true" />
            </summary>
            <p>
              Assist currently connects to Codex and terminal Claude Code. It
              shows active tasks, their latest status, and the detected Claude
              Code version directly in the island.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>Can I approve requests and answer agents from the island?</span>
              <span className="faq-state" aria-hidden="true" />
            </summary>
            <p>
              Yes. Codex and Claude Code permission requests appear in the
              island, where you can allow or deny them. Agent questions also
              expand in place so you can respond without finding the terminal.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>How many agent tasks can I see at once?</span>
              <span className="faq-state" aria-hidden="true" />
            </summary>
            <p>
              The expanded island shows up to three active tasks in a vertical
              stack. Claude and Codex usage windows remain available in both
              the collapsed and expanded states.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>What can I capture and reuse?</span>
              <span className="faq-state" aria-hidden="true" />
            </summary>
            <p>
              Press Control + Option for a clean full-screen screenshot, or
              hold Option to draw and save an annotated screenshot. Assist also
              keeps recent copied text ready to reuse or drag into another app.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>Where is my captured context stored?</span>
              <span className="faq-state" aria-hidden="true" />
            </summary>
            <p>
              Screenshot metadata and history are stored locally on your Mac.
              Assist also uses local Vision OCR for its first-pass screenshot
              context instead of sending the image to a remote vision model.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>Does Assist require any macOS permissions?</span>
              <span className="faq-state" aria-hidden="true" />
            </summary>
            <p>
              Screen &amp; System Audio Recording is required for capture.
              Accessibility or Input Monitoring lets Assist detect the global
              Option and Control + Option shortcuts.
            </p>
          </details>

          <details className="faq-item">
            <summary>
              <span>Is Assist a subscription?</span>
              <span className="faq-state" aria-hidden="true" />
            </summary>
            <p>
              No. Assist is $12 for one Mac as a one-time purchase—there is no
              recurring subscription.
            </p>
          </details>
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
