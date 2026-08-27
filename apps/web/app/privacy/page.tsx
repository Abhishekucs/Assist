import LegalDocument from "../LegalDocument";
import { createLegalMetadata } from "../legalMetadata";

const description =
  "How Assist handles screenshots, voice annotations, copied text, licenses, purchases, website analytics, and support information.";

export const metadata = createLegalMetadata("Privacy Policy", description, "/privacy");

const sections = [
  { id: "overview", label: "Overview" },
  { id: "information", label: "Information we handle" },
  { id: "permissions", label: "Mac permissions" },
  { id: "uses", label: "How we use information" },
  { id: "sharing", label: "Service providers" },
  { id: "cookies", label: "Cookies and analytics" },
  { id: "retention", label: "Retention and deletion" },
  { id: "security", label: "Security" },
  { id: "international", label: "International processing" },
  { id: "rights", label: "Your choices and rights" },
  { id: "children", label: "Children" },
  { id: "changes", label: "Changes" },
  { id: "contact", label: "Contact" }
];

export default function PrivacyPage() {
  return (
    <LegalDocument
      title="Privacy Policy"
      description={description}
      lastUpdated="August 27, 2026"
      sections={sections}
    >
      <section id="overview">
        <h2>1. Overview</h2>
        <p>
          Assist is a macOS utility for capturing screenshots, adding visual and voice
          annotations, and reusing copied text.
          The desktop app is designed so that your working context stays on your Mac. Assist
          does not upload your screenshots, annotations, voice transcripts, or copied
          text to Assist&apos;s servers unless you deliberately send that material through
          another service yourself.
        </p>
        <div className="legal-callout">
          <strong>In short:</strong> app content is processed locally; purchase and license
          details are processed online so we can sell, activate, and support the product;
          and the website uses privacy-focused Vercel Web Analytics.
        </div>
        <p>
          This policy applies to the Assist desktop application, assistapp.dev, the purchase
          and license services offered through the site, and support communications. It does
          not govern third-party applications or services you choose to use with Assist.
        </p>
        <p>
          Thinking Sound Lab Private Limited (CIN U62013BR2025PTC079572), with its registered
          office at C/O Kumari Puspa, Ashok Vihar Colony, A.P. Colony, Gaya, Bihar 823001,
          India, is the operator of Assist and the controller of personal information described
          in this policy, except where a service provider acts as an independent controller.
        </p>
      </section>

      <section id="information">
        <h2>2. Information we handle</h2>
        <div className="legal-table-wrap">
          <table>
            <thead>
              <tr>
                <th>Category</th>
                <th>Examples</th>
                <th>Where it is handled</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Captured content</td>
                <td>
                  Screenshots, annotations, thumbnails, copied text, optional local voice
                  transcripts, and capture metadata
                </td>
                <td>Stored locally in your Mac&apos;s Assist application-support folder</td>
              </tr>
              <tr>
                <td>Temporary voice audio</td>
                <td>Up to 90 seconds of speech recorded during an enabled annotation</td>
                <td>
                  Held only in memory until local transcription completes or Assist closes; never
                  saved to disk or uploaded by Assist
                </td>
              </tr>
              <tr>
                <td>License and device data</td>
                <td>
                  License key, license-instance identifier, Mac device name, app version,
                  activation and validation dates, and customer email
                </td>
                <td>Sent to Assist&apos;s license endpoint and Dodo Payments for validation</td>
              </tr>
              <tr>
                <td>Purchase records</td>
                <td>
                  Name, email, product and payment identifiers, payment status, amount, currency,
                  license key, purchase and download activity, billing address, phone number,
                  cardholder name, card last four digits, card network and type, payment method,
                  tax, invoice, refund and dispute details, and custom checkout responses when
                  Dodo includes them in its payment or webhook records
                </td>
                <td>
                  Processed by Dodo Payments; Assist stores purchase fields and copies of Dodo
                  payment and webhook event payloads in its Supabase database
                </td>
              </tr>
              <tr>
                <td>Website and support data</td>
                <td>
                  Anonymous page views, hosting request data, and information you include in an
                  email or support request
                </td>
                <td>Processed by Vercel and the services used to respond to you</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p>
          Assist does not receive or store your full payment-card number. Dodo Payments, as
          merchant of record, handles payment credentials, billing, tax, fraud checks, and
          related transaction obligations under its own privacy policy.
        </p>
        <p>
          The app also keeps preferences in macOS user defaults, activation information in the
          macOS Keychain, and a local diagnostic log. The diagnostic log is intended to contain
          operational events and errors, not the contents of your clipboard or screenshots.
        </p>
      </section>

      <section id="permissions">
        <h2>3. Mac permissions and local access</h2>
        <p>Assist may request or use the following access when you enable related features:</p>
        <ul>
          <li>
            <strong>Screen Recording</strong>{" "}to capture the screen and create screenshots or
            annotations.
          </li>
          <li>
            <strong>Accessibility or Input Monitoring</strong>{" "}to detect Assist&apos;s global
            keyboard gestures.
          </li>
          <li>
            <strong>Microphone</strong>{" "}to record speech only while you hold Option during an
            annotation when voice context is enabled. Recording stops after 90 seconds. Raw audio
            stays only in memory until its queued local transcription completes or Assist closes;
            it is never saved to disk or uploaded by Assist.
          </li>
          <li>
            <strong>Clipboard access</strong>{" "}to keep recent copied text available for reuse.
          </li>
          <li>
            <strong>Network access</strong>{" "}to validate a license, check or download updates from
            GitHub, download the optional pinned Whisper model from Hugging Face during explicit
            setup, and open the purchase or support experience.
          </li>
        </ul>
        <p>
          You control system permissions in macOS Settings. Disabling a permission may prevent
          the corresponding feature from working.
        </p>
        <p>
          During an upgrade, Assist removes only integration configuration entries created by
          older Assist versions. This cleanup does not read task or session logs and preserves
          unrelated configuration.
        </p>
      </section>

      <section id="uses">
        <h2>4. How we use information</h2>
        <p>We use the information described above to:</p>
        <ul>
          <li>provide voice annotation, screenshot, and clipboard features;</li>
          <li>complete purchases, issue downloads and licenses, and validate activations;</li>
          <li>maintain transaction, tax, accounting, fraud-prevention, and dispute records;</li>
          <li>deliver updates, diagnose errors, secure the service, and prevent abuse;</li>
          <li>answer support requests and communicate about the product; and</li>
          <li>understand aggregate website usage and improve the site.</li>
        </ul>
        <p>
          Where applicable law requires a legal basis, we rely on performance of our contract,
          our legitimate interests in operating and securing Assist, compliance with legal
          obligations, and consent where required. We do not sell personal information or use
          it for cross-context behavioral advertising.
        </p>
      </section>

      <section id="sharing">
        <h2>5. Service providers and disclosures</h2>
        <p>We disclose information only as needed for the purposes in this policy:</p>
        <ul>
          <li>
            <strong>
              <a href="https://dodopayments.com/privacy-policy">Dodo Payments</a>
            </strong>{" "}
            provides checkout, payment, tax, merchant-of-record, and license services.
          </li>
          <li>
            <strong>Supabase</strong>{" "}hosts Assist&apos;s purchase, webhook, license, and download
            records.
          </li>
          <li>
            <strong>
              <a href="https://vercel.com/docs/analytics/privacy-policy">Vercel</a>
            </strong>{" "}
            hosts the website and API routes and provides web analytics.
          </li>
          <li>
            <strong>GitHub</strong>{" "}hosts application releases and serves update information and
            downloads.
          </li>
        </ul>
        <p>
          These providers may process technical information such as IP addresses, request
          metadata, device or browser details, and service logs as part of delivering and
          securing their services. Their own terms and privacy policies also apply.
        </p>
        <p>
          We may also disclose information when required by law, to protect users or the public,
          to investigate fraud or security issues, or as part of a merger, acquisition,
          financing, reorganization, or sale of assets. If ownership changes, this policy will
          continue to apply until it is replaced with notice.
        </p>
      </section>

      <section id="cookies">
        <h2>6. Cookies and website analytics</h2>
        <p>
          assistapp.dev uses Vercel Web Analytics to measure page views and site performance in
          an anonymous, aggregated form. Vercel states that Web Analytics does not use cookies
          or collect personal identifiers for this purpose. Hosting and security systems may
          still process ordinary request information, including IP address and user-agent data.
        </p>
        <p>
          When you proceed to checkout, Dodo Payments may use cookies or similar technologies
          under its own policy to complete and secure the transaction. Assist does not currently
          run third-party advertising trackers.
        </p>
      </section>

      <section id="retention">
        <h2>7. Retention and deletion</h2>
        <ul>
          <li>
            <strong>Local app content</strong>{" "}remains on your Mac until you delete individual
            items or remove Assist&apos;s local data. Uninstalling the app may not automatically
            remove its application-support files, preferences, Keychain items, or backups.
          </li>
          <li>
            <strong>Purchase and license records</strong>{" "}are retained for as long as needed to
            deliver and validate your license and to meet accounting, tax, fraud-prevention,
            dispute, security, and legal obligations.
          </li>
          <li>
            <strong>Support messages</strong>{" "}are retained for as long as reasonably needed to
            resolve the request and maintain relevant business records.
          </li>
        </ul>
        <p>
          Deletion from active systems may not immediately remove information from backups or
          records that must be kept by law. Dodo Payments controls retention of the payment data
          it processes independently.
        </p>
      </section>

      <section id="security">
        <h2>8. Security</h2>
        <p>
          Assist uses reasonable safeguards appropriate to the information involved. Activation
          data is kept in the macOS Keychain, and purchase systems use access controls provided
          by their hosting services.
          No method of storage or transmission is completely secure, so we cannot guarantee
          absolute security.
        </p>
        <p>
          Copied text and screenshots can contain passwords, tokens, customer information, or
          other sensitive material. Review what you copy or capture, delete items you no longer
          need, protect access to your Mac, and do not rely on Assist to detect or remove secrets.
        </p>
      </section>

      <section id="international">
        <h2>9. International processing</h2>
        <p>
          Our service providers may process information in countries other than the country
          where you live. Those countries may have different data-protection laws. Where
          required, we and our providers use legally recognized safeguards for international
          transfers.
        </p>
      </section>

      <section id="rights">
        <h2>10. Your choices and privacy rights</h2>
        <p>
          You can delete local recent items in Assist, change macOS permissions, disable voice
          context, or remove the app&apos;s local data. Depending on where you live, you may also
          have rights to request access, correction, deletion, restriction, objection, or a copy
          of personal information we control, and to withdraw consent where processing relies on
          consent.
        </p>
        <p>
          Send a request to <a href="mailto:abhishek@thinkingsoundlab.com">abhishek@thinkingsoundlab.com</a>.
          We may need to verify your identity and may retain information where law permits or
          requires it. For payment information controlled by Dodo Payments, you may also need to
          contact Dodo directly. You may complain to your local data-protection authority.
        </p>
      </section>

      <section id="children">
        <h2>11. Children</h2>
        <p>
          Assist is not directed to children under 13, and we do not knowingly collect personal
          information from children under 13. If you believe a child has provided personal
          information through our online services, contact us so we can investigate and take
          appropriate action.
        </p>
      </section>

      <section id="changes">
        <h2>12. Changes to this policy</h2>
        <p>
          We may update this policy as Assist, our providers, or legal requirements change. The
          updated version will appear on this page with a revised date. If a change materially
          affects how we handle personal information, we will provide additional notice when
          reasonably appropriate.
        </p>
      </section>

      <section id="contact">
        <h2>13. Contact</h2>
        <p>
          Questions or privacy requests can be sent to Assist at{" "}
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
