import FeatureVideo from "./FeatureVideo";
import JsonLd from "./JsonLd";
import SiteFooter from "./SiteFooter";
import SiteHeader from "./SiteHeader";
import {
  CHECKOUT_HREF,
  PRODUCT_FEATURES,
  SITE_NAME,
  SITE_URL,
  type ProductFeature
} from "./productContent";

type ProductFeaturePageProps = {
  feature: ProductFeature;
};

export default function ProductFeaturePage({ feature }: ProductFeaturePageProps) {
  const pageUrl = `${SITE_URL}${feature.path}`;
  const relatedFeatures = PRODUCT_FEATURES.filter(
    (item) => item.path !== feature.path
  );
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        "@id": `${pageUrl}#webpage`,
        url: pageUrl,
        name: feature.metadataTitle,
        description: feature.metadataDescription,
        isPartOf: { "@id": `${SITE_URL}/#website` },
        about: { "@id": `${SITE_URL}/#app` },
        inLanguage: "en"
      },
      {
        "@type": "BreadcrumbList",
        "@id": `${pageUrl}#breadcrumb`,
        itemListElement: [
          {
            "@type": "ListItem",
            position: 1,
            name: SITE_NAME,
            item: SITE_URL
          },
          {
            "@type": "ListItem",
            position: 2,
            name: feature.name,
            item: pageUrl
          }
        ]
      },
      {
        "@type": "FAQPage",
        "@id": `${pageUrl}#faq`,
        mainEntity: feature.faqs.map((item) => ({
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

  return (
    <main id="top" className="feature-page">
      <JsonLd data={structuredData} />
      <SiteHeader activePath={feature.path} />

      <section className="feature-page-hero">
        <div className="feature-page-hero-copy">
          <h1>{feature.title}</h1>
          <p className="feature-page-summary">{feature.summary}</p>
          <div className="feature-page-actions">
            <a className="hero-download-button" href={CHECKOUT_HREF}>
              <span aria-hidden="true"></span>
              <span>Get Assist for Mac</span>
            </a>
            <a className="feature-page-secondary-link" href="/#pricing">
              View pricing
            </a>
          </div>
          <p className="hero-platform-note">macOS 14+ · Apple silicon for voice</p>
        </div>

        <div className="feature-page-video" role="img" aria-label={feature.videoLabel}>
          <FeatureVideo src={feature.video} />
        </div>
      </section>

      <section className="feature-answer-section" aria-labelledby={`${feature.id}-answer`}>
        <h2 id={`${feature.id}-answer`}>{feature.directQuestion}</h2>
        <p>{feature.directAnswer}</p>
      </section>

      <section className="feature-benefit-section" aria-labelledby={`${feature.id}-benefits`}>
        <div className="feature-section-heading">
          <h2 id={`${feature.id}-benefits`}>{feature.name}, without the extra steps.</h2>
        </div>
        <div className="feature-benefit-grid">
          {feature.benefits.map((benefit) => (
            <article key={benefit.title}>
              <h3>{benefit.title}</h3>
              <p>{benefit.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="feature-steps-section" aria-labelledby={`${feature.id}-steps`}>
        <div className="feature-section-heading">
          <h2 id={`${feature.id}-steps`}>Three steps, start to finish.</h2>
        </div>
        <ol className="feature-step-list">
          {feature.steps.map((step, index) => (
            <li key={step.title}>
              <span aria-hidden="true">{index + 1}</span>
              <div>
                <h3>{step.title}</h3>
                <p>{step.description}</p>
              </div>
            </li>
          ))}
        </ol>
      </section>

      <section className="feature-faq-section" aria-labelledby={`${feature.id}-faq`}>
        <div className="feature-section-heading">
          <h2 id={`${feature.id}-faq`}>About {feature.name.toLowerCase()}</h2>
        </div>
        <div className="faq-list">
          {feature.faqs.map((item, index) => (
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

      <section className="related-features" aria-labelledby={`${feature.id}-related`}>
        <h2 id={`${feature.id}-related`}>Explore the other workflows.</h2>
        <div className="related-feature-links">
          {relatedFeatures.map((item) => (
            <a href={item.path} key={item.path}>
              <span>{item.name}</span>
              <span aria-hidden="true">→</span>
            </a>
          ))}
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
