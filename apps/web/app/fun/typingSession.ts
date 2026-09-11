export const testDurations = [15, 30, 60] as const;
export type TestDuration = typeof testDurations[number];

const vocabulary = "the a one two and or but if as at by for from in into of on out to up with you we they she he it this that each some all any both can could will would may do make have get give take come go keep let help know think feel find see look hear say tell ask read write work play move run walk turn try start stop open close build bring carry change choose create draw dream enjoy explore follow grow learn listen live love meet share show smile sound space light world day night time place way home room house city road river water rain wind tree green blue clear small little big new old good great first next last long short fast slow soft warm cool right left near far quiet bright every never always often still just only over under around through before after again together between because about also more much many most other own well even here there now then when where how what who why while".split(" ");

/** A deterministic first passage keeps the server and client render identical. */
export function makePassage(seed: number): string[] {
  let value = seed + 1;
  return Array.from({ length: 250 }, () => {
    value = (Math.imul(value, 1664525) + 1013904223) >>> 0;
    return vocabulary[value % vocabulary.length];
  });
}

export type TypingSession = {
  words: string[];
  duration: TestDuration;
  value: string;
  phase: "ready" | "running" | "paused" | "complete";
  elapsedMs: number;
  updatedAt: number | null;
  attempts: number;
  correctAttempts: number;
};

export type TypingAction =
  | { type: "input"; value: string; now: number }
  | { type: "tick"; now: number }
  | { type: "pause"; now: number }
  | { type: "restart"; duration: TestDuration; seed: number };

export function createTypingSession(duration: TestDuration = 30, seed = 0): TypingSession {
  return { words: makePassage(seed), duration, value: "", phase: "ready", elapsedMs: 0,
    updatedAt: null, attempts: 0, correctAttempts: 0 };
}

function advanceClock(state: TypingSession, now: number): TypingSession {
  if (state.phase !== "running" || state.updatedAt === null) return state;
  const elapsedMs = Math.min(state.duration * 1000, state.elapsedMs + Math.max(0, now - state.updatedAt));
  const complete = elapsedMs >= state.duration * 1000;
  return { ...state, elapsedMs, updatedAt: complete ? null : now, phase: complete ? "complete" : "running" };
}

export function typingReducer(state: TypingSession, action: TypingAction): TypingSession {
  if (action.type === "restart") return createTypingSession(action.duration, action.seed);
  const next = advanceClock(state, action.now);
  if (next.phase === "complete") return next;
  if (action.type === "tick") return next;
  if (action.type === "pause") {
    return next.phase === "running" ? { ...next, phase: "paused", updatedAt: null } : next;
  }
  const value = action.value.replace(/\n/g, " ").slice(0, 5000);
  if (value === next.value) return next;

  // Count new input, including corrections; backspace never erases mistakes
  // from accuracy. A space advances the word even when its spelling is wrong.
  let prefix = 0;
  while (prefix < value.length && value[prefix] === next.value[prefix]) prefix++;
  const before = value.slice(0, prefix).split(" ");
  let wordIndex = before.length - 1;
  let letterIndex = before[wordIndex].length;
  let attempts = next.attempts;
  let correctAttempts = next.correctAttempts;
  for (let i = prefix; i < value.length; i++) {
    const letter = value[i];
    attempts++;
    if (letter === " ") {
      const wordStart = i - letterIndex;
      if (value.slice(wordStart, i) === next.words[wordIndex]) correctAttempts++;
      wordIndex++;
      letterIndex = 0;
    } else {
      if (letter === next.words[wordIndex]?.[letterIndex]) correctAttempts++;
      letterIndex++;
    }
  }
  const typedWords = value.split(" ");
  const lastWord = next.words.length - 1;
  const complete = typedWords.length > next.words.length
    || (typedWords.length === next.words.length && typedWords[lastWord].length >= next.words[lastWord].length);
  return { ...next, value, attempts, correctAttempts,
    phase: complete ? "complete" : "running", updatedAt: complete ? null : action.now };
}

export function typingMetrics(state: TypingSession) {
  const typed = state.value.split(" ");
  let correctCharacters = 0;
  for (let word = 0; word < typed.length && word < state.words.length; word++) {
    for (let letter = 0; letter < typed[word].length; letter++) {
      if (typed[word][letter] === state.words[word][letter]) correctCharacters++;
    }
    if (word < typed.length - 1 && typed[word] === state.words[word]) correctCharacters++;
  }
  return {
    // Five correct characters count as one word. Avoid unstable first-frame rates.
    wpm: state.elapsedMs < 1000 ? 0 : Math.round(correctCharacters / 5 / (state.elapsedMs / 60_000)),
    accuracy: state.attempts === 0 ? 100 : Math.round(state.correctAttempts / state.attempts * 100),
    remaining: Math.max(0, Math.ceil(state.duration - state.elapsedMs / 1000))
  };
}
