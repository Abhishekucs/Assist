"use client";

import { PointerEvent, useRef, useState } from "react";

const cards = [
  { className: "annotated left-note", kind: "screen" },
  { className: "annotated", kind: "screen" },
  { className: "annotated tight-note", kind: "screen" },
  { className: "", kind: "text" },
  { className: "color-thumb", kind: "color" },
  { className: "note-thumb", kind: "note" },
  { className: "annotated", kind: "screen" }
];

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
          key={`${card.kind}-${index}`}
        >
          {card.kind === "screen" && (
            <div className={`mini-screen ${card.className}`}>
              <span className="mini-title">Context</span>
              <span className="mini-subtitle">captured.</span>
              <span className="mini-button" />
              <span className="mini-hill" />
            </div>
          )}
          {card.kind === "text" && (
            <div className="text-thumb">
              <span />
              <span />
              <span />
            </div>
          )}
          {card.kind === "color" && <div className="color-thumb" />}
          {card.kind === "note" && (
            <div className="note-thumb">
              <span />
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
