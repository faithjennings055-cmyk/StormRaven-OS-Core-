---
name: image-generation
description: Generate or edit images from inside the sandbox through the platform egress proxy. Read this when asked to create, edit, or remix an image, or before calling any /v1/images endpoint or a Gemini image model (nano banana).
---

# Image generation

The sandbox egress proxy platform-keys image generation the same way it does
chat: POST to the provider endpoint with the `sentinel` placeholder and the
proxy stamps the real credential on the way out. Never put a real key in a
request; never bypass the proxy.

## Generate an image

```bash
curl -s -o /tmp/image.json \
  -X POST https://api.openai.com/v1/images/generations \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sentinel' \
  -d '{
    "model": "gpt-image-2",
    "prompt": "a watercolor sketch of a lighthouse",
    "n": 1,
    "size": "1024x1024",
    "quality": "medium"
  }'
```

The response JSON carries each image under `data[i].b64_json` (base64 PNG/WebP,
no URL). Decode to a file:

```bash
jq -r '.data[0].b64_json' /tmp/image.json | base64 -d > /tmp/image.png
```

Default to the provider's LATEST image model rather than a pinned id — today
that's `gpt-image-2`; check their model list/docs when unsure, don't reach for
a stale one.

## Nano banana (Google Gemini image models)

Google's current image models — `gemini-3.1-flash-image` (Nano Banana 2, the
default pick) and `gemini-3-pro-image` (Nano Banana Pro, higher fidelity for
design work) — generate through Gemini's NATIVE surface. Default to their
latest image model rather than a pinned id (the `/v1beta/models` list or their
docs is the source of truth; today that's the 3-series flash image model): a
`:generateContent` call with `responseModalities: ["IMAGE"]`. Address the
Gemini host with `x-goog-api-key: sentinel` and the proxy stamps the platform
Google key. (Note: gemini-2.5-flash-image, the original nano banana, was
deprecated and shut down by Google on 2026-10-02 — use the 3-series models.)

```bash
curl -s -o /tmp/nb.json --max-time 180 \
  -X POST 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image:generateContent' \
  -H 'Content-Type: application/json' \
  -H 'x-goog-api-key: sentinel' \
  -d '{
    "contents": [{
      "parts": [{"text": "a watercolor sketch of a lighthouse"}]
    }],
    "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
  }'
```

The response carries the image inline as base64 — decode it to a file:

```bash
jq -r '.candidates[0].content.parts[] | select(.inlineData) | .inlineData.data' /tmp/nb.json \
  | base64 -d > /tmp/image.png
```

- Editing/remixing: add an `inlineData` part to the request `contents`
  (`{"inlineData": {"mimeType": "image/png", "data": "<base64>"}}`) alongside
  the text.
- Model ids: `gemini-3.1-flash-image` (fast), `gemini-3-pro-image` (pro). Do
  NOT use `gemini-2.5-flash-image` — shut down. The OpenAI-compatible
  alternative (`/v1beta/openai/chat/completions` with
  `modalities: ["text","image"]`, `Authorization: Bearer sentinel`) also
  works platform-keyed, but the native surface above is the documented one.
- Never call the native surface with a literal `x-goog-api-key` value of
  `sentinel` UNSET — always send the header (the proxy replaces the sentinel
  with the platform key).
- Image output is expensive per token (image output tokens bill far above
  text — $60/MTok for Nano Banana 2, $120/MTok for Pro), so a single image is
  the default; don't fan out variants unless asked.

## Variants

- `/v1/images/edits` — edit an existing image. POST `multipart/form-data` with
  `image` (PNG ≤ 4MB), `prompt`, and the same auth header. `gpt-image-1` only.
- `/v1/images/variations` — remix an existing image, same multipart shape.
- `dall-e-3` / `dall-e-2` also work on `/generations`; they return `url`
  instead of `b64_json` (they can't accept transparency or multipart edits).
- `gpt-image-1-mini` when the ask is quick and cheap (sticker, icon, sketch).

## Notes

- `quality` for `gpt-image-1` is `low | medium | high` (default `auto`), and
  costs scale with it — prefer `low` for drafts, `high` only for the final
  render. `dall-e-3` uses `standard | hd`.
- `size` values: `1024x1024`, `1536x1024`, `1024x1536` (`gpt-image-1`), or
  `1792x1024` / `1024x1792` (`dall-e-3`).
- Generation takes 10-60s; set a generous curl timeout (`--max-time 120`).
- Generation IS billed to the workspace like any model call. Multiple images
  (`n`) multiply the cost.
- If the call ever returns a 401 with "Missing bearer authentication", the
  proxy didn't stamp the credential — retry once, then report it; do not try
  to substitute your own key.
