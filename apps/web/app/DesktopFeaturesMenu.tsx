"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";

import { PRODUCT_NAV_ITEMS, type SitePath } from "./siteNavigation";

type DesktopFeaturesMenuProps = {
  activePath?: SitePath;
};

export default function DesktopFeaturesMenu({ activePath }: DesktopFeaturesMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const hasActiveFeature = PRODUCT_NAV_ITEMS.some(
    (feature) => feature.path === activePath
  );

  useEffect(() => {
    if (!isOpen) {
      return;
    }

    const closeOnOutsidePointer = (event: PointerEvent) => {
      if (!menuRef.current?.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setIsOpen(false);
        triggerRef.current?.focus();
      }
    };

    document.addEventListener("pointerdown", closeOnOutsidePointer);
    document.addEventListener("keydown", closeOnEscape);

    return () => {
      document.removeEventListener("pointerdown", closeOnOutsidePointer);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, [isOpen]);

  return (
    <div
      ref={menuRef}
      className={`nav-feature-menu${hasActiveFeature ? " is-active" : ""}${isOpen ? " is-open" : ""}`}
    >
      <button
        ref={triggerRef}
        type="button"
        aria-controls="desktop-features-panel"
        aria-expanded={isOpen}
        onClick={() => setIsOpen((open) => !open)}
      >
        Features
      </button>
      <div
        id="desktop-features-panel"
        className="nav-feature-menu-panel"
        aria-hidden={!isOpen}
      >
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
    </div>
  );
}
