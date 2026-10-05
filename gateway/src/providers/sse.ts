/**
 * Minimal upstream SSE reader for provider adapters (M3-T18).
 *
 * Follows the WHATWG event-stream rules the adapters need: lines end in LF, CRLF or CR;
 * `data:` fields of one event are joined with "\n"; a blank line dispatches the event;
 * comment lines (`:`) and other fields are ignored; a pending event at EOF is dropped.
 * Only `data` payloads are yielded, because Gemini and OpenAI-compatible streams carry
 * everything in them.
 *
 * A line longer than `MAX_SSE_LINE_CHARS` throws, so a broken upstream cannot grow the
 * buffer without bound. Nothing here logs payloads.
 */

export const MAX_SSE_LINE_CHARS = 1_048_576;

export class SseLineTooLongError extends Error {
  constructor() {
    super("upstream SSE line exceeded the size limit");
  }
}

/** Yields each event's `data` (joined with "\n"). Cancels the body when iteration stops. */
export async function* readSseData(body: ReadableStream<Uint8Array>): AsyncGenerator<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let data: string[] = [];
  let finished = false;

  function* takeLines(final: boolean): Generator<string> {
    for (;;) {
      const match = /\r\n|\r|\n/.exec(buffer);
      if (match === null) break;
      // A trailing CR may be the first half of CRLF split across chunks: wait for more.
      if (!final && match[0] === "\r" && match.index === buffer.length - 1) break;
      yield buffer.slice(0, match.index);
      buffer = buffer.slice(match.index + match[0].length);
    }
    if (buffer.length > MAX_SSE_LINE_CHARS) throw new SseLineTooLongError();
  }

  function* dispatch(line: string): Generator<string> {
    if (line === "") {
      if (data.length > 0) yield data.join("\n");
      data = [];
      return;
    }
    if (line.startsWith(":")) return;
    const colon = line.indexOf(":");
    const field = colon === -1 ? line : line.slice(0, colon);
    if (field !== "data") return;
    let value = colon === -1 ? "" : line.slice(colon + 1);
    if (value.startsWith(" ")) value = value.slice(1);
    data.push(value);
  }

  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) {
        buffer += decoder.decode();
        for (const line of takeLines(true)) yield* dispatch(line);
        // Text after the last line break is an unterminated line: discarded (WHATWG).
        finished = true;
        return;
      }
      buffer += decoder.decode(value, { stream: true });
      for (const line of takeLines(false)) yield* dispatch(line);
    }
  } finally {
    if (!finished) {
      // Stopped early (terminal chunk, abort, error): release the upstream connection.
      void reader.cancel().catch(() => undefined);
    }
    try {
      reader.releaseLock();
    } catch {
      // Already released or errored: nothing to do.
    }
  }
}
