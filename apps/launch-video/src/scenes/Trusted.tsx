import { AbsoluteFill, Img, staticFile, useVideoConfig } from "remotion";

import { EASE_IN, SPRING_SMOOTH, clamp01, ramp, springAt, useSceneTime } from "../motion";
import { BODY, COLOR } from "../theme";

// The website's "Trusted by people at" row, with its bundled Simple Icons marks.
const COMPANIES: Array<{ name: string; logo?: string }> = [
  { name: "Apple", logo: "apple" },
  { name: "Microsoft", logo: "microsoft" },
  { name: "Meta", logo: "meta" },
  { name: "Amazon", logo: "amazon" },
  { name: "TikTok", logo: "tiktok" },
  { name: "(character.ai)" },
  { name: "Mistral AI", logo: "mistral-ai" },
  { name: "DoorDash", logo: "doordash" }
];

export function Trusted() {
  const t = useSceneTime("trusted");
  const { fps } = useVideoConfig();

  const label = springAt(t, 0.05, fps, SPRING_SMOOTH);
  const exit = ramp(t, 2.6, 0.4, EASE_IN);

  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        opacity: 1 - exit,
        filter: exit > 0 ? `blur(${exit * 10}px)` : undefined
      }}
    >
      <div
        style={{
          ...BODY,
          fontSize: 38,
          fontWeight: 500,
          color: COLOR.inkFaint,
          opacity: label,
          transform: `translateY(${(1 - label) * 20}px)`
        }}
      >
        Trusted by people at
      </div>
      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          justifyContent: "center",
          columnGap: 64,
          rowGap: 40,
          width: 1500,
          marginTop: 56
        }}
      >
        {COMPANIES.map((company, index) => {
          const enter = springAt(t, 0.25 + index * 0.07, fps, SPRING_SMOOTH);
          return (
            <div
              key={company.name}
              style={{
                ...BODY,
                display: "flex",
                alignItems: "center",
                gap: 16,
                fontSize: 46,
                fontWeight: 600,
                letterSpacing: "-0.03em",
                color: COLOR.ink,
                opacity: clamp01(enter * 1.3),
                transform: `translateY(${(1 - enter) * 40}px)`,
                filter: enter < 1 ? `blur(${(1 - clamp01(enter)) * 8}px)` : undefined
              }}
            >
              {company.logo ? (
                <Img src={staticFile(`brands/${company.logo}.svg`)} style={{ width: 44, height: 44 }} />
              ) : null}
              {company.name}
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
}
