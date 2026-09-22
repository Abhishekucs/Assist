import type { ReactNode } from "react";
import SiteFooter from "./SiteFooter";
import SiteHeader from "./SiteHeader";

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
    <main id="top" className="legal-page">
      <SiteHeader />

      <section className="legal-hero">
        <div className="legal-hero-content">
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

      <div className="legal-footer">
        <SiteFooter showCallToAction={false} />
      </div>
    </main>
  );
}
