import { Composition } from "remotion";

import { LaunchVideo } from "./LaunchVideo";
import { VIDEO } from "./theme";
import timeline from "./timeline.json";

export function Root() {
  return (
    <Composition
      id="AssistLaunch"
      component={LaunchVideo}
      width={VIDEO.width}
      height={VIDEO.height}
      fps={VIDEO.fps}
      durationInFrames={timeline.duration * VIDEO.fps}
    />
  );
}
