import type { ReactNode } from "react";
import MobileMenu from "./MobileMenu";

type LegalSection = {
  id: string;
  label: string;
};

type LegalDocumentProps = {
  title: string;
  description: string;
  lastUpdated: string;
  sections: LegalSection[];
  children: ReactNode;
};

export default function LegalDocument({
  title,
  description,
  lastUpdated,
  sections,
  children
}: LegalDocumentProps) {
  return (
    <main className="legal-page">
      <header className="site-header" aria-label="Site header">
        <nav className="header-pill" aria-label="Primary navigation">
          <a className="brand" href="/" aria-label="Assist home">
            <span className="brand-mark">
              <img src="/assist-icon.svg" alt="" width="30" height="30" />
            </span>
            <span>Assist</span>
          </a>
          <div className="nav-links">
            <a href="/#features">Features</a>
            <a href="/#faq">FAQ</a>
            <a href="/#pricing">Pricing</a>
          </div>
          <a className="download-button" href="/api/checkout" aria-label="Download Assist">
            <span aria-hidden="true"></span>
            <span>Download</span>
          </a>
          <MobileMenu sectionPrefix="/" />
        </nav>
      </header>

      <section className="legal-hero">
        <div className="legal-hero-content">
          <p className="legal-kicker">Legal</p>
          <h1>{title}</h1>
          <p className="legal-description">{description}</p>
          <p className="legal-date">Last updated: {lastUpdated}</p>
        </div>
      </section>

      <div className="legal-layout">
        <aside className="legal-toc" aria-label="On this page">
          <p>On this page</p>
          <nav>
            {sections.map((section) => (
              <a key={section.id} href={`#${section.id}`}>
                {section.label}
              </a>
            ))}
          </nav>
        </aside>
        <article className="legal-document">{children}</article>
      </div>

      <footer className="site-footer legal-footer">
        <div className="footer-links-wrap">
          <div className="footer-brand-block">
            <a className="footer-brand" href="/" aria-label="Assist home">
              <span className="brand-mark">
                <img src="/assist-icon.svg" alt="" width="30" height="30" />
              </span>
              <span>Assist</span>
            </a>
            <p>Coding agents, approvals, screenshots, and context—right from your Mac notch.</p>
          </div>

          <nav className="footer-link-grid" aria-label="Footer navigation">
            <div>
              <h3>Menu</h3>
              <a href="/">Home</a>
              <a href="/#features">Features</a>
              <a href="/#pricing">Pricing</a>
              <a href="/#faq">FAQ</a>
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
