---
name: jina-ai-pro
description: Web search and URL-to-LLM-readable extraction via Jina AI Reader. Use when the user needs fresh web search results, wants to read a URL into clean text or markdown, or needs lightweight bash and curl scripts backed by Jina AI and JINA_API_KEY.
homepage: https://jina.ai/reader
metadata: {"clawdbot":{"requires":{"bins":["bash","curl"],"env":["JINA_API_KEY"]},"primaryEnv":"JINA_API_KEY"}}
---

# Jina AI

Search the web with `s.jina.ai` and extract LLM-friendly content from URLs with `r.jina.ai`.

## Search

```bash
bash {baseDir}/scripts/search.sh "latest Jina AI reader updates"
bash {baseDir}/scripts/search.sh "python argparse tutorial" -n 10
bash {baseDir}/scripts/search.sh "reader api docs" --site jina.ai --site github.com
bash {baseDir}/scripts/search.sh "Jina AI Reader" --ua-preset chrome-windows
bash {baseDir}/scripts/search.sh "Jina AI search grounding" --json
```

## Read A URL

```bash
bash {baseDir}/scripts/read.sh "https://example.com/article"
bash {baseDir}/scripts/read.sh "https://example.com/article" --format markdown
bash {baseDir}/scripts/read.sh "https://example.com/article" --target-selector article
bash {baseDir}/scripts/read.sh "https://example.com/article" --ua-preset safari-macos
bash {baseDir}/scripts/read.sh "https://example.com/article" --with-links-summary
bash {baseDir}/scripts/read.sh "https://example.com/article" --json
```

## Search Options

- `-n`, `--count`: Number of search results to request. Default: `5`
- `--site <domain>`: Restrict search to one or more sites. Repeat the flag to add multiple domains.
- `--timeout <seconds>`: Request timeout. Default: `30`
- `--no-cache`: Bypass Jina cache for the request
- `--user-agent <string>`: Send a custom browser `User-Agent`
- `--ua-preset <chrome-windows|chrome-linux|safari-macos|safari-ios|firefox-linux>`: Use a built-in browser `User-Agent`
- `--json`: Print raw JSON instead of formatted output

## Read Options

- `--format <content|markdown|text|html|pageshot|screenshot|vlm|readerlm-v2>`: Preferred response format. Default: `content`
- `--wait-for-selector <css>`: Wait until the selector appears before returning
- `--target-selector <css>`: Return only the matched element
- `--remove-selector <css>`: Remove matching elements before conversion
- `--retain-links <all|text|none|gpt-oss>`: Control link retention in the rendered output
- `--retain-images <all|alt|none|all_p|alt_p>`: Control image retention
- `--with-generated-alt`: Ask Jina to generate alt text for images that need it
- `--with-links-summary`: Add a dedicated links summary section
- `--with-images-summary`: Add a dedicated images summary section
- `--timeout <seconds>`: Request timeout. Default: `30`
- `--no-cache`: Bypass Jina cache for the request
- `--user-agent <string>`: Send a custom browser `User-Agent`
- `--ua-preset <chrome-windows|chrome-linux|safari-macos|safari-ios|firefox-linux>`: Use a built-in browser `User-Agent`
- `--json`: Print raw API output instead of plain text

## Notes

- Both scripts are plain `bash` wrappers around `curl`.
- The behavior in this skill has been validated against `assets/openapi-search.json` and `assets/openapi-reader.json`.
- Both scripts load `JINA_API_KEY` from the environment first, then fall back to the nearest `.env` they can find while walking up from the script directory.
- Both scripts also honor `JINA_USER_AGENT` from the environment when no CLI `User-Agent` override is provided.
- When a key is present, both scripts send `Authorization: Bearer <JINA_API_KEY>`.
- When a custom UA is configured, the scripts send both `User-Agent` and `X-User-Agent`.
- `search.sh` uses the documented search endpoint `https://s.jina.ai/search?q=...` with `count` and repeated `site` query parameters.
- `read.sh` uses `POST https://r.jina.ai/` with `url=<target>`, which avoids fragile manual URL encoding in shell.
- `search.sh` returns plain-text results by default and JSON only when `--json` is set. This matches the documented `Accept` negotiation without relying on undocumented `X-Respond-With` values.
- If Jina responds with `401` or `403`, the scripts retry once without the auth header. This keeps the tools usable when a key is invalid, rate-limited, or the endpoint still permits anonymous access.
- For Cloudflare `1010` or similar upstream anti-bot blocks, changing `User-Agent` may help but is not guaranteed. Those decisions can depend on broader fingerprinting than the header alone.
- Default output is formatted for direct terminal use. Use `--json` when another tool or script needs the raw response.
