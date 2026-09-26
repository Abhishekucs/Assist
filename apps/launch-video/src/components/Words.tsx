import type { CSSProperties } from "react";
import { useVideoConfig } from "remotion";

import { SPRING_SNAPPY, clamp01, ramp, springAt, EASE_IN } from "../motion";
import type { SpringConfig } from "remotion";

type WordsProps = {
  /** One entry per line. */
  lines: string[];
  /** Scene time in seconds. */
  t: number;
  /** When the first word starts. */
  start: number;
  /** Delay between consecutive words, in seconds. */
  stagger?: number;
  /** Explicit start times per word (overrides `stagger`), flattened across lines. */
  wordStarts?: number[];
  /** When the words leave, if they do. */
  exitAt?: number;
  exitStagger?: number;
  config?: Partial<SpringConfig>;
  style?: CSSProperties;
  lineStyle?: CSSProperties;
  /** Per-word color overrides, keyed by flattened word index. */
  colors?: Record<number, string>;
};

/** Word-by-word reveal: each word rises, sharpens, and settles on a spring. */
export function Words({
  lines,
  t,
  start,
  stagger = 0.08,
  wordStarts,
  exitAt,
  exitStagger = 0.03,
  config = SPRING_SNAPPY,
  style,
  lineStyle,
  colors
}: WordsProps) {
  const { fps } = useVideoConfig();
  let index = 0;

  return (
    <div style={style}>
      {lines.map((line, lineIndex) => (
        <div key={lineIndex} style={{ display: "block", whiteSpace: "nowrap", ...lineStyle }}>
          {line.split(" ").map((word, wordIndex, words) => {
            const i = index++;
            const begin = wordStarts?.[i] ?? start + i * stagger;
            const enter = springAt(t, begin, fps, config);
            const leave = exitAt === undefined ? 0 : ramp(t, exitAt + i * exitStagger, 0.35, EASE_IN);
            const opacity = clamp01(enter * 1.6) * (1 - leave);
            const y = (1 - enter) * 0.42 - leave * 0.3;
            const blur = (1 - clamp01(enter)) * 14 + leave * 10;
            const scale = 0.92 + 0.08 * enter;

            return (
              <span key={wordIndex} style={{ display: "inline-block", whiteSpace: "pre" }}>
                <span
                  style={{
                    display: "inline-block",
                    opacity,
                    color: colors?.[i],
                    transform: `translateY(${y}em) scale(${scale})`,
                    transformOrigin: "50% 80%",
                    filter: blur > 0.05 ? `blur(${blur}px)` : undefined
                  }}
                >
                  {word}
                </span>
                {wordIndex < words.length - 1 ? " " : ""}
              </span>
            );
          })}
        </div>
      ))}
    </div>
  );
}
