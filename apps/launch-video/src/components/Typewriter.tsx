import type { CSSProperties } from "react";

type TypewriterProps = {
  text: string;
  t: number;
  start: number;
  /** Characters per second; matches the keystroke timing in the soundtrack. */
  cps: number;
  caretColor: string;
  /** Show the caret from this time (defaults to just before typing starts). */
  caretFrom?: number;
  /** Hide the caret after this time. */
  caretUntil?: number;
  style?: CSSProperties;
};

/** Types `text` one character at a time with a text caret. */
export function Typewriter({ text, t, start, cps, caretColor, caretFrom, caretUntil, style }: TypewriterProps) {
  const typed = Math.max(0, Math.min(text.length, Math.floor((t - start) * cps) + 1));
  const visible = t >= start ? text.slice(0, typed) : "";
  const typing = t >= start && typed < text.length;
  const blinkOn = Math.floor((t - start) * 2.2) % 2 === 0;
  const showCaret = t >= (caretFrom ?? start - 0.4) && (caretUntil === undefined || t < caretUntil) && (typing || blinkOn);

  return (
    <div style={{ display: "inline-flex", alignItems: "center", whiteSpace: "pre", ...style }}>
      <span>{visible}</span>
      <span
        style={{
          display: "inline-block",
          width: "0.06em",
          height: "0.92em",
          marginLeft: "0.04em",
          borderRadius: "0.03em",
          background: caretColor,
          opacity: showCaret ? 1 : 0
        }}
      />
    </div>
  );
}
