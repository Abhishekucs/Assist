// Visual tokens for the launch video. Every value is taken from the shipping
// product: the website (apps/web/app/globals.css) for the light surfaces and
// type, and the macOS app (AssistDesignTokens.swift) for the notch, keycaps,
// dark surfaces, and island tints. See docs/design/macos-design-language.md.

export const VIDEO = {
  width: 1920,
  height: 1080,
  fps: 60
} as const;

export const COLOR = {
  // Website
  paper: "#ffffff",
  ink: "#050505",
  inkMuted: "rgba(0, 0, 0, 0.6)",
  inkFaint: "rgba(0, 0, 0, 0.42)",
  hover: "#f5f5f5",
  // The notch keeps its black silhouette.
  notch: "#000000",
  onNotch: "#ffffff",
  onNotchMuted: "rgba(255, 255, 255, 0.68)",
  // macOS app, dark appearance
  darkCard: "#25252B",
  darkControl: "#2D2D33",
  accentDark: "#B6A9FF",
  accentSurfaceDark: "#353047",
  // macOS app, light appearance
  card: "#F8F8FA",
  accent: "#5142B8",
  accentSurface: "#EEEBFA",
  // Island card tints
  sage: "#98B3A3",
  lavender: "#A7A1BD",
  mustard: "#B2AC75",
  dustyBlue: "#96AEBF"
} as const;

export const FONT_FAMILY = "Inter Assist, Inter, system-ui, sans-serif";

// Website headline treatment (.hero-title): weight 600, -0.055em, 0.92 leading.
export const HEADLINE = {
  fontFamily: FONT_FAMILY,
  fontWeight: 600,
  letterSpacing: "-0.055em",
  lineHeight: 0.92
} as const;

export const BODY = {
  fontFamily: FONT_FAMILY,
  fontWeight: 400,
  letterSpacing: "-0.01em",
  lineHeight: 1.45
} as const;

// Module renders are 2x captures of the 666 x 234 pt island.
export const MODULE_IMAGE = { width: 1332, height: 468 } as const;
