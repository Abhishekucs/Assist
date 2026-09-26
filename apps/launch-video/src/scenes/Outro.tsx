import { AbsoluteFill, Img, staticFile, useVideoConfig } from "remotion";

import { Words } from "../components/Words";
import { SPRING_POP, SPRING_SMOOTH, clamp01, mix, springAt, useSceneTime } from "../motion";
import { BODY, COLOR, FONT_FAMILY, HEADLINE } from "../theme";

/** Lockup, headline, and the website's "Download for Mac" call to action. */
export function Outro() {
  const t = useSceneTime("outro");
  const { fps } = useVideoConfig();

  const icon = springAt(t, 0, fps, SPRING_POP);
  const lift = springAt(t, 0.7, fps, { damping: 26, stiffness: 130, mass: 1 });
  const wordmark = springAt(t, 0.8, fps, { damping: 26, stiffness: 140, mass: 1 });
  const button = springAt(t, 2.0, fps, SPRING_POP);
  const url = springAt(t, 2.35, fps, SPRING_SMOOTH);
  const note = springAt(t, 2.6, fps, SPRING_SMOOTH);
  const settle = 1 + springAt(t, 2.0, fps, { damping: 200, stiffness: 20, mass: 1 }) * 0.02;

  const iconSize = 180;

  return (
    <AbsoluteFill style={{ transform: `scale(${settle})` }}>
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          transform: `translateY(${mix(0, -250, lift)}px)`
        }}
      >
        <div style={{ display: "flex", alignItems: "center" }}>
          <Img
            src={staticFile("brand/assist-icon.png")}
            style={{
              width: iconSize,
              height: iconSize,
              marginRight: -iconSize * 0.1 * wordmark,
              opacity: clamp01(icon * 1.5),
              transform: `scale(${mix(0.4, 1, icon)}) rotate(${(1 - icon) * -14}deg)`,
              filter: icon < 1 ? `blur(${(1 - clamp01(icon)) * 16}px)` : undefined
            }}
          />
          <div style={{ width: 350 * wordmark, overflow: "hidden" }}>
            <div
              style={{
                ...HEADLINE,
                fontSize: 124,
                whiteSpace: "nowrap",
                paddingLeft: 20,
                color: COLOR.ink,
                transform: `translateX(${(1 - wordmark) * -100}px)`,
                opacity: clamp01(wordmark * 1.4)
              }}
            >
              Assist
            </div>
          </div>
        </div>
      </AbsoluteFill>

      <Words
        lines={["One notch. Everyday tools."]}
        t={t}
        start={1.0}
        wordStarts={[1.0, 1.25, 1.5, 1.75]}
        style={{ ...HEADLINE, position: "absolute", top: 434, width: "100%", fontSize: 104, color: COLOR.ink, textAlign: "center" }}
      />

      <AbsoluteFill style={{ alignItems: "center" }}>
        <div
          style={{
            position: "absolute",
            top: 628,
            display: "inline-flex",
            alignItems: "center",
            gap: 18,
            height: 104,
            padding: "0 58px",
            borderRadius: 30,
            background: COLOR.ink,
            color: COLOR.paper,
            fontFamily: FONT_FAMILY,
            fontSize: 34,
            fontWeight: 500,
            boxShadow: "inset 0 2px 0 rgba(255, 255, 255, 0.14)",
            opacity: clamp01(button * 1.5),
            transform: `translateY(${(1 - button) * 40}px) scale(${mix(0.8, 1, button)})`
          }}
        >
          <Img src={staticFile("brands/apple.svg")} style={{ width: 34, height: 34, filter: "invert(1)", marginTop: -4 }} />
          Download for Mac
        </div>
        <div
          style={{
            ...BODY,
            position: "absolute",
            top: 772,
            fontSize: 44,
            fontWeight: 600,
            letterSpacing: "-0.02em",
            color: COLOR.ink,
            opacity: url,
            transform: `translateY(${(1 - url) * 20}px)`
          }}
        >
          assistapp.dev
        </div>
        <div
          style={{
            ...BODY,
            position: "absolute",
            top: 842,
            fontSize: 28,
            color: COLOR.inkFaint,
            opacity: note,
            transform: `translateY(${(1 - note) * 16}px)`
          }}
        >
          macOS 14+ · One-time purchase · No subscription
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
}
