import { Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import type { SpringConfig } from "remotion";

import timeline from "./timeline.json";

export const EASE_OUT = Easing.bezier(0.16, 1, 0.3, 1);
export const EASE_IN = Easing.bezier(0.7, 0, 0.84, 0);
export const EASE_IN_OUT = Easing.bezier(0.65, 0, 0.35, 1);

// Tuned to the app's own motion: SwiftUI springs around response 0.3,
// damping 0.8 (see AssistDesignTokens.Motion).
export const SPRING_SNAPPY: Partial<SpringConfig> = { damping: 20, stiffness: 190, mass: 0.9 };
export const SPRING_POP: Partial<SpringConfig> = { damping: 13, stiffness: 160, mass: 0.9 };
export const SPRING_SMOOTH: Partial<SpringConfig> = { damping: 200, stiffness: 90, mass: 1 };

export type SceneName = keyof typeof timeline.scenes;

/** How early a scene starts so it can transition in over the previous one. */
export function sceneLead(scene: SceneName): number {
  const entry = timeline.scenes[scene];
  return "lead" in entry ? entry.lead : 0;
}

/**
 * Seconds since the named scene's nominal start (negative during its lead-in).
 * Call inside the scene's own Sequence, which starts `lead` seconds early.
 */
export function useSceneTime(scene: SceneName): number {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return frame / fps - sceneLead(scene);
}

/** 0 → 1 over `duration` seconds from `start`, clamped, eased. */
export function ramp(t: number, start: number, duration: number, easing = EASE_OUT): number {
  if (duration <= 0) return t >= start ? 1 : 0;
  return interpolate(t, [start, start + duration], [0, 1], {
    easing,
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp"
  });
}

/** A spring that starts at `start` seconds; 0 before it. */
export function springAt(
  t: number,
  start: number,
  fps: number,
  config: Partial<SpringConfig> = SPRING_SNAPPY
): number {
  const frame = (t - start) * fps;
  if (frame <= 0) return 0;
  return spring({ frame, fps, config });
}

export function mix(from: number, to: number, amount: number): number {
  return from + (to - from) * amount;
}

export function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}
