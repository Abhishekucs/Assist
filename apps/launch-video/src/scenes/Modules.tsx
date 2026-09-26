import { AbsoluteFill, Img, staticFile, useVideoConfig } from "remotion";

import { Icon } from "../components/Icon";
import { Words } from "../components/Words";
import type { HugeiconName } from "../generated/hugeicons";
import { EASE_IN, SPRING_POP, SPRING_SMOOTH, SPRING_SNAPPY, clamp01, ramp, springAt, useSceneTime } from "../motion";
import { BODY, COLOR, HEADLINE, MODULE_IMAGE } from "../theme";
import timeline from "../timeline.json";

type Module = { image: string; name: string; icon: HugeiconName; description: string };

// Names and descriptions from the website (apps/web/app/moduleContent.ts),
// in the island's tab order. Clipboard opened the video, so the carousel
// starts at Shelf.
const CAROUSEL: Module[] = [
  { image: "shelf", name: "Shelf", icon: "shelf", description: "Drop files on the notch, drag them into any app." },
  { image: "notes", name: "Notes", icon: "notes", description: "A scratchpad that saves every edit." },
  { image: "timers", name: "Focus", icon: "timer", description: "Pomodoro, countdown, stopwatch, and hydration." },
  { image: "calendar", name: "Calendar", icon: "calendar", description: "Seven days of events and your reminders." },
  { image: "media", name: "Media", icon: "music", description: "Music and Spotify controls in the notch." },
  { image: "stats", name: "System", icon: "stats", description: "CPU, memory, disk, network, and battery." },
  { image: "screenTime", name: "Screen Time", icon: "hourglass", description: "Today’s app usage, tracked locally." },
  { image: "converter", name: "Convert", icon: "convert", description: "Drop images, get JPEG, PNG, HEIC, or PDF." },
  { image: "revenue", name: "Revenue", icon: "revenue", description: "Stripe, Polar, or Dodo sales at a glance." },
  { image: "aiUsage", name: "AI Usage", icon: "ai-usage", description: "Claude Code and Codex token activity." }
];

const ALL_MODULES: Array<{ name: string; icon: HugeiconName }> = [
  { name: "Clipboard", icon: "clipboard" },
  ...CAROUSEL.map(({ name, icon }) => ({ name, icon }))
];

const scene = timeline.scenes.modules;
const CAROUSEL_START = timeline.moduleCarousel.start - scene.start;
const STEP = timeline.moduleCarousel.step;
const CAROUSEL_END = CAROUSEL_START + CAROUSEL.length * STEP;
const LEFT = (1920 - MODULE_IMAGE.width) / 2;

/** "Make the notch yours." Then every module, one beat pair each. */
export function Modules() {
  const t = useSceneTime("modules");
  const { fps } = useVideoConfig();

  const drop = springAt(t, CAROUSEL_START - 0.25, fps, { damping: 26, stiffness: 150, mass: 1 });
  const retract = ramp(t, CAROUSEL_END, 0.4, EASE_IN);
  const active = Math.min(CAROUSEL.length - 1, Math.max(0, Math.floor((t - CAROUSEL_START) / STEP)));
  const switchedAt = CAROUSEL_START + active * STEP;
  const swap = active === 0 ? 1 : ramp(t, switchedAt, 0.12);
  const bump = active === 0 ? 0 : springAt(t, switchedAt, fps, SPRING_POP) - springAt(t, switchedAt + 0.08, fps, SPRING_POP);
  const labelsOut = ramp(t, CAROUSEL_END - 0.05, 0.35, EASE_IN);

  return (
    <AbsoluteFill>
      <Words
        lines={["Make the notch yours."]}
        t={t}
        start={0}
        wordStarts={[0, 0.25, 0.5, 0.75]}
        exitAt={1.5}
        style={{ ...HEADLINE, position: "absolute", top: 452, width: "100%", fontSize: 150, color: COLOR.ink, textAlign: "center" }}
      />

      {/* The island, hanging from the top edge like the real notch. */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: LEFT,
          width: MODULE_IMAGE.width,
          height: MODULE_IMAGE.height,
          transform: `translateY(${(-(1 - drop) - retract) * 105}%) scale(${1 + bump * 0.012})`,
          transformOrigin: "50% 0%"
        }}
      >
        {CAROUSEL.map((module, index) => {
          const visible = index === active ? swap : index === active - 1 ? 1 : 0;
          return visible > 0 ? (
            <Img
              key={module.image}
              src={staticFile(`modules/${module.image}.png`)}
              style={{ position: "absolute", inset: 0, width: "100%", height: "100%", opacity: visible }}
            />
          ) : null;
        })}
      </div>

      {/* Module label: name rolls up on every switch. */}
      <div
        style={{
          position: "absolute",
          top: 640,
          left: LEFT,
          width: MODULE_IMAGE.width,
          height: 300,
          opacity: 1 - labelsOut,
          transform: `translateY(${-labelsOut * 40}px)`
        }}
      >
        {CAROUSEL.map((module, index) => {
          const enterAt = CAROUSEL_START + index * STEP;
          // The outgoing label clears quickly; the next one rises in just behind it.
          const enter = springAt(t, index === 0 ? enterAt : enterAt + 0.07, fps, SPRING_SNAPPY);
          const leave = index < CAROUSEL.length - 1 ? ramp(t, enterAt + STEP, 0.14, EASE_IN) : 0;
          if (enter <= 0 || leave >= 1) return null;
          const y = (1 - enter) * 90 - leave * 50;
          const opacity = clamp01(enter * 1.4) * (1 - leave);
          const blur = (1 - clamp01(enter)) * 10 + leave * 8;

          return (
            <div
              key={module.name}
              style={{
                position: "absolute",
                inset: 0,
                opacity,
                transform: `translateY(${y}px)`,
                filter: blur > 0.05 ? `blur(${blur}px)` : undefined
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 30 }}>
                <Icon name={module.icon} size={96} color={COLOR.ink} />
                <div style={{ ...HEADLINE, fontSize: 124, color: COLOR.ink }}>{module.name}</div>
              </div>
              <div style={{ ...BODY, marginTop: 26, fontSize: 40, color: COLOR.inkMuted }}>{module.description}</div>
              <div
                style={{
                  ...BODY,
                  position: "absolute",
                  right: 0,
                  top: 34,
                  fontSize: 44,
                  fontWeight: 500,
                  color: COLOR.inkFaint,
                  fontVariantNumeric: "tabular-nums"
                }}
              >
                {String(index + 2).padStart(2, "0")} / {String(ALL_MODULES.length).padStart(2, "0")}
              </div>
            </div>
          );
        })}
      </div>

      <ModuleGrid t={t - CAROUSEL_END} fps={fps} />
    </AbsoluteFill>
  );
}

function ModuleGrid({ t, fps }: { t: number; fps: number }) {
  if (t < 0) return null;
  const size = 88;
  const column = 150;

  return (
    <AbsoluteFill style={{ alignItems: "center" }}>
      <Words
        lines={["Eleven modules. One notch."]}
        t={t}
        start={0.25}
        wordStarts={[0.25, 0.5, 0.75, 1.0]}
        style={{ ...HEADLINE, position: "absolute", top: 282, width: "100%", fontSize: 110, color: COLOR.ink, textAlign: "center" }}
      />
      <div style={{ position: "absolute", top: 520, display: "flex" }}>
        {ALL_MODULES.map((module, index) => {
          const pop = springAt(t, 0.6 + index * 0.05, fps, SPRING_POP);
          const settle = springAt(t, 0.6 + index * 0.05, fps, SPRING_SMOOTH);
          return (
            <div
              key={module.name}
              style={{
                width: column,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 22,
                opacity: clamp01(pop * 1.5),
                transform: `translateY(${(1 - settle) * 70}px) scale(${0.6 + 0.4 * pop})`
              }}
            >
              <Icon name={module.icon} size={size} color={COLOR.ink} />
              <div style={{ ...BODY, fontSize: 25, fontWeight: 500, color: COLOR.inkMuted, whiteSpace: "nowrap" }}>
                {module.name}
              </div>
            </div>
          );
        })}
      </div>
      <div
        style={{
          ...BODY,
          position: "absolute",
          top: 760,
          fontSize: 38,
          color: COLOR.inkMuted,
          opacity: springAt(t, 1.5, fps, SPRING_SMOOTH),
          transform: `translateY(${(1 - springAt(t, 1.5, fps, SPRING_SMOOTH)) * 24}px)`
        }}
      >
        Enable the ones that fit your day.
      </div>
    </AbsoluteFill>
  );
}
