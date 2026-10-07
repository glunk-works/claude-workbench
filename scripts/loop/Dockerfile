# The loop layer (WB-D23, plan v9 § 7.3 "The image"): the pinned devcontainer-base image
# plus the `claude` CLI and the loop's own baked-in, root-owned files. One loop image per
# toolchain; claude-workbench's gate needs only what base carries plus `claude`.
#
# BASE_IMAGE is pinned by tag AND digest. launch.sh reads this default back out of this file
# and runs `gh attestation verify` on the digest before it builds, so bumping the pin is one
# edit here and the same verify then covers it. A tag alone moves; the digest is what is
# verified. The base already runs as non-root uid 1000 with no sudo, strips setuid bits and is
# built for a read-only root.
ARG BASE_IMAGE=ghcr.io/603-identity/devcontainer-base:1.6@sha256:51b4395305137c50e45d08a035a62a945f1f1423966b628314b8cf8a2d9f318b
FROM ${BASE_IMAGE}

# `claude` goes in /usr/local/bin, root-owned, not the native installer's per-user location:
# that is writable state, where the session could replace the binary. Pinned by version and
# sha256 (from the release manifest.json for that version, linux-x64); auto-update is off,
# since an updater would need the update hosts on the proxy list. 2.1.289 is the version the
# plan's tests ([T]) ran against.
ARG CLAUDE_VERSION=2.1.289
ARG CLAUDE_SHA256=a186b99e4a9c88366cd49df2f7dad56c61fc306ef0140b19ee64b7c42a8d1348

USER root
RUN set -eu; \
    curl -fsSL --retry 3 -o /usr/local/bin/claude \
      "https://downloads.claude.ai/claude-code-releases/${CLAUDE_VERSION}/linux-x64/claude"; \
    echo "${CLAUDE_SHA256}  /usr/local/bin/claude" | sha256sum -c -; \
    chown root:root /usr/local/bin/claude; \
    chmod 0755 /usr/local/bin/claude; \
    mkdir -p /etc/claude-code /opt/loop; \
    chmod 0755 /etc/claude-code /opt/loop

# Root-owned, read-only to everyone: the managed settings, and the loop's own scripts.
COPY --chown=root:root --chmod=0444 managed-settings.json /etc/claude-code/managed-settings.json
COPY --chown=root:root --chmod=0444 stop-schema.json /opt/loop/stop-schema.json
COPY --chown=root:root --chmod=0555 proxy.py entrypoint.sh /opt/loop/

# Auto-update off, and no traffic the session does not need (the proxy would refuse it anyway).
ENV DISABLE_AUTOUPDATER=1 \
    DISABLE_TELEMETRY=1 \
    DISABLE_ERROR_REPORTING=1 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

# Non-root; the container is run with a read-only root filesystem, so /etc and the managed
# settings cannot change. Writable state is tmpfs or a volume, set by launch.sh.
USER 1000:1000
WORKDIR /work
ENTRYPOINT ["/opt/loop/entrypoint.sh"]
