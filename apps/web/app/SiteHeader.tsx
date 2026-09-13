import Image from "next/image";
import MobileMenu from "./MobileMenu";

export default function SiteHeader({ funMode = false }: { funMode?: boolean }) {
  const prefix = funMode ? "/" : "";
  return (
    <header className="site-header" aria-label="Site header">
      <nav className="header-pill" aria-label="Primary navigation">
        <a className="brand" href={funMode ? "/" : "#top"} aria-label="Assist home">
          <span className="brand-mark"><Image src="/assist-icon.png" alt="" width={30} height={30} /></span>
          <span>Assist</span>
        </a>
        <div className="nav-links">
          <a href={`${prefix}#features`}>Features</a>
          <a href={`${prefix}#faq`}>FAQ</a>
          <a href={`${prefix}#pricing`}>Pricing</a>
          <a href="/keyboard-sound-tester" aria-current={funMode ? "page" : undefined}>Fun mode</a>
        </div>
        <a className="download-button" href="/api/checkout" aria-label="Download Assist">
          <span aria-hidden="true"></span><span>Download</span>
        </a>
        <MobileMenu sectionPrefix={prefix} />
      </nav>
    </header>
  );
}
