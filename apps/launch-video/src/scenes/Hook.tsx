import { AbsoluteFill, Img, staticFile, useVideoConfig } from "remotion";

import { Typewriter } from "../components/Typewriter";
import { EASE_IN, SPRING_POP, mix, ramp, springAt, useSceneTime } from "../motion";
import { COLOR, HEADLINE, MODULE_IMAGE } from "../theme";
import timeline from "../timeline.json";

const [line1, line2] = timeline.typing;
const NOTCH = { width: 250, height: 40, radius: 20 };

/** "Your Mac has a notch." The notch then opens into the Assist island. */
export function Hook() {
  const t = useSceneTime("hook");
  const { fps, width } = useVideoConfig();

  const line1Done = line1.start + line1.text.length / line1.cps;
  const pulse = springAt(t, line1Done, fps, SPRING_POP) - springAt(t, line1Done + 0.18, fps, SPRING_POP);

  // The notch grows into the island at the first downbeat after the copy.
  const open = springAt(t, 4.0, fps, { damping: 24, stiffness: 120, mass: 1 });
  const notchWidth = mix(NOTCH.width, MODULE_IMAGE.width, open) * (1 + pulse * 0.08);
  const notchHeight = mix(NOTCH.height, MODULE_IMAGE.height, open) * (1 + pulse * 0.1);
  const notchRadius = mix(NOTCH.radius, 40, open);
  const content = ramp(t, 4.45, 0.45);
  const retract = ramp(t, 5.55, 0.45, EASE_IN);
  const pushIn = 1 + ramp(t, 4.6, 1.4) * 0.035;

  const line1Exit = ramp(t, 2.3, 0.35, EASE_IN);
  const line2Exit = ramp(t, 4.0, 0.35, EASE_IN);

  return (
    <AbsoluteFill>
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          width,
          height: MODULE_IMAGE.height,
          transform: `translateY(${-retract * 110}%) scale(${pushIn})`,
          transformOrigin: "50% 0%"
        }}
      >
        <div
          style={{
            position: "absolute",
            top: 0,
            left: (width - notchWidth) / 2,
            width: notchWidth,
            height: notchHeight,
            background: COLOR.notch,
            borderBottomLeftRadius: notchRadius,
            borderBottomRightRadius: notchRadius
          }}
        />
        <Img
          src={staticFile("modules/clipboard.png")}
          style={{
            position: "absolute",
            top: 0,
            left: (width - MODULE_IMAGE.width) / 2,
            width: MODULE_IMAGE.width,
            height: MODULE_IMAGE.height,
            opacity: content,
            filter: content < 1 ? `blur(${(1 - content) * 8}px)` : undefined
          }}
        />
      </div>

      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", paddingTop: 60 }}>
        <div
          style={{
            position: "absolute",
            opacity: 1 - line1Exit,
            transform: `translateY(${-line1Exit * 70}px)`,
            filter: line1Exit > 0 ? `blur(${line1Exit * 10}px)` : undefined
          }}
        >
          <Typewriter
            text={line1.text}
            t={t}
            start={line1.start}
            cps={line1.cps}
            caretColor={COLOR.ink}
            caretUntil={2.3}
            style={{ ...HEADLINE, fontSize: 104, color: COLOR.ink }}
          />
        </div>
        <div
          style={{
            position: "absolute",
            opacity: 1 - line2Exit,
            transform: `translateY(${line2Exit * 90}px)`,
            filter: line2Exit > 0 ? `blur(${line2Exit * 10}px)` : undefined
          }}
        >
          <Typewriter
            text={line2.text}
            t={t}
            start={line2.start}
            cps={line2.cps}
            caretColor={COLOR.ink}
            caretFrom={2.3}
            style={{ ...HEADLINE, fontSize: 104, color: COLOR.ink }}
          />
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
}
