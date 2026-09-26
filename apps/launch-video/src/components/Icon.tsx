import type { CSSProperties } from "react";

import { HUGEICONS, type HugeiconName } from "../generated/hugeicons";

type IconProps = {
  name: HugeiconName;
  size: number;
  color: string;
  style?: CSSProperties;
};

/** A bundled Hugeicons Stroke Rounded glyph, drawn in `color`. */
export function Icon({ name, size, color, style }: IconProps) {
  const svg = HUGEICONS[name].replace('width="24" height="24"', `width="${size}" height="${size}"`);

  return (
    <span
      aria-hidden
      style={{ display: "inline-flex", width: size, height: size, flex: "none", color, ...style }}
      dangerouslySetInnerHTML={{ __html: svg }}
    />
  );
}
