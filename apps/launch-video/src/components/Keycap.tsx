import { COLOR, FONT_FAMILY } from "../theme";

type KeycapProps = {
  symbol: string;
  label: string;
  /** Height in px; the app's keycap is 28 pt tall with a 6 pt radius. */
  height: number;
  /** 0 = resting, 1 = fully pressed. */
  pressed: number;
  opacity?: number;
};

/** The app's AssistKeycap in dark appearance, scaled up for video. */
export function Keycap({ symbol, label, height, pressed, opacity = 1 }: KeycapProps) {
  const unit = height / 28;

  return (
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 7 * unit,
        height,
        padding: `0 ${14 * unit}px`,
        borderRadius: 6 * unit,
        background: COLOR.accentSurfaceDark,
        color: COLOR.accentDark,
        fontFamily: FONT_FAMILY,
        fontSize: 13 * unit,
        fontWeight: 500,
        letterSpacing: "-0.01em",
        opacity,
        transform: `translateY(${pressed * 2.5 * unit}px) scale(${1 - pressed * 0.04})`,
        filter: `brightness(${1 + pressed * 0.35})`
      }}
    >
      <span style={{ fontSize: 15 * unit }}>{symbol}</span>
      <span>{label}</span>
    </div>
  );
}
