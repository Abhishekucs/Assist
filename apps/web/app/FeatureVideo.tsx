"use client";

import { useEffect, useRef, useState } from "react";

type FeatureVideoProps = {
  src: string;
};

export default function FeatureVideo({ src }: FeatureVideoProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [shouldLoad, setShouldLoad] = useState(false);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    if (!("IntersectionObserver" in window)) {
      setShouldLoad(true);
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;

        setShouldLoad(true);
        observer.disconnect();
      },
      { rootMargin: "420px 0px" }
    );

    observer.observe(video);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!shouldLoad) return;

    const playPromise = videoRef.current?.play();
    void playPromise?.catch(() => {});
  }, [shouldLoad]);

  return (
    <video
      ref={videoRef}
      className="feature-video"
      src={shouldLoad ? src : undefined}
      autoPlay={shouldLoad}
      muted
      loop
      playsInline
      preload="none"
    />
  );
}
