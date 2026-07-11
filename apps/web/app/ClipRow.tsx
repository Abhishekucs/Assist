"use client";

import Image from "next/image";
import { PointerEvent, useRef, useState } from "react";

const cards = [
  {
    kind: "image",
    src: "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/4B4E873B-AFDE-4DC3-999F-B1B8EFEFFE81-thumb.png"
  },
  {
    kind: "image",
    src: "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/4B4E873B-AFDE-4DC3-999F-B1B8EFEFFE81.png"
  },
  {
    kind: "image",
    src: "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/6E28B0F5-206C-440B-ADF9-FA69E583F9FD-thumb.png"
  },
  {
    kind: "image",
    src: "https://m94bitnxyzpsrcu1.public.blob.vercel-storage.com/HeroIsland/6E28B0F5-206C-440B-ADF9-FA69E583F9FD.png"
  }
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
          className={`clip-card${index === 0 ? " selected" : ""}`}
          key={card.src}
        >
          <Image
            className="clip-image"
            src={card.src}
            alt=""
            width={142}
            height={142}
            sizes="(max-width: 640px) 112px, 142px"
            draggable={false}
          />
        </article>
      ))}
    </div>
  );
}
