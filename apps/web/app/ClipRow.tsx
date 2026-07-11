"use client";

import { PointerEvent, useRef, useState } from "react";

const cards = [
  {
    kind: "image",
    fullSrc: "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/4B4E873B-AFDE-4DC3-999F-B1B8EFEFFE81.png",
    thumbSrc: "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/4B4E873B-AFDE-4DC3-999F-B1B8EFEFFE81-thumb.png"
  },
  {
    kind: "image",
    fullSrc: "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/6E28B0F5-206C-440B-ADF9-FA69E583F9FD.png",
    thumbSrc: "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/6E28B0F5-206C-440B-ADF9-FA69E583F9FD-thumb.png"
  },
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
          key={card.kind === "image" ? card.thumbSrc : `${card.kind}-${index}`}
        >
          {card.kind === "image" && (
            <img
              className="clip-image"
              src={card.thumbSrc}
              srcSet={`${card.thumbSrc} 640w, ${card.fullSrc} 3840w`}
              sizes="(max-width: 640px) 112px, 142px"
              alt=""
              draggable={false}
            />
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
