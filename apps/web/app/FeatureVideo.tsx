"use client";

import { useEffect, useRef, useState } from "react";

type FeatureVideoProps = {
  src: string;
};

export default function FeatureVideo({ src }: FeatureVideoProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const isInViewportRef = useRef(false);
  const [shouldLoad, setShouldLoad] = useState(false);
  const [shouldPlay, setShouldPlay] = useState(false);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    const reducedMotionQuery = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    );
    const syncPlaybackState = () => {
      setShouldPlay(isInViewportRef.current && !reducedMotionQuery.matches);
    };

    if (!("IntersectionObserver" in window)) {
      isInViewportRef.current = true;
      setShouldLoad(true);
      syncPlaybackState();
      reducedMotionQuery.addEventListener("change", syncPlaybackState);

      return () => {
        reducedMotionQuery.removeEventListener("change", syncPlaybackState);
        isInViewportRef.current = false;
        video.pause();
      };
    }

    const loadObserver = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;

        setShouldLoad(true);
        loadObserver.disconnect();
      },
      { rootMargin: "420px 0px" }
    );
    const playbackObserver = new IntersectionObserver(
      ([entry]) => {
        isInViewportRef.current =
          entry.isIntersecting && entry.intersectionRatio >= 0.2;
        syncPlaybackState();
      },
      { threshold: [0, 0.2] }
    );

    loadObserver.observe(video);
    playbackObserver.observe(video);
    reducedMotionQuery.addEventListener("change", syncPlaybackState);

    return () => {
      loadObserver.disconnect();
      playbackObserver.disconnect();
      reducedMotionQuery.removeEventListener("change", syncPlaybackState);
      isInViewportRef.current = false;
      video.pause();
    };
  }, []);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    if (!shouldLoad || !shouldPlay) {
      video.pause();
      return;
    }

    const playPromise = video.play();
    void playPromise?.catch(() => {});
  }, [shouldLoad, shouldPlay]);

  return (
    <video
      ref={videoRef}
      className="feature-video"
      src={shouldLoad ? src : undefined}
      muted
      loop
      playsInline
      preload={shouldLoad ? "metadata" : "none"}
    />
  );
}
