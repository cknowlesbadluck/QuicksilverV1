import { describe, expect, it } from "vitest";
import { MAX_SSE_LINE_CHARS, readSseData, SseLineTooLongError } from "../src/providers/sse";
import { chunkedBody } from "./upstreamHelpers";

async function collect(text: string, size = 3): Promise<string[]> {
  const out: string[] = [];
  for await (const data of readSseData(chunkedBody(text, size))) out.push(data);
  return out;
}

describe("readSseData (upstream SSE reader)", () => {
  it("yields data payloads across LF, CRLF and CR line endings", async () => {
    await expect(collect("data: a\n\ndata: b\r\n\r\ndata: c\r\rdata:d\n\n")).resolves.toEqual([
      "a",
      "b",
      "c",
      "d",
    ]);
  });

  it("handles a CRLF split across chunks without inventing an empty event", async () => {
    for (const size of [1, 2, 5, 8]) {
      await expect(collect("data: x\r\ndata: y\r\n\r\n", size)).resolves.toEqual(["x\ny"]);
    }
  });

  it("joins multi-line data, ignores comments and other fields, drops a pending event at EOF", async () => {
    const text = ": ping\nevent: message\nid: 4\ndata: one\ndata: two\n\ndata: lost";
    await expect(collect(text)).resolves.toEqual(["one\ntwo"]);
  });

  it("decodes multi-byte characters split across chunks", async () => {
    await expect(collect("data: ‹mercurio› ☿\n\n", 1)).resolves.toEqual(["‹mercurio› ☿"]);
  });

  it("throws on an over-long line instead of buffering without bound", async () => {
    const huge = `data: ${"x".repeat(MAX_SSE_LINE_CHARS + 10)}`;
    await expect(collect(huge, 65_536)).rejects.toBeInstanceOf(SseLineTooLongError);
  });

  it("cancels the upstream body when the consumer stops early", async () => {
    let cancelled = false;
    const body = new ReadableStream<Uint8Array>({
      pull(controller) {
        controller.enqueue(new TextEncoder().encode("data: tick\n\n"));
      },
      cancel() {
        cancelled = true;
      },
    });
    for await (const data of readSseData(body)) {
      expect(data).toBe("tick");
      break;
    }
    expect(cancelled).toBe(true);
  });
});
