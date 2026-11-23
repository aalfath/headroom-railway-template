# Headroom LLM context-compression proxy, packaged for Railway.
# Official upstream image, pinned by version and digest (code-aware build, non-root user).
FROM ghcr.io/headroomlabs-ai/headroom:0.45.0-code-nonroot@sha256:195d5ca4868f6b2c344dfb4a9ef367b4815bd5933d2bf2d78c5a154c16ecbd8b

# The start script runs as root only to fix the Railway volume's ownership,
# then drops to the image's non-root user (uid 1000) with setpriv.
USER root
COPY --chmod=0755 start.sh /usr/local/bin/railway-start.sh
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
