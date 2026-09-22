import Image from "next/image";
import Link from "next/link";
import DesktopFeaturesMenu from "./DesktopFeaturesMenu";
import MobileMenu from "./MobileMenu";
import { CHECKOUT_HREF, type SitePath } from "./siteNavigation";

type SiteHeaderProps = {
  activePath?: SitePath;
};

export default function SiteHeader({ activePath }: SiteHeaderProps) {
  const isHome = activePath === "/";

  return (
    <header className="site-header" aria-label="Site header">
      <nav className="header-pill" aria-label="Primary navigation">
        <Link className="brand" href={isHome ? "#top" : "/"} aria-label="Assist home">
          <span className="brand-mark"><Image src="/assist-icon.png" alt="" width={30} height={30} /></span>
          <span>Assist</span>
        </Link>
        <div className="nav-links">
          <DesktopFeaturesMenu activePath={activePath} />
          <Link href="/#pricing">Pricing</Link>
          <Link
            href="/keyboard-sound-tester"
            aria-current={activePath === "/keyboard-sound-tester" ? "page" : undefined}
          >
            Fun mode
          </Link>
        </div>
        <a className="download-button" href={CHECKOUT_HREF} aria-label="Download Assist">
          <span aria-hidden="true"></span><span>Download</span>
        </a>
        <MobileMenu activePath={activePath} />
      </nav>
    </header>
  );
}
