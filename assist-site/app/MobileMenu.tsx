"use client";

import { useState } from "react";

const menuItems = [
  { href: "#features", label: "Features" },
  { href: "#faq", label: "FAQ" },
  { href: "#pricing", label: "Pricing" },
];

export default function MobileMenu() {
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
        <span className="mobile-menu-icon" aria-hidden="true">
          <span />
          <span />
          <span />
        </span>
      </button>
      <div className="mobile-menu-panel" aria-hidden={!isOpen}>
        {menuItems.map((item) => (
          <a
            key={item.href}
            href={item.href}
            onClick={() => setIsOpen(false)}
          >
            {item.label}
          </a>
        ))}
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
