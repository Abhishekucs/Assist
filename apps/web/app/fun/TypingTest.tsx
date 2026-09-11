"use client";

import { memo, useEffect, useImperativeHandle, useLayoutEffect, useReducer, useRef, useState,
  type KeyboardEvent, type Ref } from "react";
import type { DemoKey } from "./keyboard";
import { createTypingSession, testDurations, typingMetrics, typingReducer, type TestDuration } from "./typingSession";
import styles from "./playground.module.css";

export type TypingTestHandle = { tap(key: DemoKey): void; pause(): void };

type Props = {
  ref: Ref<TypingTestHandle>;
  onActivity(): void;
  onKeyDown(event: KeyboardEvent<HTMLTextAreaElement>): void;
  onKeyUp(event: KeyboardEvent<HTMLTextAreaElement>): void;
  onBlur(): void;
};

export default function TypingTest({ ref, onActivity, onKeyDown, onKeyUp, onBlur }: Props) {
  const [session, dispatch] = useReducer(typingReducer, undefined, () => createTypingSession());
  const [focused, setFocused] = useState(false);
  const input = useRef<HTMLTextAreaElement>(null);
  const round = useRef(0);
  const metrics = typingMetrics(session);
  const complete = session.phase === "complete";

  useEffect(() => {
    if (session.phase !== "running") return;
    // This is the test clock. Elapsed time comes from the monotonic clock,
    // rather than counting ticks, so delayed frames cannot extend a test.
    const timer = window.setInterval(() => dispatch({ type: "tick", now: performance.now() }), 100);
    return () => window.clearInterval(timer);
  }, [session.phase]);

  useImperativeHandle(ref, () => ({
    pause() { dispatch({ type: "pause", now: performance.now() }); },
    tap(key) {
      if (complete) return;
      let value = session.value;
      if (key.code === "Backspace" || key.code === "Delete") value = value.slice(0, -1);
      else if (key.code === "Space" || key.code === "Enter") value += " ";
      else if (/^Key[A-Z]$/.test(key.code)) value += key.label.toLowerCase();
      else if (/^Digit\d$/.test(key.code)) value += key.label;
      else return;
      dispatch({ type: "input", value, now: performance.now() });
    }
  }));

  function restart(duration: TestDuration = session.duration) {
    dispatch({ type: "restart", duration, seed: ++round.current });
    input.current?.focus();
    onBlur();
  }

  function handleKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    onKeyDown(event);
    if (event.key === "Escape") { input.current?.blur(); return; }
    if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"].includes(event.key)) {
      event.preventDefault();
    }
    if (!event.metaKey && !event.ctrlKey) onActivity();
  }

  const hint = complete ? "Test complete. Go again?"
    : session.phase === "paused" ? "Paused. Start typing to continue."
    : session.phase === "running" ? "Keep going. Find your rhythm."
    : focused ? "Follow the words. The clock starts with your first letter."
    : "Click the words and start typing, or tap the keys below.";

  return (
    <div className={styles.test}>
      <div className={styles.testToolbar}>
        <div className={styles.durations} aria-label="Test duration">
          {testDurations.map(duration => <button type="button" key={duration}
            aria-pressed={session.duration === duration} onClick={() => restart(duration)}>{duration}s</button>)}
        </div>
        <dl className={styles.metrics} aria-label={complete ? "Typing result" : "Live typing statistics"}>
          <div><dt>WPM</dt><dd title="Correct characters divided by five, per minute">{metrics.wpm}</dd></div>
          <div><dt>Accuracy</dt><dd>{metrics.accuracy}%</dd></div>
          <div><dt>Time left</dt><dd>{metrics.remaining}s</dd></div>
        </dl>
      </div>
      <div className={styles.pad}>
        {complete ? <div className={styles.result} aria-hidden="true">
          <div><strong>{metrics.wpm}</strong><span>words per minute</span></div>
          <div><strong>{metrics.accuracy}%</strong><span>accuracy</span></div>
        </div> : <PromptWords words={session.words} value={session.value} />}
        <p id="typing-passage" className="sr-only">{session.words.join(" ")}</p>
        <textarea ref={input} className={styles.typingInput} aria-label="Typing test"
          aria-describedby="typing-instructions typing-passage" value={session.value} readOnly={complete}
          maxLength={5000} spellCheck={false} autoComplete="off" autoCorrect="off" autoCapitalize="off"
          onChange={event => dispatch({ type: "input", value: event.target.value, now: performance.now() })}
          onPaste={event => event.preventDefault()} onDrop={event => event.preventDefault()}
          onFocus={() => { setFocused(true); onActivity(); }}
          onClick={() => input.current?.setSelectionRange(session.value.length, session.value.length)}
          onBlur={() => { setFocused(false); dispatch({ type: "pause", now: performance.now() }); onBlur(); }}
          onKeyDown={handleKeyDown} onKeyUp={onKeyUp} />
      </div>
      <div className={styles.testFooter}>
        <span id="typing-instructions">{hint}</span>
        <button type="button" onClick={() => restart()}>{complete ? "Try again" : "Restart test"}</button>
      </div>
      <span className="sr-only" role="status">{complete ? `Test complete. ${metrics.wpm} words per minute. ${metrics.accuracy}% accuracy.` : ""}</span>
    </div>
  );
}

const PromptWords = memo(function PromptWords({ words, value }: { words: string[]; value: string }) {
  const viewport = useRef<HTMLDivElement>(null);
  const activeWord = useRef<HTMLSpanElement>(null);
  const typed = value.split(" ");
  const current = typed.length - 1;

  useLayoutEffect(() => {
    const container = viewport.current;
    const word = activeWord.current;
    if (!container || !word) return;
    const lineHeight = Number.parseFloat(getComputedStyle(container).lineHeight);
    container.scrollTop = Math.max(0, word.offsetTop - lineHeight);
  }, [value, words]);

  return <div ref={viewport} className={styles.wordsWindow} aria-hidden="true">
    {words.map((word, index) => <span key={index} ref={index === current ? activeWord : undefined}
      className={styles.word} data-current-word={index === current || undefined}>
      {Array.from(word).map((letter, position) => {
        const entered = typed[index]?.[position];
        const missed = index < current && entered === undefined;
        const wrong = entered !== undefined && entered !== letter;
        const caret = index === current && position === typed[current].length;
        return <span key={position} data-letter-state={wrong || missed ? "incorrect" : entered === letter ? "correct" : "pending"}
          className={`${wrong || missed ? styles.incorrect : entered === letter ? styles.correct : ""} ${caret ? styles.caret : ""}`}>{letter}</span>;
      })}
      {Array.from(typed[index]?.slice(word.length) ?? "").map((letter, position) =>
        <span className={styles.incorrect} data-letter-state="incorrect" key={`extra-${position}`}>{letter}</span>)}
      {index === current && typed[current].length >= word.length && <span className={styles.caret} />}
    </span>)}
  </div>;
});
