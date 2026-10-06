/** Node entry point for `npm run eval` (bundled by esbuild into eval/.build/, git-ignored). */

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { runFromArgs } from "./run";

function localDate(): string {
  const now = new Date();
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

try {
  const outcome = await runFromArgs(process.argv.slice(2), {
    readText: (path) => readFileSync(path, "utf8"),
    writeText: (path, text) => {
      mkdirSync(path.slice(0, path.lastIndexOf("/")), { recursive: true });
      writeFileSync(path, text, "utf8");
    },
    env: {
      GEMINI_API_KEY: process.env.GEMINI_API_KEY,
      GROQ_API_KEY: process.env.GROQ_API_KEY,
      XAI_API_KEY: process.env.XAI_API_KEY,
    },
    today: localDate(),
    log: (line) => console.log(line),
  });
  if (!outcome.ok) process.exitCode = 1;
} catch (error) {
  console.error(`eval: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 2;
}
