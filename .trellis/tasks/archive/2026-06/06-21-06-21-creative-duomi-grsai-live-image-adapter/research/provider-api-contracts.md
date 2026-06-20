# Duomi / GrsAI image provider API contract extraction

Date: 2026-06-21
Sources:
- Duomi Apifox shared doc: `https://s.apifox.cn/b924931e-29c0-4127-b025-d68c90285060/api-192667743`
- Duomi async result doc: `https://s.apifox.cn/b924931e-29c0-4127-b025-d68c90285060/api-447345474`
- GrsAI gpt-image-2 doc: `https://qmy27nhsd9.apifox.cn/452409160e0`
- GrsAI nano-banana doc: `https://qmy27nhsd9.apifox.cn/452392911e0`
- GrsAI async result doc: `https://qmy27nhsd9.apifox.cn/452409577e0`

Raw HTML was fetched only for extraction and then removed because examples include Authorization header samples. This artifact intentionally contains no keys.

## Duomi

### Submit

- Method/path: `POST /v1/images/generations?async=true`
- Base URL shown by docs: `https://duomiapi.com`
- Auth header: `Authorization: <channel key>` (docs example does not use `Bearer`).
- Current documented supported model: `gpt-image-2`.
- Docs mention upcoming `nano-banana` series, but the shared page says upcoming rather than ready for this submit endpoint.
- Request body fields observed:
  - `model` string, required.
  - `prompt` string, required, max length described as 5000 chars.
  - `size` string. Supports `auto`, pixel sizes like `1024x1024`, custom `widthxheight`, and ratios including `1:1`, `3:2`, `2:3`, `16:9`, `9:16`, `1:2`, `2:1`, `4:3`, `3:4`, `5:4`, `4:5`. Custom dimensions require each side divisible by 16, side range `[16,3840]`, pixel budget `655360..8294400`.
  - `image` array/string. Reference images; docs say multiple as array, single may be string or array.
  - `quality` enum `low|medium|high`; doc label says “思考深度”, but product/UI should treat it as provider-specific quality/effort, not OpenTU “画质”.
- Async submit success example: `{ "id": "<provider-task-id>" }`.

### Poll/result

- Method/path: `GET /v1/tasks/{id}`
- Base URL: `https://duomiapi.com`
- Auth header: same submit key.
- Success response shape observed:
  - `id` string
  - `state` string, e.g. `succeeded`
  - `data.images[]` with `url`, `file_name`
  - `progress` integer
  - `create_time`, `update_time`
  - `action`
- Result URLs are provider/CDN URLs and must not be returned raw to the browser; Creative public DTO should expose owned `/creative/relay/v1/images/tasks/:task_id/content` URLs only.

## GrsAI

### Submit for gpt-image-2

- Method/path: `POST /v1/api/generate`
- Base URLs shown by docs:
  - global: `https://grsaiapi.com`
  - domestic: `https://grsai.dakka.com.cn`
- Auth header: `Authorization: Bearer <channel key>`.
- Supported models shown: `gpt-image-2`, `gpt-image-2-vip`.
- Request body fields observed:
  - `model` string, required.
  - `prompt` string, required.
  - `images` array, supports base64 and URL links.
  - `aspectRatio` string. For `gpt-image-2`, supports ratio and 1K pixel value; for `gpt-image-2-vip`, supports 1K-4K pixel values and not ratios. Docs list examples for common ratios.
  - `replyType` string: `json`, `stream`, `async`. For backend task adapter use `async` only.
- Response shapes observed:
  - Succeeded direct JSON: `{ id, status: "succeeded", results: [{ url }] }`.
  - Async submit: `{ id, status: "running" }`.
  - Failure: `{ id, status: "failed", error }` or `violation`.

### Submit for nano-banana

- Same method/path/base/auth as GrsAI gpt-image-2: `POST /v1/api/generate`.
- Supported models shown:
  - `nano-banana`
  - `nano-banana-fast`
  - `nano-banana-2`
  - `nano-banana-2-cl`
  - `nano-banana-2-4k-cl`
  - `nano-banana-pro`
  - `nano-banana-pro-cl`
  - `nano-banana-pro-vip`
  - `nano-banana-pro-4k-vip`
- Request body fields observed:
  - `model`, `prompt`, `images`, `aspectRatio`, `imageSize`, `replyType`.
  - `aspectRatio` common values: `auto`, `1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `3:2`, `2:3`, `5:4`, `4:5`, `21:9`; nano-banana-2 series additionally supports `1:4`, `4:1`, `1:8`, `8:1`.
  - `imageSize` example: `1K`.
- For backend v1, `replyType` must be forced to `async` by the adapter, not accepted from browser `userParams`.

### Poll/result

- Method/path: `GET /v1/api/result?id=<provider-task-id>`
- Auth header: `Authorization: Bearer <channel key>`.
- Response fields observed: `id`, `status`, `results[]`, `progress`, `error`.
- Status values observed/described: `running`, `violation`, `succeeded`, `failed`.

## Provider differences that matter for design

- Auth header differs:
  - Duomi: `Authorization: <key>`
  - GrsAI: `Authorization: Bearer <key>`
- Submit URL differs:
  - Duomi: `/v1/images/generations?async=true`
  - GrsAI: `/v1/api/generate`
- Poll URL differs:
  - Duomi: `/v1/tasks/{id}`
  - GrsAI: `/v1/api/result?id={id}`
- Parameter names differ:
  - Duomi uses `size`, `image`, `quality`.
  - GrsAI uses `aspectRatio`, `images`, `imageSize`, `replyType`.
- Result status field differs:
  - Duomi uses `state`.
  - GrsAI uses `status`.
- Result URL locations differ:
  - Duomi `data.images[].url`.
  - GrsAI `results[].url`.
- Both providers can return provider-hosted result URLs; browser DTO must not leak them raw.
