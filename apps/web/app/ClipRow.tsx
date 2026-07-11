"use client";

import { PointerEvent, useRef, useState } from "react";

const cards = [
  { kind: "image", src: "/island-card-annotation.png" },
  { kind: "image", src: "/island-card-cta.png" },
  { kind: "image", src: "/island-card-assist.png" },
  { kind: "text" }
] as const;

export default function ClipRow() {
  const rowRef = useRef<HTMLDivElement>(null);
  const drag = useRef({
    active: false,
    pointerId: -1,
    startX: 0,
    scrollLeft: 0
  });
  const [isDragging, setIsDragging] = useState(false);

  function startDrag(event: PointerEvent<HTMLDivElement>) {
    if (!rowRef.current) return;

    drag.current = {
      active: true,
      pointerId: event.pointerId,
      startX: event.clientX,
      scrollLeft: rowRef.current.scrollLeft
    };
    rowRef.current.setPointerCapture(event.pointerId);
    setIsDragging(true);
  }

  function moveDrag(event: PointerEvent<HTMLDivElement>) {
    if (!drag.current.active || !rowRef.current) return;

    event.preventDefault();
    const distance = event.clientX - drag.current.startX;
    rowRef.current.scrollLeft = drag.current.scrollLeft - distance;
  }

  function endDrag(event: PointerEvent<HTMLDivElement>) {
    if (!drag.current.active) return;

    drag.current.active = false;
    setIsDragging(false);

    if (rowRef.current?.hasPointerCapture(event.pointerId)) {
      rowRef.current.releasePointerCapture(event.pointerId);
    }
  }

  return (
    <div
      ref={rowRef}
      className={`clip-row${isDragging ? " is-dragging" : ""}`}
      onPointerDown={startDrag}
      onPointerMove={moveDrag}
      onPointerUp={endDrag}
      onPointerCancel={endDrag}
      onPointerLeave={endDrag}
    >
      {cards.map((card, index) => (
        <article
          className={`clip-card${index === 0 ? " selected" : ""}${
            card.kind === "text" ? " text-clip" : ""
          }`}
          key={card.kind === "image" ? card.src : `${card.kind}-${index}`}
        >
          {card.kind === "image" && (
            <img className="clip-image" src={card.src} alt="" draggable={false} />
          )}
          {card.kind === "text" && (
            <div className="text-thumb">
              <span />
              <span />
              <span />
            </div>
          )}
        </article>
      ))}
    </div>
  );
}
