import assert from "node:assert/strict";
import test from "node:test";

import sitemap from "../app/sitemap";
import { MODULE_WALKTHROUGH } from "../app/moduleContent";
import { PRODUCT_FEATURES, SITE_URL } from "../app/productContent";

test("sitemap lists each canonical public route once with accurate content signals", () => {
  const entries = sitemap();
  assert.deepEqual(entries.map((entry) => new URL(entry.url).pathname), [
    "/",
    ...PRODUCT_FEATURES.map((feature) => feature.path),
    "/modules",
    "/keyboard-sound-tester",
    "/privacy",
    "/terms"
  ]);

  for (const entry of entries) {
    assert.match(String(entry.lastModified), /^2026-\d{2}-\d{2}$/);
    assert.equal(entry.changeFrequency, undefined);
    assert.equal(entry.priority, undefined);
  }
});

test("sitemap links the module images actually shown on the homepage", () => {
  const entries = sitemap();
  assert.deepEqual(entries[0].images, [
    `${SITE_URL}/assist-icon.png`,
    ...MODULE_WALKTHROUGH.map((module) => `${SITE_URL}/modules/${module.screenshot}`)
  ]);
  assert.equal(entries[0].videos?.[0]?.content_loc, `${SITE_URL}/videos/notch-modules-demo.mp4`);
  assert.equal(entries[0].videos?.[0]?.thumbnail_loc, `${SITE_URL}/videos/notch-modules-poster.jpg`);

  for (const feature of PRODUCT_FEATURES) {
    const entry = entries.find((item) => item.url === `${SITE_URL}${feature.path}`);
    assert.equal(entry?.videos?.[0]?.content_loc, `${SITE_URL}${feature.video}`);
  }
});
