import { AbsoluteFill, OffthreadVideo, Sequence, staticFile, useVideoConfig } from "remotion";

import { Screen } from "../components/Screen";
import { Words } from "../components/Words";
import { EASE_IN, mix, ramp, sceneLead, springAt, useSceneTime } from "../motion";
import { COLOR, HEADLINE } from "../theme";

const LEAD = sceneLead("context");

// Cuts from the website's notch walkthrough (videos/notch-modules-demo.mp4).
const CLIPS = [
  { at: -LEAD, source: 1.0, length: 4.5 + LEAD, title: ["Your clipboard,", "in the notch."] },
  { at: 4.5, source: 18.7, length: 3.5, title: ["Timers that", "stay in sight."] }
] as const;

/** The real app in use: clipboard history, then focus timers. */
export function Context() {
  const t = useSceneTime("context");
  const { fps } = useVideoConfig();

  const rise = springAt(t, -LEAD, fps, { damping: 30, stiffness: 70, mass: 1.1 });
  const drift = ramp(t, 0.4, 7.0) * 0.045;
  const dive = ramp(t, 7.35, 0.65, EASE_IN);
  const screenWidth = 1320;

  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ perspective: 2200, alignItems: "center" }}>
        <div
          style={{
            position: "absolute",
            top: 232,
            transform: [
              `translateY(${(1 - rise) * 520}px)`,
              `rotateX(${(1 - rise) * 32}deg)`,
              `scale(${mix(0.84, 1, rise) + drift + dive * 2.2})`
            ].join(" "),
            transformOrigin: "50% 0%",
            opacity: 1 - ramp(t, 7.7, 0.3)
          }}
        >
          <Screen width={screenWidth} surface="light">
            {CLIPS.map((clip) => (
              <Sequence
                key={clip.source}
                from={Math.round((clip.at + LEAD) * fps)}
                durationInFrames={Math.round(clip.length * fps)}
                layout="none"
              >
                <OffthreadVideo
                  src={staticFile("videos/notch-modules-demo.mp4")}
                  trimBefore={Math.round(clip.source * fps)}
                  muted
                  style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
                />
              </Sequence>
            ))}
          </Screen>
        </div>
      </AbsoluteFill>

      {CLIPS.map((clip, index) => {
        const begin = Math.max(clip.at, 0) + 0.15;
        const next = CLIPS[index + 1];
        // Each title clears before the next one arrives with its cut.
        return (
          <Words
            key={clip.source}
            lines={[clip.title.join(" ")]}
            t={t}
            start={begin}
            stagger={0.07}
            exitAt={next ? next.at - 0.4 : 7.15}
            style={{
              ...HEADLINE,
              position: "absolute",
              top: 84,
              width: "100%",
              fontSize: 84,
              color: COLOR.ink,
              textAlign: "center"
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
}
