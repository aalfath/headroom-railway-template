#!/bin/sh
# Railway wrapper for Headroom. Sets safe defaults for a public deploy, sizes
# the ML compressor and thread pools to the container, then runs the proxy as
# the non-root user. Any value below can be overridden with a service variable.
set -eu

STATE_DIR=/home/nonroot/.headroom

# Refuse to start without a proxy token: without it the public URL would be an
# open relay to the deployer's LLM provider.
if [ -z "${HEADROOM_PROXY_TOKEN:-}" ]; then
  echo "railway-start: HEADROOM_PROXY_TOKEN is empty; refusing to start an open proxy." >&2
  exit 1
fi

export HOME=/home/nonroot
export HEADROOM_HOST="${HEADROOM_HOST:-::}"
export HEADROOM_PORT="${PORT:-${HEADROOM_PORT:-8787}}"
export HEADROOM_WORKSPACE_DIR="${HEADROOM_WORKSPACE_DIR:-$STATE_DIR}"
export HEADROOM_CONFIG_DIR="${HEADROOM_CONFIG_DIR:-$STATE_DIR/config}"
# Model downloads (Kompress, tokenizers) are cached on the volume, so restarts
# don't download them again.
export HF_HOME="${HF_HOME:-$STATE_DIR/hf}"
export HEADROOM_UPDATE_CHECK="${HEADROOM_UPDATE_CHECK:-off}"
# Railway's health check shouldn't depend on reaching api.anthropic.com.
export HEADROOM_SKIP_UPSTREAM_CHECK="${HEADROOM_SKIP_UPSTREAM_CHECK:-1}"
# Upstream's anonymous usage beacon is on by default; a hosted proxy keeps it
# off unless the deployer sets HEADROOM_BEACON=on.
export HEADROOM_BEACON="${HEADROOM_BEACON:-off}"

# CPUs and memory from the container's cgroup, not the host.
cpus=$(awk '{ if ($1 == "max") print 0; else printf "%d", ($1 + $2 - 1) / $2 }' /sys/fs/cgroup/cpu.max 2>/dev/null || echo 0)
[ "${cpus:-0}" -ge 1 ] 2>/dev/null || cpus=$(nproc)
[ "$cpus" -gt 4 ] && cpus=4
mem_mb=$(awk '{ if ($1 == "max") print 0; else printf "%d", $1 / 1048576 }' /sys/fs/cgroup/memory.max 2>/dev/null || echo 0)

export HEADROOM_COMPRESSION_MAX_WORKERS="${HEADROOM_COMPRESSION_MAX_WORKERS:-$cpus}"
export HEADROOM_KOMPRESS_ONNX_INTRA_THREADS="${HEADROOM_KOMPRESS_ONNX_INTRA_THREADS:-$cpus}"
export HEADROOM_KOMPRESS_ONNX_INTER_THREADS="${HEADROOM_KOMPRESS_ONNX_INTER_THREADS:-1}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$cpus}"

# The Kompress ML compressor needs about 600 MB on top of the proxy. Below
# ~900 MB of RAM (Railway Free/Trial: 0.5 GB) it would be OOM-killed, so the
# proxy runs with its rule-based compressors only (JSON, logs, code, diffs).
if [ -z "${HEADROOM_DISABLE_KOMPRESS:-}" ] && [ "$mem_mb" -gt 0 ] && [ "$mem_mb" -lt 900 ]; then
  export HEADROOM_DISABLE_KOMPRESS=1
  echo "railway-start: ${mem_mb} MB RAM limit; Kompress ML compression off (needs about 1 GB). Rule-based compression stays on."
fi

mkdir -p "$STATE_DIR" "$HEADROOM_CONFIG_DIR" "$HF_HOME"
chown -R 1000:1000 "$STATE_DIR" 2>/dev/null || true

echo "railway-start: headroom $(headroom --version 2>/dev/null | tail -1) on [$HEADROOM_HOST]:$HEADROOM_PORT, cpus=$cpus mem_limit_mb=$mem_mb"
exec setpriv --reuid=1000 --regid=1000 --init-groups headroom proxy "$@"
