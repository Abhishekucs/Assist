import { cp, mkdir, readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const source = path.resolve(root, "../macos/Sources/Assist/Resources/Sounds");
const destination = path.join(root, "public/keyboard-sounds");
const { sounds } = JSON.parse(await readFile(path.join(root, "app/fun/catalog.json"), "utf8"));
const check = process.argv.includes("--check");
const files = sounds.flatMap(({ id }) => ["down", "up"].flatMap(phase =>
  Array.from({ length: 6 }, (_, i) => `${id}/${phase}-${i}.wav`)));
files.push("LICENSE.txt", "KBSIM-LICENSE.txt", "manifest.json", "recorded-manifest.json", "README.md");

for (const file of files) {
  const target = path.join(destination, file);
  if (check) {
    const hash = data => createHash("sha256").update(data).digest("hex");
    if (hash(await readFile(path.join(source, file))) !== hash(await readFile(target))) {
      throw new Error(`Web and Mac keyboard assets differ: ${file}`);
    }
  } else {
    await mkdir(path.dirname(target), { recursive: true });
    await cp(path.join(source, file), target);
  }
}
console.log(`${check ? "Verified" : "Synced"} ${sounds.length} packs and their source notices.`);
