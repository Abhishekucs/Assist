import type { CSSProperties, ReactNode } from "react";

type ScreenProps = {
  width: number;
  children: ReactNode;
  /** Shadow tuned for the surface underneath. */
  surface: "light" | "dark";
  style?: CSSProperties;
};

/** A 16:9 recording of the Mac display with rounded corners and a soft shadow. */
export function Screen({ width, children, surface, style }: ScreenProps) {
  const height = (width * 9) / 16;
  const radius = width * 0.014;

  return (
    <div
      style={{
        position: "relative",
        width,
        height,
        borderRadius: radius,
        overflow: "hidden",
        background: "#000",
        boxShadow:
          surface === "light"
            ? "0 30px 80px rgba(0, 0, 0, 0.16), 0 8px 24px rgba(0, 0, 0, 0.08)"
            : "0 30px 90px rgba(0, 0, 0, 0.6), 0 0 0 1px rgba(255, 255, 255, 0.08)",
        ...style
      }}
    >
      {children}
    </div>
  );
}
