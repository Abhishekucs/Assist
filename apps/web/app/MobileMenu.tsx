"use client";

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";

import {
  CHECKOUT_HREF,
  PRODUCT_NAV_ITEMS,
  type SitePath
} from "./siteNavigation";

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
          {PRODUCT_NAV_ITEMS.map((feature) => (
            <Link
              key={feature.path}
              href={feature.path}
              aria-current={activePath === feature.path ? "page" : undefined}
              onClick={() => setIsOpen(false)}
            >
              {feature.label}
            </Link>
          ))}
        </div>
        <Link href="/#pricing" onClick={() => setIsOpen(false)}>Pricing</Link>
        <Link
          href="/keyboard-sound-tester"
          aria-current={activePath === "/keyboard-sound-tester" ? "page" : undefined}
          onClick={() => setIsOpen(false)}
        >
          Fun mode
        </Link>
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
