import { AbsoluteFill, Img, staticFile, useVideoConfig } from "remotion";

import { Words } from "../components/Words";
import { EASE_IN, SPRING_POP, SPRING_SMOOTH, clamp01, mix, ramp, springAt, useSceneTime } from "../motion";
import { BODY, COLOR, HEADLINE } from "../theme";

/** Icon, wordmark, and the website's headline: "One notch. Everyday tools." */
export function Brand() {
  const t = useSceneTime("brand");
  const { fps } = useVideoConfig();

  const iconIn = springAt(t, 0, fps, SPRING_POP);
  const split = springAt(t, 0.85, fps, { damping: 26, stiffness: 140, mass: 1 });
  const lift = springAt(t, 2.0, fps, SPRING_SMOOTH);
  const exit = ramp(t, 5.15, 0.55, EASE_IN);
  const sub = springAt(t, 3.6, fps, SPRING_SMOOTH);

  const iconSize = 260;
  const wordmarkWidth = 500;

  return (
    <AbsoluteFill
      style={{
        opacity: 1 - exit,
        transform: `scale(${1 + exit * 0.14})`,
        filter: exit > 0 ? `blur(${exit * 18}px)` : undefined
      }}
    >
      {/* Lockup: icon, then the wordmark slides out from behind it. */}
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          transform: `translateY(${mix(0, -300, lift)}px) scale(${mix(1, 0.5, lift)})`
        }}
      >
        <div style={{ display: "flex", alignItems: "center" }}>
          <Img
            src={staticFile("brand/assist-icon.png")}
            style={{
              width: iconSize,
              height: iconSize,
              // The icon art carries macOS canvas padding; pull the wordmark in.
              marginRight: -iconSize * 0.1 * split,
              opacity: clamp01(iconIn * 1.5),
              transform: `scale(${mix(0.4, 1, iconIn)}) rotate(${(1 - iconIn) * -14}deg)`,
              filter: iconIn < 1 ? `blur(${(1 - clamp01(iconIn)) * 16}px)` : undefined
            }}
          />
          <div style={{ width: wordmarkWidth * split, overflow: "hidden" }}>
            <div
              style={{
                ...HEADLINE,
                fontSize: 176,
                whiteSpace: "nowrap",
                paddingLeft: 28,
                color: COLOR.ink,
                transform: `translateX(${(1 - split) * -140}px)`,
                opacity: clamp01(split * 1.4)
              }}
            >
              Assist
            </div>
          </div>
        </div>
      </AbsoluteFill>

      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", paddingTop: 70 }}>
        <Words
          lines={["One notch.", "Everyday tools."]}
          t={t}
          start={2.0}
          wordStarts={[2.0, 2.25, 2.5, 2.75]}
          style={{ ...HEADLINE, fontSize: 150, color: COLOR.ink, textAlign: "center" }}
        />
        <div
          style={{
            ...BODY,
            marginTop: 44,
            maxWidth: 1000,
            fontSize: 38,
            color: COLOR.inkMuted,
            textAlign: "center",
            opacity: sub,
            transform: `translateY(${(1 - sub) * 24}px)`
          }}
        >
          Clipboard, files, notes, focus timers, and more—right where you need them.
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
}
