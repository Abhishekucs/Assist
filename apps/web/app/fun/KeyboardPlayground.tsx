"use client";

import { useEffect, useRef, useState, type CSSProperties, type KeyboardEvent } from "react";
import catalog from "./catalog.json";
import { KeyboardAudio } from "./KeyboardAudio";
import { keyboardKeys, keyboardRows, keyColors, type DemoKey } from "./keyboard";
import TypingTest, { type TypingTestHandle } from "./TypingTest";
import styles from "./playground.module.css";

export default function KeyboardPlayground() {
  const [pack, setPack] = useState("thock");
  const [designId, setDesignId] = useState("mint");
  const [sound, setSound] = useState(true);
  const [volume, setVolume] = useState(0.35);
  const [status, setStatus] = useState<"off" | "loading" | "ready" | "error">("off");
  const [pressed, setPressed] = useState<Set<string>>(() => new Set());
  const audio = useRef<KeyboardAudio | null>(null);
  const held = useRef(new Map<string, number>());
  const variation = useRef(0);
  const typingTest = useRef<TypingTestHandle>(null);
  const live = useRef(false);
  const design = catalog.designs.find(item => item.id === designId)!;
  const selectedSound = catalog.sounds.find(item => item.id === pack)!;

  useEffect(() => {
    live.current = true;
    const player = new KeyboardAudio();
    audio.current = player;
    const pause = () => {
      held.current.clear();
      setPressed(new Set());
      typingTest.current?.pause();
      setStatus("off");
      void player.pause()?.catch(() => { if (live.current) setStatus("error"); });
    };
    const visibility = () => { if (document.hidden) pause(); };
    window.addEventListener("blur", pause);
    document.addEventListener("visibilitychange", visibility);
    return () => {
      live.current = false;
      window.removeEventListener("blur", pause);
      document.removeEventListener("visibilitychange", visibility);
      void player.dispose()?.catch(() => {});
      audio.current = null;
    };
  }, []);

  async function activate(nextPack = pack) {
    setStatus("loading");
    try {
      const ready = await audio.current?.activate(nextPack);
      if (!ready || !live.current) return;
      setStatus("ready");
    } catch {
      if (live.current) setStatus("error");
    }
  }

  function activateOnInput() {
    if (!sound) return;
    if (status === "off" || status === "error") void activate();
    else void audio.current?.resumeOnGesture()?.catch(() => {
      if (live.current) setStatus("error");
    });
  }

  function clearKeys() {
    held.current.clear();
    setPressed(new Set());
    audio.current?.silence();
  }

  function press(key: DemoKey) {
    if (held.current.has(key.code)) return;
    const index = variation.current++ % 3;
    held.current.set(key.code, index);
    setPressed(new Set(held.current.keys()));
    if (sound) audio.current?.play(key.code, "down", index, key.pan);
  }

  function release(key: DemoKey) {
    const index = held.current.get(key.code);
    if (index === undefined) return;
    held.current.delete(key.code);
    setPressed(new Set(held.current.keys()));
    if (sound) audio.current?.play(key.code, "up", index, key.pan);
  }

  function keyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.repeat || event.nativeEvent.isComposing || event.metaKey || event.ctrlKey) return;
    const key = keyboardKeys.get(event.code);
    if (key) press(key);
  }

  function changePack(value: string) {
    if (!catalog.sounds.some(item => item.id === value)) return;
    setPack(value);
    clearKeys();
    typingTest.current?.pause();
    if (sound) void activate(value);
  }

  function toggleSound() {
    clearKeys();
    setSound(!sound);
    if (!sound) void activate();
    else {
      setStatus("off");
      void audio.current?.pause()?.catch(() => setStatus("error"));
    }
  }

  return (
    <section className={styles.playground} aria-labelledby="keyboard-sound-tester-title">
      <div className={styles.heading}>
        <h1 id="keyboard-sound-tester-title">Keystrokes that sound better.</h1>
      </div>

      <div className={styles.controls}>
        <label className={styles.choice}>
          <span>Sound pack</span>
          <select value={pack} onChange={event => changePack(event.target.value)}>
            {catalog.sounds.map(item => <option key={item.id} value={item.id}>{item.title}</option>)}
          </select>
        </label>
        <label className={styles.choice}>
          <span>Keyboard design</span>
          <select value={designId} onChange={event => { setDesignId(event.target.value); typingTest.current?.pause(); }}>
            {catalog.designs.map(item => <option key={item.id} value={item.id}>{item.title}</option>)}
          </select>
        </label>
        <button className={styles.soundToggle} type="button" aria-pressed={sound} onClick={toggleSound}>
          Sound {sound ? "on" : "off"}
        </button>
        <label className={styles.volume}>
          <span>Volume</span>
          <input type="range" min="0" max="1" step="0.01" value={volume} onChange={event => {
            const value = Number(event.target.value);
            setVolume(value);
            audio.current?.setVolume(value);
          }} />
        </label>
      </div>

      <TypingTest ref={typingTest} onActivity={activateOnInput} onKeyDown={keyDown}
        onKeyUp={event => { const key = keyboardKeys.get(event.code); if (key) release(key); }} onBlur={clearKeys} />

      <div className={styles.keyboard} data-design={designId} aria-label={`${design.title} keyboard, US layout`}>
        {keyboardRows.map((row, index) => <div className={styles.row} key={index}>
          {row.map(key => {
            const { fill, ink } = keyColors(design, key.macCode);
            return <button type="button" key={key.code} tabIndex={-1}
              className={`${styles.key} ${pressed.has(key.code) ? styles.pressed : ""}`}
              aria-label={`${key.label} key`} aria-pressed={pressed.has(key.code)} data-key={key.code}
              style={{ "--units": key.units, "--key-fill": fill, "--key-ink": ink } as CSSProperties}
              onPointerDown={event => {
                event.preventDefault();
                if (event.button !== 0) return;
                event.currentTarget.setPointerCapture(event.pointerId);
                activateOnInput();
                press(key);
                typingTest.current?.tap(key);
              }}
              onPointerUp={() => { activateOnInput(); release(key); }} onPointerCancel={() => release(key)}
              onLostPointerCapture={() => release(key)}>{key.label}</button>;
          })}
        </div>)}
      </div>

      <div className={styles.details}>
        <span>{selectedSound.detail}</span>
        <span role="status">{status === "loading" ? "Loading sound…" : status === "error" ? <>
          Sound couldn’t load. <button type="button" onClick={() => void activate()}>Retry sound</button>
        </> : ""}</span>
      </div>
      <div className={styles.getAssist}>
        <p>Bring this feeling to every app on your Mac.</p>
        <a className="hero-download-button" href="/api/checkout">Get Assist for Mac</a>
        <a href="/" className={styles.back}>Back to Assist</a>
      </div>
    </section>
  );
}
