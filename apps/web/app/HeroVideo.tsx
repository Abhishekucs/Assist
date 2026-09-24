"use client";

import Image from "next/image";
import { useRef, useState } from "react";

type HeroVideoProps = {
  src: string;
  poster: string;
};

export default function HeroVideo({ src, poster }: HeroVideoProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const playbackLabel = `${isPlaying ? "Pause" : "Play"} Assist demo`;

  const togglePlayback = async () => {
    const video = videoRef.current;
    if (!video) return;

    if (!video.paused) {
      video.pause();
      return;
    }

    try {
      await video.play();
    } catch {
      setIsPlaying(!video.paused);
    }
  };

  return (
    <div className={`hero-video-frame${isPlaying ? " is-playing" : ""}`}>
      <video
        ref={videoRef}
        id="hero-demo-video"
        className="hero-video"
        src={src}
        poster={poster}
        aria-label="Assist notch modules product walkthrough"
        aria-describedby="hero-video-description"
        playsInline
        preload="metadata"
        onPlay={() => setIsPlaying(true)}
        onPause={() => setIsPlaying(false)}
        onEnded={() => setIsPlaying(false)}
      >
        Your browser does not support video playback.
      </video>
      <button
        className="hero-video-play-button"
        type="button"
        aria-label={playbackLabel}
        aria-controls="hero-demo-video"
        title={playbackLabel}
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
