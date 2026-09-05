import LegalDocument from "../LegalDocument";
import { createLegalMetadata } from "../legalMetadata";

const description =
  "The terms that apply to Assist for Mac, voice annotation, screenshots, clipboard history, official downloads, licenses, purchases, updates, and support.";

export const metadata = createLegalMetadata("Terms of Use", description, "/terms");

const sections = [
  { id: "agreement", label: "Agreement" },
  { id: "service", label: "What Assist does" },
  { id: "license", label: "License and open source" },
  { id: "responsibilities", label: "Your responsibilities" },
  { id: "content", label: "Your content" },
  { id: "purchases", label: "Purchases and refunds" },
  { id: "updates", label: "Updates and availability" },
  { id: "third-parties", label: "Third-party services" },
  { id: "privacy", label: "Privacy" },
  { id: "intellectual-property", label: "Intellectual property" },
  { id: "disclaimers", label: "Disclaimers" },
  { id: "liability", label: "Limitation of liability" },
  { id: "termination", label: "Termination" },
  { id: "law", label: "Applicable law" },
  { id: "changes", label: "Changes" },
  { id: "contact", label: "Contact" }
];

export default function TermsPage() {
  return (
    <LegalDocument
      title="Terms of Use"
      description={description}
      lastUpdated="August 27, 2026"
      sections={sections}
    >
      <section id="agreement">
        <h2>1. Agreement to these terms</h2>
        <p>
          These Terms of Use govern your access to and use of the official Assist macOS builds,
          assistapp.dev, purchase and license services, updates, and support (together, the
          “Services”). “Assist,” “we,” “us,” and “our” refer to Thinking Sound Lab Private
          Limited, an Indian private limited company (CIN U62013BR2025PTC079572) with its
          registered office at C/O Kumari Puspa, Ashok Vihar Colony, A.P. Colony, Gaya, Bihar
          823001, India.
        </p>
        <p>
          By purchasing, downloading, activating, or using the Services, you agree to these
          terms and the <a href="/privacy">Privacy Policy</a>. If you do not agree, do not use
          the Services. You must be legally able to enter into this agreement. If you use Assist
          for an organization, you represent that you have authority to bind it to these terms.
        </p>
      </section>

      <section id="service">
        <h2>2. What Assist does</h2>
        <p>
          Assist is a macOS utility for capturing screenshots, adding visual and voice
          annotations, and keeping recent copied text available for reuse from the Mac notch
          and a local library.
        </p>
        <div className="legal-fact-grid" aria-label="Current purchase details">
          <div>
            <strong>One-time purchase</strong>
            <span>No recurring subscription for the current offer</span>
          </div>
          <div>
            <strong>One Mac</strong>
            <span>One official-build activation per purchased license</span>
          </div>
          <div>
            <strong>macOS 14+</strong>
            <span>A compatible Mac and required system permissions are needed</span>
          </div>
        </div>
        <p>
          Feature descriptions on the purchase page form part of the offer at the time of your
          purchase. Some features depend on macOS permissions, local voice-model setup,
          configuration, network access, and compatible hardware.
        </p>
      </section>

      <section id="license">
        <h2>3. Official-build license and open-source rights</h2>
        <p>
          After successful payment, you receive access to the official Assist build and a
          license for one Mac, subject to the purchase description and these terms. You may not
          share a license key, use it to activate more devices than the offer permits, resell
          official download access, or interfere with the hosted license service. Contact us if
          you replace your Mac or need a legitimate activation reset.
        </p>
        <p>
          Assist also includes source code and third-party components distributed under
          open-source licenses. Your rights in that code are governed by the applicable license
          files, including the license in the Assist source repository. Nothing in these terms
          restricts rights that an open-source license expressly grants. These terms separately
          govern the official paid build, hosted purchase and license services, Assist branding,
          updates, and support.
        </p>
      </section>

      <section id="responsibilities">
        <h2>4. Your responsibilities and acceptable use</h2>
        <p>You are responsible for your Mac, accounts, content, and use of Assist. You agree to:</p>
        <ul>
          <li>use the Services lawfully and respect the rights of others;</li>
          <li>obtain permission before capturing, monitoring, or sharing content you do not own;</li>
          <li>protect your Mac, license key, and any confidential information;</li>
          <li>review screenshots and copied text before moving them into another application;</li>
          <li>maintain backups of content you need; and</li>
          <li>comply with the terms of connected services you use with Assist.</li>
        </ul>
        <p>You must not:</p>
        <ul>
          <li>use the Services to violate law, privacy, intellectual-property, or contractual rights;</li>
          <li>introduce malware or attempt to disrupt, overload, or gain unauthorized access to the website, checkout, APIs, or license systems;</li>
          <li>use stolen payment details, fraudulent chargebacks, or unlawfully obtained license keys; or</li>
          <li>misrepresent Assist as your product or use Assist trademarks in a misleading way.</li>
        </ul>
      </section>

      <section id="content">
        <h2>5. Screenshots, clipboard data, and your content</h2>
        <p>
          You retain ownership of content you capture, copy, annotate, or send through Assist.
          You are responsible for having the rights and permissions needed to use that content.
          Assist does not claim ownership of it.
        </p>
        <p>
          Clipboard text and screenshots can include passwords, API keys, personal data, source
          code, customer records, or other confidential material. Assist is not a secret scanner
          and does not promise to identify or redact sensitive information. Keep your Mac secure,
          delete items you no longer need, and inspect content before dragging or pasting it into
          chats, documents, or other services.
        </p>
        <p>
          Local data can be lost through deletion, device failure, operating-system changes, or
          other events. Assist is not a backup service.
        </p>
      </section>

      <section id="purchases">
        <h2>6. Purchases, billing, and refunds</h2>
        <p>
          Dodo Payments acts as merchant of record for purchases. Its checkout terms and privacy
          policy apply to payment processing, taxes, invoices, fraud screening, and payment
          disputes. Prices and included features are those shown at checkout, and taxes or local
          charges may be added where required.
        </p>
        <p>
          Because the official build and license are digital goods delivered after purchase,
          payments are final except where applicable law requires a refund. If you experience a
          duplicate charge, failed delivery, or a material technical or licensing problem,
          contact us. We may provide troubleshooting, replacement access, an activation reset,
          or a discretionary refund as appropriate. Nothing here limits mandatory consumer
          rights.
        </p>
      </section>

      <section id="updates">
        <h2>7. Updates, changes, and availability</h2>
        <p>
          The current purchase offer includes lifetime access to the purchased official build
          and updates in the 1.x release line. “Lifetime” refers to the supported life of the
          product and compatible systems, not the lifetime of a person. It does not promise that
          every feature, third-party integration, download server, or operating-system version
          will remain available indefinitely.
        </p>
        <p>
          We may add, change, deprecate, or remove features to improve Assist, respond to security
          concerns, comply with law, or adapt to macOS and third-party platform changes. Updates may
          be required for continued compatibility or security. Beta or early-access features may
          be less reliable and may change without notice.
        </p>
      </section>

      <section id="third-parties">
        <h2>8. Third-party services</h2>
        <p>
          Assist interoperates with or relies on services such as Dodo Payments, Supabase,
          Vercel, GitHub, and Apple&apos;s macOS. Those products are controlled by
          their respective providers and are governed by their own terms. We are not responsible
          for third-party availability, output, security, pricing, policy changes, or data
          practices.
        </p>
        <p>
          A change by Apple or a service provider may limit a feature or require us to modify
          Assist. Links to third-party sites are provided for convenience and do not imply
          endorsement of all content on those sites.
        </p>
      </section>

      <section id="privacy">
        <h2>9. Privacy</h2>
        <p>
          The <a href="/privacy">Privacy Policy</a> explains how Assist handles local app data,
          license and purchase records, website analytics, service-provider disclosures, and
          privacy choices. By using the Services, you acknowledge those practices.
        </p>
      </section>

      <section id="intellectual-property">
        <h2>10. Intellectual property and feedback</h2>
        <p>
          Except for open-source code and third-party materials governed by their own licenses,
          Assist&apos;s official website content, branding, logos, and service design are owned by or
          licensed to us and are protected by applicable law. No trademark rights are granted by
          these terms.
        </p>
        <p>
          If you voluntarily provide feedback, you grant us a worldwide, perpetual, irrevocable,
          royalty-free right to use it to develop, improve, and promote Assist, without an
          obligation to compensate you. This does not transfer ownership of your source code,
          screenshots, or other app content.
        </p>
      </section>

      <section id="disclaimers">
        <h2>11. Disclaimers</h2>
        <p>
          To the maximum extent permitted by law, the Services are provided “as is” and “as
          available.” We disclaim implied warranties of merchantability, fitness for a particular
          purpose, non-infringement, and uninterrupted or error-free operation. We do not warrant
          that Assist will capture every item, preserve every item, or remain compatible with
          every Mac or operating-system version.
        </p>
        <p>
          Some jurisdictions do not allow certain warranty exclusions, so some of these terms may
          not apply to you. Mandatory warranties and consumer guarantees remain unaffected.
        </p>
      </section>

      <section id="liability">
        <h2>12. Limitation of liability</h2>
        <p>
          To the maximum extent permitted by law, Assist and its developer will not be liable for
          indirect, incidental, special, consequential, exemplary, or punitive damages, or for
          loss of data, source code, profits, revenue, business opportunity, goodwill, or security,
          arising from or related to the Services, third-party services, or these
          terms.
        </p>
        <p>
          To the maximum extent permitted by law, our total aggregate liability for all claims
          relating to the Services will not exceed the amount you paid for Assist. These limits do
          not apply where liability cannot lawfully be excluded or limited, including any rights
          available under mandatory consumer law.
        </p>
      </section>

      <section id="termination">
        <h2>13. Suspension and termination</h2>
        <p>
          You may stop using Assist at any time. We may suspend hosted purchase, download, license,
          update, or support access if we reasonably believe there is fraud, unlawful use, a
          security threat, material breach of these terms, or a legal requirement. Where
          practical, we will give notice and an opportunity to resolve the issue.
        </p>
        <p>
          Payment obligations, open-source rights, intellectual-property provisions,
          disclaimers, liability limits, and dispute provisions will survive termination when
          their nature requires it.
        </p>
      </section>

      <section id="law">
        <h2>14. Applicable law and disputes</h2>
        <p>
          Before starting formal proceedings, please contact us and allow 30 days to try to
          resolve the dispute informally. These terms are governed by the laws of India, without
          regard to conflict-of-law principles. The courts in Gaya, Bihar will have exclusive
          jurisdiction, except where mandatory consumer law gives you the right to bring a claim
          elsewhere or requires a different law or forum.
        </p>
      </section>

      <section id="changes">
        <h2>15. Changes and general terms</h2>
        <p>
          We may update these terms to reflect changes to Assist, our providers, or legal
          requirements. The revised terms will be posted here with a new date. Material changes
          will apply prospectively and will receive additional notice when reasonably appropriate.
          Continued use after the effective date means you accept the revised terms.
        </p>
        <p>
          If a provision is unenforceable, it will be limited to the minimum extent necessary and
          the remaining provisions will continue. A failure to enforce a provision is not a waiver.
          You may not assign these terms without our consent; we may assign them as part of a
          reorganization, financing, merger, acquisition, or sale of the Services. These terms,
          the Privacy Policy, and the purchase description are the entire agreement concerning
          the Services.
        </p>
      </section>

      <section id="contact">
        <h2>16. Contact</h2>
        <p>
          Questions about these terms can be sent to Assist at{" "}
          <a href="mailto:abhishek@thinkingsoundlab.com">abhishek@thinkingsoundlab.com</a>.
        </p>
        <address>
          Thinking Sound Lab Private Limited<br />
          CIN U62013BR2025PTC079572<br />
          C/O Kumari Puspa, Ashok Vihar Colony, A.P. Colony<br />
          Gaya, Bihar 823001, India
        </address>
      </section>
    </LegalDocument>
  );
}
