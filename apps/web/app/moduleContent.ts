export const MODULE_WALKTHROUGH = [
  {
    id: "clipboard",
    name: "Clipboard",
    heading: "Mac clipboard history",
    description:
      "Keep text, links, images, and screenshots in one local shelf. Filter, copy, or drag them back into any app.",
    screenshot: "clipboard.png",
    alt: "Assist Clipboard module with two example clips and All, Text, and Images filters",
    path: "/clipboard"
  },
  {
    id: "shelf",
    name: "Shelf",
    heading: "A file shelf in the notch",
    description:
      "Drop files on the notch and drag them into another app without copying or moving the originals.",
    screenshot: "shelf.png",
    alt: "Assist Shelf module holding a sample project brief"
  },
  {
    id: "notes",
    name: "Notes",
    heading: "Quick notes for Mac",
    description:
      "Write in a notch scratchpad that saves every edit and stays open while you type.",
    screenshot: "notes.png",
    alt: "Assist Notes module showing an example scratchpad"
  },
  {
    id: "timers",
    name: "Focus",
    heading: "Focus timers and hydration",
    description:
      "Run Pomodoro, countdown, and stopwatch timers. Active clocks stay visible, and hydration reminders animate in the notch.",
    screenshot: "timers.png",
    alt: "Assist Timers module showing a focus session and hydration interval controls",
    alertScreenshot: "hydration-alert.png"
  },
  {
    id: "calendar",
    name: "Calendar",
    heading: "Calendar and reminders",
    description:
      "See seven days of events, add reminders, and complete them from the notch after granting macOS access.",
    screenshot: "calendar.png",
    alt: "Assist Calendar module prompting for permission before showing events and reminders"
  },
  {
    id: "media",
    name: "Media",
    heading: "Music controls in the notch",
    description:
      "See the current Music or Spotify track and control playback with Mac media keys.",
    screenshot: "media.png",
    alt: "Assist Media module in its idle state before Music or Spotify starts playing"
  },
  {
    id: "stats",
    name: "System",
    heading: "Mac system stats",
    description:
      "View CPU, memory, disk, network, and battery readings, sampled only while the module is open.",
    screenshot: "stats.png",
    alt: "Assist System module showing sample CPU, memory, disk, network, and battery readings"
  },
  {
    id: "screenTime",
    name: "Screen Time",
    heading: "Screen time by app",
    description:
      "Track today’s app usage locally; counting pauses during idle time and sleep.",
    screenshot: "screenTime.png",
    alt: "Assist Screen Time module showing sample app usage today"
  },
  {
    id: "converter",
    name: "Convert",
    heading: "Image converter for Mac",
    description:
      "Drop images to make JPEG, PNG, HEIC, or PDF files beside the originals, with optional resizing.",
    screenshot: "converter.png",
    alt: "Assist Convert module showing image format, quality, and size choices"
  },
  {
    id: "revenue",
    name: "Revenue",
    heading: "Revenue at a glance",
    description:
      "See today, seven-day, and 30-day sales from Stripe, Polar, or Dodo Payments. Keys stay in your Mac Keychain.",
    screenshot: "revenue.png",
    alt: "Assist Revenue module showing the provider connection prompt"
  },
  {
    id: "aiUsage",
    name: "AI Usage",
    heading: "Claude Code and Codex activity",
    description:
      "Compare local daily token grids from Claude Code and Codex logs, without account quota or reset readouts.",
    screenshot: "aiUsage.png",
    alt: "Assist AI Usage module showing a sample Claude Code daily token activity grid"
  }
] as const;
