"use client";

import Image from "next/image";
import { useRef, useState } from "react";

type HeroVideoProps = {
  src: string;
};

export default function HeroVideo({ src }: HeroVideoProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);

  const togglePlayback = async () => {
    const video = videoRef.current;
    if (!video) return;

    if (!video.paused) {
      video.pause();
      return;
    }

    try {
      video.muted = false;
      await video.play();
    } catch {
      setIsPlaying(false);
    }
  };

  return (
    <div className={`hero-video-frame${isPlaying ? " is-playing" : ""}`}>
      <video
        ref={videoRef}
        className="hero-video"
        src={src}
        aria-label="Assist for Mac workflow demonstration"
        loop
        playsInline
        preload="metadata"
        onPlay={() => setIsPlaying(true)}
        onPause={() => setIsPlaying(false)}
      />
      <button
        className="hero-video-play-button"
        type="button"
        aria-label={`${isPlaying ? "Pause" : "Play"} Assist demo`}
        onClick={() => void togglePlayback()}
      >
        <Image
          className={`hero-video-play-icon${isPlaying ? " is-pause" : ""}`}
          src={`/icons/${isPlaying ? "pause" : "play"}.svg`}
          alt=""
          width={34}
          height={34}
          aria-hidden="true"
        />
      </button>
    </div>
  );
}
