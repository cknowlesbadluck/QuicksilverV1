// The few Node APIs eval/cli.ts uses. The gateway compiles against Workers types only
// (no @types/node), so these are declared here instead of adding a dependency.
declare const process: {
  argv: string[];
  env: Record<string, string | undefined>;
  exitCode?: number;
};

declare module "node:fs" {
  export function readFileSync(path: string, encoding: "utf8"): string;
  export function writeFileSync(path: string, data: string, encoding: "utf8"): void;
  export function mkdirSync(path: string, options: { recursive: true }): void;
}
