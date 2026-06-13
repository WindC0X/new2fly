# Container staging route/header check
timestamp_utc=2026-06-13T15:00:07.626379+00:00
base=http://localhost:39083
note=no response bodies, cookies, auth, provider/payment/CDN endpoints, production services, or secrets were sent/printed

| method | path | status | content-type | cache-control | location | x-content-type-options | classification |
|---|---|---:|---|---|---|---|---|
| HEAD | /creative/ | 200 | text/html; charset=utf-8 | no-cache |  | nosniff | pass |
| GET | /creative/ | 200 | text/html; charset=utf-8 | no-cache |  | nosniff | pass |
| HEAD | /creative/sw.js | 200 | text/javascript; charset=utf-8 | no-cache |  | nosniff | pass |
| GET | /creative/sw.js | 200 | text/javascript; charset=utf-8 | no-cache |  | nosniff | pass |
| HEAD | /creative/version.json | 200 | application/json | no-cache |  | nosniff | pass |
| GET | /creative/version.json | 200 | application/json | no-cache |  | nosniff | pass |
| HEAD | /creative/assets/index-Bs1ESiJC.js | 200 | text/javascript; charset=utf-8 | public, max-age=31536000, immutable |  | nosniff | pass |
| GET | /creative/assets/index-Bs1ESiJC.js | 200 | text/javascript; charset=utf-8 | public, max-age=31536000, immutable |  | nosniff | pass |
| HEAD | /creative/assets/index-Bhsy9ZA3.css | 200 | text/css; charset=utf-8 | public, max-age=31536000, immutable |  | nosniff | pass |
| GET | /creative/assets/index-Bhsy9ZA3.css | 200 | text/css; charset=utf-8 | public, max-age=31536000, immutable |  | nosniff | pass |
| HEAD | /creative/assets/__missing_container_check__.js | 404 | text/plain; charset=utf-8 | no-cache |  | nosniff | pass |
| GET | /creative/assets/__missing_container_check__.js | 404 | text/plain; charset=utf-8 | no-cache |  | nosniff | pass |
| HEAD | /creative/api/bootstrap | 404 | application/json; charset=utf-8 | private, no-store |  | nosniff | pass |
| GET | /creative/api/bootstrap | 401 | application/json; charset=utf-8 | private, no-store |  |  | pass |
| HEAD | /creative/api/missing | 404 | application/json; charset=utf-8 | private, no-store |  | nosniff | pass |
| GET | /creative/api/missing | 404 | application/json; charset=utf-8 | private, no-store |  | nosniff | pass |
| HEAD | /creative/relay/v1/chat/completions | 404 | application/json; charset=utf-8 | private, no-store |  | nosniff | pass |
| GET | /creative/relay/v1/chat/completions | 404 | application/json; charset=utf-8 | private, no-store |  | nosniff | pass |
