import type { ComponentType } from "react";
import { AbsoluteFill, Audio, Sequence, staticFile, useVideoConfig } from "remotion";

import "./components/fonts";
import { sceneLead, type SceneName } from "./motion";
import { Benefits } from "./scenes/Benefits";
import { Brand } from "./scenes/Brand";
import { Capture } from "./scenes/Capture";
import { Context } from "./scenes/Context";
import { Hook } from "./scenes/Hook";
import { Modules } from "./scenes/Modules";
import { Outro } from "./scenes/Outro";
import { Trusted } from "./scenes/Trusted";
import { Voice } from "./scenes/Voice";
import { COLOR } from "./theme";
import timeline from "./timeline.json";

// Later scenes draw above earlier ones; a scene's lead (timeline.json) starts
// it early so it can transition in over the one before it.
const SCENES: Array<{ name: SceneName; component: ComponentType }> = [
  { name: "hook", component: Hook },
  { name: "brand", component: Brand },
  { name: "context", component: Context },
  { name: "modules", component: Modules },
  { name: "capture", component: Capture },
  { name: "voice", component: Voice },
  { name: "benefits", component: Benefits },
  { name: "trusted", component: Trusted },
  { name: "outro", component: Outro }
];

export function LaunchVideo() {
  const { fps } = useVideoConfig();

  return (
    <AbsoluteFill style={{ background: COLOR.paper }}>
      {SCENES.map(({ name, component: Scene }) => {
        const { start, end } = timeline.scenes[name];
        const lead = sceneLead(name);
        return (
          <Sequence
            key={name}
            name={name}
            from={Math.round((start - lead) * fps)}
            durationInFrames={Math.round((end - start + lead) * fps)}
          >
            <Scene />
          </Sequence>
        );
      })}
      <Audio src={staticFile("audio/soundtrack.wav")} />
    </AbsoluteFill>
  );
}
