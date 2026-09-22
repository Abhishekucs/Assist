import type { ProductFeaturePath } from "./siteNavigation";

export const SITE_URL = "https://assistapp.dev";
export const SITE_NAME = "Assist";

export const HOME_TITLE =
  "Assist for Mac — Screenshots, Voice Annotation & Clipboard";
export const HOME_DESCRIPTION =
  "Capture and edit Mac screenshots, add local voice annotations, and keep clipboard history close. Assist is a native, local-first app for macOS 14+.";

export type ProductFaq = {
  question: string;
  answer: string;
};

export type ProductFeature = {
  id: "screenshots" | "voice-annotation" | "clipboard";
  path: ProductFeaturePath;
  name: string;
  metadataTitle: string;
  metadataDescription: string;
  title: string;
  summary: string;
  video: string;
  videoLabel: string;
  directQuestion: string;
  directAnswer: string;
  benefits: ReadonlyArray<{
    title: string;
    description: string;
  }>;
  steps: ReadonlyArray<{
    title: string;
    description: string;
  }>;
  faqs: ReadonlyArray<ProductFaq>;
};

export const PRODUCT_FEATURES: ReadonlyArray<ProductFeature> = [
  {
    id: "screenshots",
    path: "/screenshots",
    name: "Screenshots",
    metadataTitle: "Screenshot App for Mac — Capture, Crop & Blur",
    metadataDescription:
      "Capture a full Mac display with Control + Option, then crop, blur, or frame it in Assist's quick editor. The original is saved locally first.",
    title: "Take cleaner Mac screenshots without breaking your flow.",
    summary:
      "Press Control + Option to capture the full display. Assist saves the original immediately, then opens a compact editor under the notch for optional crop, blur, and backdrop changes.",
    video: "/videos/screenshot-editor.mp4",
    videoLabel: "Assist screenshot capture and quick editor demonstration",
    directQuestion: "What does Assist do for Mac screenshots?",
    directAnswer:
      "Assist captures the full Mac display with Control + Option, stores the screenshot locally, and offers a short-lived quick editor for cropping, blurring private details, or adding a framed backdrop. If you close or ignore the editor, the original screenshot remains saved.",
    benefits: [
      {
        title: "Capture immediately",
        description:
          "Control + Option captures the full display without opening a separate capture utility."
      },
      {
        title: "Edit only when needed",
        description:
          "Crop freely or to a fixed ratio, blur with three brush sizes, and add padding, rounded corners, a shadow, or a backdrop."
      },
      {
        title: "Keep the original safe",
        description:
          "The screenshot is saved before the editor appears. Saving replaces it with the edit; closing keeps the original."
      }
    ],
    steps: [
      {
        title: "Press Control + Option",
        description: "Assist captures the current display and adds it to local history."
      },
      {
        title: "Adjust the quick editor",
        description: "Crop, blur, or frame the capture if it needs cleanup."
      },
      {
        title: "Copy or drag it out",
        description: "Reuse the saved screenshot in a document, message, or another app."
      }
    ],
    faqs: [
      {
        question: "What is the screenshot shortcut in Assist?",
        answer:
          "Press Control + Option to capture the full display immediately. The screenshot is saved to Assist's local history."
      },
      {
        question: "What happens if I ignore the quick editor?",
        answer:
          "The original screenshot remains saved. The editor closes after about five seconds if you never hover it, and an unsaved draft is discarded when you leave it."
      },
      {
        question: "Can Assist blur private information?",
        answer:
          "Yes. The quick editor includes a blur tool with three brush sizes, so you can cover private details before reusing the screenshot."
      }
    ]
  },
  {
    id: "voice-annotation",
    path: "/voice-annotation",
    name: "Voice Annotation",
    metadataTitle: "Voice Annotation for Mac Screenshots",
    metadataDescription:
      "Hold Option to draw over your Mac screen and speak. Assist saves the annotated screenshot with an optional transcript created locally on Apple silicon.",
    title: "Point at the problem. Say what you mean.",
    summary:
      "Hold Option anywhere on macOS, draw over what matters, and speak while you point it out. Release Option to save the annotation with its optional local transcript.",
    video: "/videos/voice-annotation.mp4",
    videoLabel: "Assist voice annotation workflow demonstration",
    directQuestion: "How does voice annotation work in Assist?",
    directAnswer:
      "While you hold Option, Assist lets you draw directly over the Mac screen and optionally records your voice. Releasing Option saves the annotated screenshot. On Apple silicon, WhisperKit can create a transcript locally; Assist does not upload or persist the raw recording.",
    benefits: [
      {
        title: "One continuous gesture",
        description:
          "Hold Option to start, draw and speak together, then release to finish the capture."
      },
      {
        title: "Image and intent stay together",
        description:
          "The marked-up screenshot and optional transcript are saved as one reusable capture."
      },
      {
        title: "Local transcription",
        description:
          "WhisperKit runs on supported Apple-silicon Macs after a one-time model download. Raw audio is not saved."
      }
    ],
    steps: [
      {
        title: "Hold Option",
        description: "Start annotation mode over the screen you are already viewing."
      },
      {
        title: "Draw and speak",
        description: "Mark the exact area and explain the context in the same moment."
      },
      {
        title: "Release to save",
        description: "Assist stores the annotation and its optional local transcript in history."
      }
    ],
    faqs: [
      {
        question: "Does Assist upload my voice recording?",
        answer:
          "No. Optional transcription runs locally with WhisperKit on Apple silicon. Raw audio remains in memory only until transcription finishes and is never saved by Assist."
      },
      {
        question: "Does voice annotation require Apple silicon?",
        answer:
          "Drawing and screenshots work on supported Macs. The optional local Whisper transcription feature requires Apple silicon and a one-time model download."
      },
      {
        question: "How long can a voice annotation be?",
        answer:
          "Assist records up to 90 seconds of speech during an enabled annotation, then processes the optional transcript locally."
      }
    ]
  },
  {
    id: "clipboard",
    path: "/clipboard",
    name: "Clipboard",
    metadataTitle: "Local Clipboard History for Mac",
    metadataDescription:
      "Keep recently copied text beside your Assist screenshots in a local Mac history. Filter, copy again, drag into another app, or delete individual items.",
    title: "Keep copied text and screenshots close.",
    summary:
      "Assist keeps recently copied text in local history beside your screenshots. Open the notch, filter the shelf, and copy or drag an item back into your workflow.",
    video: "/videos/clipboard-history.mp4",
    videoLabel: "Assist clipboard history demonstration",
    directQuestion: "How does clipboard history work in Assist?",
    directAnswer:
      "Assist watches for copied text and stores it locally on your Mac. The notch shelf combines that text with screenshots and annotations, with All, Text, and Images filters. You can copy an item again, drag it into another app, or delete it from history.",
    benefits: [
      {
        title: "One local shelf",
        description:
          "Copied text, screenshots, and voice annotations are available from the same Mac notch surface."
      },
      {
        title: "Filter quickly",
        description:
          "Use All, Text, or Images to narrow the history to the kind of item you need."
      },
      {
        title: "Stay in control",
        description:
          "History stays on your Mac, and you can delete individual items whenever you want."
      }
    ],
    steps: [
      {
        title: "Copy text normally",
        description: "Assist adds the copied text to its local history."
      },
      {
        title: "Open the notch shelf",
        description: "Filter All, Text, or Images to find the item you want."
      },
      {
        title: "Reuse or remove it",
        description: "Copy it again, drag it into another app, or delete it from history."
      }
    ],
    faqs: [
      {
        question: "What does Assist store in clipboard history?",
        answer:
          "Assist stores recently copied text. Its combined history also shows screenshots and annotations captured with Assist."
      },
      {
        question: "Is clipboard history uploaded?",
        answer:
          "No. Copied text and capture history are stored locally on your Mac unless you choose to move an item into another service."
      },
      {
        question: "Can I delete clipboard items?",
        answer:
          "Yes. You can delete individual copied-text or capture items from Assist's history whenever you want."
      }
    ]
  }
] as const;

export const PRODUCT_FAQS: ReadonlyArray<ProductFaq> = [
  {
    question: "What does Assist for Mac do?",
    answer:
      "Assist combines three Mac workflows in the notch: full-screen screenshot capture and editing, voice-powered screen annotation, and local clipboard history."
  },
  {
    question: "How do I take and edit a screenshot?",
    answer:
      "Press Control + Option to capture the full display. Assist saves the original immediately, then opens a quick editor for optional cropping, blurring, padding, rounded corners, shadows, and backdrops."
  },
  {
    question: "How does voice-powered screen annotation work?",
    answer:
      "Hold Option anywhere on macOS, draw over the screen, and speak while you point things out. Release Option to save the annotated screenshot with its optional local transcript."
  },
  {
    question: "Does Assist send my voice recording to the cloud?",
    answer:
      "No. Voice transcription runs locally with WhisperKit on Apple silicon. Raw audio stays in memory only while transcription finishes and is never saved; Assist stores only the resulting transcript and its status."
  },
  {
    question: "How does clipboard history work?",
    answer:
      "Copy text as usual and Assist keeps it in local history alongside your screenshots. Use All, Text, or Images to filter, copy an item again, drag it into another app, or delete it."
  },
  {
    question: "Where does Assist store my screenshots and history?",
    answer:
      "Screenshots, copied text, history, and optional transcripts are stored locally on your Mac. Assist does not OCR or interpret screenshots."
  },
  {
    question: "What are the Mac requirements?",
    answer:
      "Assist requires macOS 14 Sonoma or later. Screenshots and clipboard history work on supported Macs; optional local voice transcription requires Apple silicon and a one-time Whisper model download."
  },
  {
    question: "Which macOS permissions does Assist need?",
    answer:
      "Screen Recording is required for screenshots. Accessibility or Input Monitoring lets Assist detect its shortcuts. Microphone access is optional and requested only for voice transcription."
  },
  {
    question: "Is Assist a subscription?",
    answer:
      "No. Assist is a one-time purchase for one Mac. The website and checkout show the available regional price. There is no recurring subscription."
  }
] as const;

export function getProductFeature(path: ProductFeature["path"]): ProductFeature {
  const feature = PRODUCT_FEATURES.find((item) => item.path === path);

  if (!feature) {
    throw new Error(`Unknown product feature path: ${path}`);
  }

  return feature;
}
