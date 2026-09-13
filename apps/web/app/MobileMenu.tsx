"use client";

import { useState } from "react";
import Image from "next/image";

const menuItems = [
  { hash: "#features", label: "Features" },
  { hash: "#faq", label: "FAQ" },
  { hash: "#pricing", label: "Pricing" },
];

type MobileMenuProps = {
  sectionPrefix?: string;
};

export default function MobileMenu({ sectionPrefix = "" }: MobileMenuProps) {
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
        {menuItems.map((item) => (
          <a
            key={item.hash}
            href={`${sectionPrefix}${item.hash}`}
            onClick={() => setIsOpen(false)}
          >
            {item.label}
          </a>
        ))}
        <a href="/keyboard-sound-tester" onClick={() => setIsOpen(false)}>Fun mode</a>
        <a
          className="mobile-menu-download"
          href="/api/checkout"
          onClick={() => setIsOpen(false)}
        >
          <span aria-hidden="true"></span>
          <span>Download</span>
        </a>
      </div>
    </div>
  );
}
