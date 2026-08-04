---
name: response-streaming-reliability
description: "Use when chat responses are truncated or repeated."
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [reliability, streaming, conversation]
---

# Response Streaming Reliability

Use this skill when the chat reports a network interruption, repeated continuation, or `Response remained truncated after 4 continuation attempts`.

## Workflow

1. Treat the interruption as a transport/streaming problem unless tool output proves the underlying task failed.
2. Do not repeat the whole prior answer. Continue only from the last complete semantic point, or provide a compact completion summary in a fresh response.
3. If the user asks for status after an interruption, verify current state with the relevant source/tool before claiming completion. Prefer a short status covering what was done, what was verified, and remaining uncertainty.
4. Avoid multiple near-identical continuation messages. If a continuation is cut again, answer in a new, very concise message rather than elaborating.
5. When explaining the incident, distinguish transport/provider streaming failure from task failure. Mention active model/provider only when relevant and grounded in runtime metadata.

## Pitfalls

- Do not claim “nothing remains” solely because an earlier response said so; re-check when the user asks for progress.
- Do not resend long lists or tool transcripts after truncation.
- Do not invent a provider diagnosis beyond the available error signal; say “likely streaming/network layer” when exact cause is unknown.

## Compact status format

```text
Đã làm: <action>
Đã xác minh: <evidence>
Còn lại: <none / explicit next step>
```
