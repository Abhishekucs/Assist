import Link from "next/link";

import SiteFooter from "../SiteFooter";
import SiteHeader from "../SiteHeader";
import { CHECKOUT_HREF } from "../siteNavigation";
import { createPageMetadata } from "../siteMetadata";

export const metadata = createPageMetadata({
  title: "Mac Notch Modules — Notes, Timers, Calendar & More",
  description:
    "Choose the Assist modules you want in your Mac notch: a file shelf, notes, timers, calendar, media, system stats, screen time, image conversion, revenue, and local AI token activity.",
  path: "/modules"
});

const groups = [
  {
    title: "Keep your day moving",
    modules: [
      { name: "Shelf", detail: "Drop files on the notch and drag them into another app. Assist keeps references, not copies." },
      { name: "Notes", detail: "Keep a scratchpad one hover away. Your notes are saved locally as you type." },
      { name: "Timers", detail: "Run Pomodoro sessions, countdowns, a stopwatch, or hydration reminders. Active clocks stay visible on the collapsed notch." },
      { name: "Calendar", detail: "See the next seven days of events and add or complete reminders in place with calendar access." }
    ]
  },
  {
    title: "See it at a glance",
    modules: [
      { name: "Media", detail: "See what's playing in Music or Spotify and use previous, play/pause, and next controls." },
      { name: "System", detail: "Check CPU, memory, disk, network, and battery details while the module is open." },
      { name: "Screen Time", detail: "See time spent in your apps today. The local tracker pauses during idle time and sleep." }
    ]
  },
  {
    title: "Tools for your workflow",
    modules: [
      { name: "Convert", detail: "Drop images to make JPEG, PNG, HEIC, or PDF files beside the originals, with optional resizing." },
      { name: "Revenue", detail: "See sales from Stripe, Polar, or Dodo Payments for today, seven days, and 30 days. Add provider keys in Assist; they stay in your Mac Keychain." },
      { name: "AI Usage", detail: "Switch between Claude Code and Codex daily token activity grids, read from logs on this Mac. Account quotas and reset times aren't shown." }
    ]
  }
] as const;

export default function ModulesPage() {
  return (
    <main id="top" className="feature-page">
      <SiteHeader activePath="/modules" />
      <section className="feature-page-hero modules-hero">
        <div className="feature-page-hero-copy">
          <h1>Your notch. Your tools.</h1>
          <p className="feature-page-summary">
            Assist keeps your clipboard shelf ready and lets you choose what else
            belongs in the notch. Enable the modules you use in the Mac app.
          </p>
          <div className="feature-page-actions">
            <a className="hero-download-button" href={CHECKOUT_HREF}>
              <span aria-hidden="true"></span><span>Download for Mac</span>
            </a>
            <Link className="feature-page-secondary-link" href="/#features">
              See each module
            </Link>
          </div>
          <p className="modules-default-note">
            Shelf, Notes, Timers, and System start enabled. Turn other modules on as needed.
          </p>
        </div>
      </section>

      {groups.map((group, index) => (
        <section className="modules-group" key={group.title}>
          <div className="modules-group-inner">
            <h2>{group.title}</h2>
            <div className={`modules-grid${index === 0 ? " modules-grid-leading" : ""}`}>
              {group.modules.map((module) => (
                <article key={module.name}>
                  <h3>{module.name}</h3>
                  <p>{module.detail}</p>
                </article>
              ))}
            </div>
          </div>
        </section>
      ))}

      <section className="modules-privacy">
        <h2>Useful without getting in the way.</h2>
        <p>
          Your notes, screen time, and AI activity stay on this Mac. Calendar
          needs macOS permission; Revenue connects to the providers you configure.
          Choose which modules appear in the notch at any time.
        </p>
      </section>
      <SiteFooter />
    </main>
  );
}
