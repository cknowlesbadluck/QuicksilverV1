/**
 * Leak fence. 16:00 EDT 2026-10-09.
 *
 * Scans text that an agent is about to record. A required-key name is not a
 * secret. A token, bearer, or passworded Postgres URL is. Redaction never
 * echoes the matched span. Phase admission stays false.
 * Does not fetch, invent secrets, merge pulls, or delete refs.
 */

export const LEAK_FENCE_REVISION = "2026-10-09-leak-fence";

const SHAPES: ReadonlyArray<{ kind: string; pattern: RegExp }> = [
  { kind: "jwt", pattern: /eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{8,}/g },
  { kind: "sb_secret", pattern: /sb_secret_[A-Za-z0-9_-]{8,}/g },
  { kind: "bearer", pattern: /Bearer\s+[A-Za-z0-9._-]{20,}/g },
  { kind: "postgres_url_with_password", pattern: /postgres(?:ql)?:\/\/[^:\s]+:[^@\s]{3,}@/gi },
];

export type LeakDecision = {
  revision: string;
  leaked: boolean;
  kinds: string[];
  phaseAdmitted: false;
  redacted: string;
};

export function inspectLeak(text: string): LeakDecision {
  const kinds: string[] = [];
  let redacted = text ?? "";
  for (const shape of SHAPES) {
    shape.pattern.lastIndex = 0;
    if (shape.pattern.test(redacted)) {
      kinds.push(shape.kind);
      shape.pattern.lastIndex = 0;
      redacted = redacted.replace(shape.pattern, `[redacted:${shape.kind}]`);
    }
  }
  return {
    revision: LEAK_FENCE_REVISION,
    leaked: kinds.length > 0,
    kinds,
    phaseAdmitted: false,
    redacted,
  };
}

export function assertSafeToRecord(text: string): string {
  const decision = inspectLeak(text);
  if (decision.leaked) {
    throw new Error(`refusing to record secret-shaped content (${decision.kinds.join(",")})`);
  }
  return text;
}
