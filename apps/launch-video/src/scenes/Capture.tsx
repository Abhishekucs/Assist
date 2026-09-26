import { AbsoluteFill, OffthreadVideo, Sequence, staticFile, useVideoConfig } from "remotion";

import { Icon } from "../components/Icon";
import { Keycap } from "../components/Keycap";
import { CircleReveal } from "../components/Reveal";
import { Screen } from "../components/Screen";
import { Words } from "../components/Words";
import type { HugeiconName } from "../generated/hugeicons";
import { sceneLead, EASE_IN, EASE_IN_OUT, SPRING_POP, SPRING_SMOOTH, clamp01, mix, ramp, springAt, useSceneTime } from "../motion";
import { BODY, COLOR, HEADLINE } from "../theme";
import timeline from "../timeline.json";

const LEAD = sceneLead("capture");
const scene = timeline.scenes.capture;
const [controlDown, optionDown] = timeline.keyPresses.map((time) => time - scene.start);
const FLASH = optionDown + 0.25;

// Cuts from the website's screenshot editor recording.
const TOOLS: Array<{ name: string; icon: HugeiconName; description: string; at: number; source: number }> = [
  { name: "Crop", icon: "crop", description: "Freely, or to a fixed ratio.", at: 1.5, source: 8.0 },
  { name: "Blur", icon: "blur", description: "Three brush sizes for private details.", at: 3.5, source: 12.5 },
  { name: "Frame", icon: "paint-board", description: "Padding, corners, shadow, backdrop.", at: 5.5, source: 16.8 }
];

/** Control + Option captures the display; the quick editor crops, blurs, frames. */
export function Capture() {
  const t = useSceneTime("capture");
  const { fps } = useVideoConfig();

  const reveal = ramp(t, -LEAD, 0.55, EASE_IN_OUT);
  const keysOut = ramp(t, FLASH + 0.05, 0.3, EASE_IN);
  const flash = t >= FLASH ? 1 - ramp(t, FLASH, 0.45) : 0;
  const screenIn = springAt(t, 1.4, fps, { damping: 28, stiffness: 110, mass: 1 });
  const active = TOOLS.reduce((current, tool, index) => (t >= tool.at ? index : current), 0);

  const press = (at: number) => springAt(t, at, fps, { damping: 18, stiffness: 400, mass: 0.6 });

  return (
    <CircleReveal progress={reveal} background={COLOR.notch}>
      {/* Beat 1: the shortcut. */}
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          opacity: 1 - keysOut,
          transform: `scale(${1 - keysOut * 0.08})`,
          filter: keysOut > 0 ? `blur(${keysOut * 12}px)` : undefined
        }}
      >
        <Words
          lines={["Capture."]}
          t={t}
          start={0}
          style={{ ...HEADLINE, fontSize: 150, color: COLOR.onNotch, marginBottom: 90 }}
        />
        <div style={{ display: "flex", alignItems: "center", gap: 44 }}>
          {[
            { symbol: "⌃", label: "control", at: 0.05, down: controlDown },
            { symbol: "⌥", label: "option", at: 0.18, down: optionDown }
          ].map((key, index) => {
            const enter = springAt(t, key.at, fps, SPRING_POP);
            return (
              <div key={key.label} style={{ display: "flex", alignItems: "center", gap: 44 }}>
                {index > 0 ? (
                  <span style={{ ...BODY, fontSize: 64, color: COLOR.onNotchMuted, opacity: clamp01(enter) }}>+</span>
                ) : null}
                <div style={{ transform: `translateY(${(1 - enter) * 60}px) scale(${mix(0.7, 1, enter)})`, opacity: clamp01(enter * 1.5) }}>
                  <Keycap symbol={key.symbol} label={key.label} height={132} pressed={press(key.down)} />
                </div>
              </div>
            );
          })}
        </div>
      </AbsoluteFill>

      {/* Beat 2: the quick editor. */}
      <AbsoluteFill>
        <div style={{ position: "absolute", left: 120, top: 236, width: 520 }}>
          <Words
            lines={["Capture.", "Edit."]}
            t={t}
            start={1.5}
            wordStarts={[1.5, 1.65]}
            style={{ ...HEADLINE, fontSize: 118, color: COLOR.onNotch }}
          />
          <div style={{ marginTop: 70, display: "flex", flexDirection: "column", gap: 34 }}>
            {TOOLS.map((tool, index) => {
              const enter = springAt(t, 1.75 + index * 0.08, fps, SPRING_SMOOTH);
              const on = index === active ? ramp(t, tool.at, 0.2) : index === active - 1 ? 1 - ramp(t, TOOLS[active].at, 0.2) : 0;
              return (
                <div
                  key={tool.name}
                  style={{
                    opacity: clamp01(enter) * mix(0.34, 1, on),
                    transform: `translateX(${(1 - enter) * -40 + on * 10}px)`
                  }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
                    <Icon name={tool.icon} size={48} color={COLOR.onNotch} />
                    <span style={{ ...HEADLINE, fontSize: 50, letterSpacing: "-0.03em", color: COLOR.onNotch }}>{tool.name}</span>
                  </div>
                  <div style={{ ...BODY, fontSize: 26, marginTop: 6, marginLeft: 66, color: COLOR.onNotchMuted }}>
                    {tool.description}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <AbsoluteFill style={{ perspective: 2000 }}>
          <div
            style={{
              position: "absolute",
              left: 700,
              top: 223,
              opacity: clamp01(screenIn * 1.4),
              transform: `translateX(${(1 - screenIn) * 260}px) rotateY(${(1 - screenIn) * -18}deg) scale(${1 + ramp(t, 1.6, 6.4) * 0.03})`,
              transformOrigin: "100% 50%"
            }}
          >
            <Screen width={1100} surface="dark">
              {TOOLS.map((tool, index) => {
                const until = TOOLS[index + 1]?.at ?? 8.0;
                return (
                  <Sequence
                    key={tool.name}
                    from={Math.round((tool.at + LEAD) * fps)}
                    durationInFrames={Math.round((until - tool.at) * fps)}
                    layout="none"
                  >
                    <OffthreadVideo
                      src={staticFile("videos/screenshot-editor.mp4")}
                      trimBefore={Math.round(tool.source * fps)}
                      muted
                      style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
                    />
                  </Sequence>
                );
              })}
            </Screen>
          </div>
        </AbsoluteFill>
      </AbsoluteFill>

      {/* The capture flash. */}
      <AbsoluteFill style={{ background: COLOR.onNotch, opacity: flash * 0.85, pointerEvents: "none" }} />
    </CircleReveal>
  );
}
