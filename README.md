# Headroom on Railway

Railway template for [Headroom](https://github.com/headroomlabs-ai/headroom) 0.45.0, an LLM context-compression proxy. It sits between your coding agent or app and your LLM provider (Anthropic, OpenAI or any OpenAI-compatible API) and shrinks tool outputs, logs, JSON and RAG chunks before they reach the model.

## What it deploys

One service, `Headroom`, built from this repo's `Dockerfile`:

- the official image `ghcr.io/headroomlabs-ai/headroom:0.45.0-code-nonroot`, pinned by digest (code-aware compression, non-root user);
- a small start script (`start.sh`) that listens on Railway's `PORT`, keeps all state on the volume, sizes thread pools to the container and refuses to start without a proxy token;
- a volume at `/home/nonroot/.headroom` for the compression cache, savings history, config and the downloaded Kompress model;
- a public domain with the health check on `/readyz`.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `HEADROOM_PROXY_TOKEN` | generated (`${{secret(48)}}`) | Bearer token every client must send. The service refuses to start without it. |
| `PORT` | `8787` | Port the proxy listens on. |

No provider key is stored on the server: clients keep sending their own key (`x-api-key` / `Authorization`) or subscription login, and Headroom forwards it upstream.

Optional variables (set them on the service if you need them): `OPENAI_TARGET_API_URL` / `ANTHROPIC_TARGET_API_URL` to send traffic to another OpenAI- or Anthropic-compatible endpoint, `HEADROOM_DISABLE_KOMPRESS=1` to force the ML compressor off, `HEADROOM_BEACON=on` to re-enable upstream's anonymous usage beacon (off in this template).

## Memory

The proxy itself uses about 300 MB. The Kompress ML compressor needs about 600 MB more, so on plans with less than about 900 MB per service (Railway Free and Trial: 0.5 GB) the start script turns Kompress off and Headroom runs with its rule-based compressors (JSON, logs, code, diffs, search results). Give the service 1 GB or more to get ML compression too.

## Using it

Send the token in the `X-Headroom-Proxy-Token` header so `Authorization` stays free for your provider key:

```bash
# Claude Code
export ANTHROPIC_BASE_URL=https://YOUR-DOMAIN.up.railway.app
export ANTHROPIC_CUSTOM_HEADERS="X-Headroom-Proxy-Token: YOUR-TOKEN"
claude
```

## Updates

The service builds from this repo. When a new Headroom release is tested here, the pin in `Dockerfile` is bumped on `main` and Railway shows an "update available" notice in your project; read `CHANGELOG.md` before applying it. Data on the volume is kept across updates.
