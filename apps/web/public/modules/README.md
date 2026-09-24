# Assist module screenshots

These images are renders of the actual macOS notch module views, not drawings or screenshots of someone’s desktop. The opt-in `MarketingScreenshotTests` runs the views with isolated preferences and temporary files. Clipboard, Shelf, Notes, Focus, System, Screen Time, and AI Usage contain sample data; Calendar and Revenue show their unconnected states. `hydration-alert.png` shows the transient timer notification. The previews do not contain personal clipboard entries, calendar events, provider keys, sales, or local AI logs.

To regenerate on a Mac without Calendar or Reminders access in the test process:

```sh
cd apps/macos
ASSIST_MODULE_SCREENSHOT_DIR="$(cd ../web/public/modules && pwd)" swift test --filter MarketingScreenshotTests
```

Inspect every image before publishing it. The test deliberately skips export if its process can access personal calendars. The icon assets in these renders come from the app's bundled Hugeicons free set; see `apps/macos/Sources/Assist/Resources/Icons/README.md` for source and license.
