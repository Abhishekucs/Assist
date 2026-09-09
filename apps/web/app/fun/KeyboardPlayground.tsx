"use client";

import { useEffect, useRef, useState, type CSSProperties, type KeyboardEvent } from "react";
import catalog from "./catalog.json";
import { KeyboardAudio } from "./KeyboardAudio";
import { keyboardKeys, keyboardRows, keyColors, type DemoKey } from "./keyboard";
import styles from "./playground.module.css";

export default function KeyboardPlayground() {
  const [pack, setPack] = useState("thock");
  const [designId, setDesignId] = useState("mint");
  const [sound, setSound] = useState(true);
  const [volume, setVolume] = useState(0.35);
  const [started, setStarted] = useState(false);
  const [status, setStatus] = useState<"off" | "loading" | "ready" | "error">("off");
  const [text, setText] = useState("");
  const [pressed, setPressed] = useState<Set<string>>(() => new Set());
  const [hits, setHits] = useState(0);
  const audio = useRef<KeyboardAudio | null>(null);
  const held = useRef(new Map<string, number>());
  const variation = useRef(0);
  const textarea = useRef<HTMLTextAreaElement>(null);
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

  async function activate(nextPack = pack, focus = false) {
    setStarted(true);
    setStatus("loading");
    try {
      const ready = await audio.current?.activate(nextPack);
      if (!ready || !live.current) return;
      setStatus("ready");
      if (focus && !window.matchMedia("(pointer: coarse)").matches) textarea.current?.focus();
    } catch {
      if (live.current) setStatus("error");
    }
  }

  function clearKeys() {
    held.current.clear();
    setPressed(new Set());
    audio.current?.silence();
  }

  function press(key: DemoKey) {
    if (!started || (sound && status !== "ready") || held.current.has(key.code)) return;
    const index = variation.current++ % 3;
    held.current.set(key.code, index);
    setPressed(new Set(held.current.keys()));
    setHits(value => value + 1);
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
    if (started && sound) void activate(value);
  }

  function toggleSound() {
    clearKeys();
    setSound(!sound);
    if (!sound && started) void activate();
    else {
      setStatus("off");
      void audio.current?.pause()?.catch(() => setStatus("error"));
    }
  }

  function start() {
    if (sound) void activate(pack, true);
    else { setStarted(true); textarea.current?.focus(); }
  }

  function tapText(key: DemoKey) {
    setText(value => {
      if (key.code === "Backspace" || key.code === "Delete") return Array.from(value).slice(0, -1).join("");
      const letter = key.code === "Space" ? " " : key.code === "Enter" ? "\n" : key.code === "Minus" ? "-" : key.label.length === 1 && !key.code.startsWith("Arrow") && !key.code.startsWith("Meta") ? key.label.toLowerCase() : "";
      return (value + letter).slice(0, 5000);
    });
  }

  return (
    <section className={styles.playground} aria-labelledby="fun-title">
      <div className={styles.heading}>
        <h1 id="fun-title">Make a little noise.</h1>
        <p>Find your sound. Pick your colors. Enjoy every keystroke.</p>
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
          <select value={designId} onChange={event => setDesignId(event.target.value)}>
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

      <div className={styles.pad}>
        <textarea ref={textarea} aria-label="Typing playground" value={text} maxLength={5000}
          placeholder={started ? "Type anything. This space is yours." : "A little thock. A little click. A lot of fun."}
          readOnly={!started || (sound && status !== "ready")} spellCheck={false} autoComplete="off" autoCorrect="off" autoCapitalize="off"
          onChange={event => setText(event.target.value)}
          onFocus={() => { if (started && sound && status === "off") void activate(); }}
          onBlur={clearKeys} onKeyDown={keyDown}
          onKeyUp={event => { const key = keyboardKeys.get(event.code); if (key) release(key); }} />
        {(!started || (sound && status !== "ready")) && <div className={styles.startRow}>
          <button type="button" className={styles.start} disabled={status === "loading"} onClick={start}>
            {status === "loading" ? "Loading sound…" : status === "error" ? "Retry sound" : started ? "Resume sound" : "Start typing"}
          </button>
          <span role="status">{status === "error" ? "That sound couldn’t load. Try again, or turn sound off." : "Try your keyboard or tap the keys below."}</span>
        </div>}
      </div>

      <div className={styles.keyboard} data-design={designId} aria-label={`${design.title} keyboard, US layout`}>
        {keyboardRows.map((row, index) => <div className={styles.row} key={index}>
          {row.map(key => {
            const { fill, ink } = keyColors(design, key.macCode);
            return <button type="button" key={key.code} tabIndex={-1} disabled={!started || (sound && status !== "ready")}
              className={`${styles.key} ${pressed.has(key.code) ? styles.pressed : ""}`}
              aria-label={`${key.label} key`} aria-pressed={pressed.has(key.code)} data-key={key.code}
              style={{ "--units": key.units, "--key-fill": fill, "--key-ink": ink } as CSSProperties}
              onPointerDown={event => {
                event.preventDefault();
                if (event.button !== 0) return;
                event.currentTarget.setPointerCapture(event.pointerId);
                if (sound && status === "off") void activate();
                press(key);
                tapText(key);
              }}
              onPointerUp={() => release(key)} onPointerCancel={() => release(key)}
              onLostPointerCapture={() => release(key)}>{key.label}</button>;
          })}
        </div>)}
      </div>

      <div className={styles.details}>
        <span>{selectedSound.detail}</span>
        <span>{hits} {hits === 1 ? "keystroke" : "keystrokes"}</span>
        <button type="button" onClick={() => { setText(""); setHits(0); clearKeys(); textarea.current?.focus(); }}>Clear typing</button>
      </div>
      <p className={styles.privacy}>Just for you. Your typing isn’t saved or sent anywhere.</p>
      <div className={styles.getAssist}>
        <p>Bring this feeling to every app on your Mac.</p>
        <a className="hero-download-button" href="/api/checkout">Get Assist for Mac</a>
        <a href="/" className={styles.back}>Back to Assist</a>
      </div>
      <p className={styles.credits}>Sounds from <a href="/keyboard-sounds/README.md">kbsim, with source credits</a>. Keyboard colors inspired by <a href="https://getkeeby.com/" target="_blank" rel="noreferrer">Keeby</a>.</p>
    </section>
  );
}
