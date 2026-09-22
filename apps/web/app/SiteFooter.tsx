import Image from "next/image";
import Link from "next/link";

import { CHECKOUT_HREF, PRODUCT_NAV_ITEMS } from "./siteNavigation";

type SiteFooterProps = {
  showCallToAction?: boolean;
};

export default function SiteFooter({ showCallToAction = true }: SiteFooterProps) {
  return (
    <footer className="site-footer">
      {showCallToAction ? (
        <div className="footer-cta">
          <Image
            className="footer-cta-icon"
            src="/assist-icon.png"
            alt=""
            width={72}
            height={72}
          />
          <h2>Keep every capture one gesture away.</h2>
          <p>
            Screenshots, voice annotation, and clipboard history, built for your Mac.
          </p>
          <a className="footer-cta-button" href={CHECKOUT_HREF}>
            <span aria-hidden="true"></span>
            <span>Get Assist for Mac</span>
          </a>
        </div>
      ) : null}

      <div className="footer-links-wrap">
        <div className="footer-brand-block">
          <Link className="footer-brand" href="/" aria-label="Assist home">
            <span className="brand-mark">
              <Image src="/assist-icon.png" alt="" width={30} height={30} />
            </span>
            <span>Assist</span>
          </Link>
          <p>
            Screenshots, voice annotation, and clipboard history, right from your Mac notch.
          </p>
        </div>

        <nav className="footer-link-grid" aria-label="Footer navigation">
          <div>
            <h3>Product</h3>
            {PRODUCT_NAV_ITEMS.map((feature) => (
              <Link key={feature.path} href={feature.path}>
                {feature.label}
              </Link>
            ))}
            <Link href="/keyboard-sound-tester">Fun mode</Link>
          </div>
          <div>
            <h3>Buy</h3>
            <Link href="/#pricing">Pricing</Link>
            <Link href="/#faq">FAQ</Link>
            <a href={CHECKOUT_HREF}>Download</a>
          </div>
          <div>
            <h3>Company</h3>
            <a href="mailto:abhishek@thinkingsoundlab.com">Contact</a>
          </div>
          <div>
            <h3>Legal</h3>
            <Link href="/privacy">Privacy policy</Link>
            <Link href="/terms">Terms of use</Link>
          </div>
        </nav>
      </div>

      <div className="footer-bottom">
        <p>© 2026 Assist. All rights reserved.</p>
        <Link href="#top">Back to top</Link>
      </div>
    </footer>
  );
}
