export const CHECKOUT_HREF = "/api/checkout";

export type ProductFeaturePath =
  | "/screenshots"
  | "/voice-annotation"
  | "/clipboard";

export type SitePath =
  | "/"
  | ProductFeaturePath
  | "/modules"
  | "/keyboard-sound-tester";

export const PRODUCT_NAV_ITEMS = [
  { path: "/screenshots", label: "Screenshots" },
  { path: "/voice-annotation", label: "Voice annotate" },
  { path: "/clipboard", label: "Clipboard" },
  { path: "/modules", label: "Modules" }
] as const satisfies ReadonlyArray<{
  path: SitePath;
  label: string;
}>;
