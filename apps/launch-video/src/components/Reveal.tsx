import type { ReactNode } from "react";
import { AbsoluteFill } from "remotion";

type CircleRevealProps = {
  /** 0 = hidden, 1 = covers the frame. */
  progress: number;
  background: string;
  children: ReactNode;
};

/** Reveals a scene through a circle growing from the center of the frame. */
export function CircleReveal({ progress, background, children }: CircleRevealProps) {
  if (progress <= 0) return null;
  // Half the 1920 x 1080 diagonal, so the circle clears every corner.
  const radius = progress * 1102;

  return (
    <AbsoluteFill style={{ background, clipPath: progress < 1 ? `circle(${radius}px at 50% 50%)` : undefined }}>
      {children}
    </AbsoluteFill>
  );
}
