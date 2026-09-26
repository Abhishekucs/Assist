import { AbsoluteFill, OffthreadVideo, Sequence, random, staticFile, useVideoConfig } from "remotion";

import { Screen } from "../components/Screen";
import { Words } from "../components/Words";
import { EASE_IN, SPRING_POP, SPRING_SMOOTH, clamp01, mix, ramp, springAt, useSceneTime } from "../motion";
import { BODY, COLOR, HEADLINE } from "../theme";

const WORDS = [
  { text: "Point.", at: 0 },
  { text: "Speak.", at: 0.5 },
  { text: "Done.", at: 1.0 }
];
const DOCK = 1.45;
const CLIP = { at: 1.5, source: 0.8 };

/** Hold Option, draw and talk; Assist keeps the transcript with the capture. */
export function Voice() {
  const t = useSceneTime("voice");
  const { fps } = useVideoConfig();

  const screenIn = springAt(t, 1.5, fps, { damping: 28, stiffness: 100, mass: 1 });
  const chips = springAt(t, 2.2, fps, SPRING_SMOOTH);
  const exit = ramp(t, 5.55, 0.45, EASE_IN);

  return (
    <AbsoluteFill style={{ background: COLOR.notch }}>
      {/* One word per beat, centered, then the full line docks above the clip. */}
      {WORDS.map((word, index) => {
        const next = WORDS[index + 1]?.at ?? DOCK;
        if (t < word.at || t >= next) return null;
        const hit = springAt(t, word.at, fps, SPRING_POP);
        return (
          <AbsoluteFill key={word.text} style={{ alignItems: "center", justifyContent: "center" }}>
            <span
              style={{
                ...HEADLINE,
                fontSize: 240,
                color: COLOR.onNotch,
                opacity: clamp01(hit * 2),
                transform: `scale(${mix(1.45, 1, clamp01(hit))})`,
                filter: hit < 1 ? `blur(${(1 - clamp01(hit)) * 22}px)` : undefined
              }}
            >
              {word.text}
            </span>
          </AbsoluteFill>
        );
      })}
      <Words
        lines={[WORDS.map((word) => word.text).join(" ")]}
        t={t}
        start={DOCK}
        stagger={0.06}
        exitAt={5.55}
        style={{ ...HEADLINE, position: "absolute", top: 96, width: "100%", fontSize: 92, color: COLOR.onNotch, textAlign: "center" }}
      />

      <AbsoluteFill style={{ perspective: 2200, alignItems: "center" }}>
        <div
          style={{
            position: "absolute",
            top: 250,
            opacity: clamp01(screenIn * 1.4) * (1 - exit),
            transform: `translateY(${(1 - screenIn) * 420 + exit * -30}px) rotateX(${(1 - screenIn) * 26}deg) scale(${1 + ramp(t, 1.6, 4.4) * 0.03})`,
            transformOrigin: "50% 0%"
          }}
        >
          <Screen width={1260} surface="dark">
            <Sequence from={Math.round(CLIP.at * fps)} layout="none">
              <OffthreadVideo
                src={staticFile("videos/voice-annotation.mp4")}
                trimBefore={Math.round(CLIP.source * fps)}
                muted
                style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
              />
            </Sequence>
          </Screen>

          {/* The recording shows the held Option key; add the local transcript. */}
          <div
            style={{
              position: "absolute",
              right: -60,
              bottom: 64,
              display: "flex",
              alignItems: "center",
              gap: 22,
              height: 96,
              padding: "0 34px",
              borderRadius: 14,
              background: COLOR.darkCard,
              boxShadow: "0 20px 60px rgba(0, 0, 0, 0.5)",
              opacity: clamp01(chips * 1.4),
              transform: `translateY(${(1 - chips) * 40}px)`
            }}
          >
            <Waveform t={t} active={t > 2.4 && t < 5.2} />
            <span style={{ ...BODY, fontSize: 32, fontWeight: 500, color: COLOR.onNotch }}>Local transcript</span>
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
}

function Waveform({ t, active }: { t: number; active: boolean }) {
  const bars = 11;
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 6, height: 48 }}>
      {Array.from({ length: bars }, (_, index) => {
        const step = Math.floor(t * 14);
        const level = active ? 0.25 + 0.75 * random(`bar-${index}-${step}`) * Math.sin(((index + 1) / (bars + 1)) * Math.PI) : 0.12;
        return (
          <span
            key={index}
            style={{ width: 6, height: 8 + level * 40, borderRadius: 3, background: COLOR.accentDark }}
          />
        );
      })}
    </div>
  );
}
