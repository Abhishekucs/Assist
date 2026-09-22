"use client";

import { useState } from "react";
import Image from "next/image";
import { CHECKOUT_HREF, PRODUCT_FEATURES, type SitePath } from "./productContent";

type MobileMenuProps = {
  activePath?: SitePath;
};

export default function MobileMenu({ activePath }: MobileMenuProps) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className={`mobile-menu${isOpen ? " is-open" : ""}`}>
      <button
        className="mobile-menu-button"
        type="button"
        aria-label={isOpen ? "Close navigation menu" : "Open navigation menu"}
        aria-expanded={isOpen}
        onClick={() => setIsOpen((open) => !open)}
      >
        <Image src={`/icons/${isOpen ? "cancel-01" : "menu-01"}.svg`} width={18} height={18} alt="" aria-hidden="true" />
      </button>
      <div className="mobile-menu-panel" aria-hidden={!isOpen}>
        <div className="mobile-feature-group">
          <span>Features</span>
          {PRODUCT_FEATURES.map((feature) => (
            <a
              key={feature.path}
              href={feature.path}
              aria-current={activePath === feature.path ? "page" : undefined}
              onClick={() => setIsOpen(false)}
            >
              {feature.navigationLabel}
            </a>
          ))}
        </div>
        <a href="/#pricing" onClick={() => setIsOpen(false)}>Pricing</a>
        <a
          href="/keyboard-sound-tester"
          aria-current={activePath === "/keyboard-sound-tester" ? "page" : undefined}
          onClick={() => setIsOpen(false)}
        >
          Fun mode
        </a>
        <a
          className="mobile-menu-download"
          href={CHECKOUT_HREF}
          onClick={() => setIsOpen(false)}
        >
          <span aria-hidden="true"></span>
          <span>Download</span>
        </a>
      </div>
    </div>
  );
}
