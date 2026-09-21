import Image from "next/image";
import MobileMenu from "./MobileMenu";
import { CHECKOUT_HREF, PRODUCT_FEATURES, type SitePath } from "./productContent";

type SiteHeaderProps = {
  activePath?: SitePath;
};

export default function SiteHeader({ activePath }: SiteHeaderProps) {
  const isHome = activePath === "/";

  return (
    <header className="site-header" aria-label="Site header">
      <nav className="header-pill" aria-label="Primary navigation">
        <a className="brand" href={isHome ? "#top" : "/"} aria-label="Assist home">
          <span className="brand-mark"><Image src="/assist-icon.png" alt="" width={30} height={30} /></span>
          <span>Assist</span>
        </a>
        <div className="nav-links">
          {PRODUCT_FEATURES.map((feature) => (
            <a
              key={feature.path}
              href={feature.path}
              aria-current={activePath === feature.path ? "page" : undefined}
            >
              {feature.navigationLabel}
            </a>
          ))}
          <a href="/#pricing">Pricing</a>
          <a
            href="/keyboard-sound-tester"
            aria-current={activePath === "/keyboard-sound-tester" ? "page" : undefined}
          >
            Fun mode
          </a>
        </div>
        <a className="download-button" href={CHECKOUT_HREF} aria-label="Download Assist">
          <span aria-hidden="true"></span><span>Download</span>
        </a>
        <MobileMenu activePath={activePath} />
      </nav>
    </header>
  );
}
