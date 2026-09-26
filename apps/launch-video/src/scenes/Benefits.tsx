import { AbsoluteFill, useVideoConfig } from "remotion";

import { Icon } from "../components/Icon";
import { CircleReveal } from "../components/Reveal";
import { Words } from "../components/Words";
import type { HugeiconName } from "../generated/hugeicons";
import { sceneLead, EASE_IN, EASE_IN_OUT, SPRING_SNAPPY, clamp01, ramp, springAt, useSceneTime } from "../motion";
import { BODY, COLOR, HEADLINE } from "../theme";

const LEAD = sceneLead("benefits");

// Facts from the website's hero note, FAQ, and pricing section.
const CARDS: Array<{ icon: HugeiconName; title: string; body: string }> = [
  { icon: "desktop", title: "Native to macOS", body: "Built for macOS 14 and later. Apple silicon for voice." },
  { icon: "storage", title: "Local-first", body: "Screenshots, clips, and transcripts stay on your Mac." },
  { icon: "key", title: "Pay once", body: "One Mac, one purchase. No subscription." }
];

export function Benefits() {
  const t = useSceneTime("benefits");
  const { fps } = useVideoConfig();

  const reveal = ramp(t, -LEAD, 0.55, EASE_IN_OUT);

  return (
    <CircleReveal progress={reveal} background={COLOR.paper}>
      <AbsoluteFill style={{ alignItems: "center" }}>
        <Words
          lines={["Native. Local. Yours."]}
          t={t}
          start={0}
          wordStarts={[0.05, 0.5, 1.0]}
          exitAt={5.45}
          style={{ ...HEADLINE, position: "absolute", top: 196, fontSize: 140, color: COLOR.ink }}
        />
        <div style={{ position: "absolute", top: 470, display: "flex", gap: 32 }}>
          {CARDS.map((card, index) => {
            const enter = springAt(t, 1.35 + index * 0.12, fps, SPRING_SNAPPY);
            const leave = ramp(t, 5.45 + index * 0.04, 0.35, EASE_IN);
            return (
              <div
                key={card.title}
                style={{
                  width: 520,
                  height: 330,
                  padding: "46px 44px",
                  borderRadius: 28,
                  background: COLOR.hover,
                  opacity: clamp01(enter * 1.5) * (1 - leave),
                  transform: `translateY(${(1 - enter) * 90 - leave * 40}px)`,
                  filter: leave > 0 ? `blur(${leave * 10}px)` : undefined
                }}
              >
                <Icon name={card.icon} size={64} color={COLOR.ink} />
                <div style={{ ...HEADLINE, fontSize: 50, letterSpacing: "-0.035em", marginTop: 38, color: COLOR.ink }}>
                  {card.title}
                </div>
                <div style={{ ...BODY, fontSize: 30, marginTop: 16, color: COLOR.inkMuted }}>{card.body}</div>
              </div>
            );
          })}
        </div>
      </AbsoluteFill>
    </CircleReveal>
  );
}
