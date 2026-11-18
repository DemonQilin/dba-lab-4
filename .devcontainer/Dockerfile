# Development container with Oracle Instant Client + SQL*Plus.
# SQL*Plus is the same client the reviewer uses, so the solution script is
# tested here exactly as it will be executed during the review.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG TARGETARCH
ARG IC_BASE_URL=https://download.oracle.com/otn_software/linux/instantclient

# libaio was renamed to libaio1t64 in Ubuntu 24.04; Instant Client still
# looks for libaio.so.1, so a compatibility symlink is required.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libaio1t64 unzip rlwrap \
    && rm -rf /var/lib/apt/lists/* \
    && LIBDIR="/usr/lib/$(uname -m)-linux-gnu" \
    && ln -sf "$LIBDIR/libaio.so.1t64" "$LIBDIR/libaio.so.1"

RUN case "$TARGETARCH" in \
        amd64) IC_ARCH=linuxx64 ;; \
        arm64) IC_ARCH=linux-arm64 ;; \
        *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && mkdir -p /opt/oracle \
    && cd /tmp \
    && curl -fsSLo basic.zip "$IC_BASE_URL/instantclient-basic-$IC_ARCH.zip" \
    && curl -fsSLo sqlplus.zip "$IC_BASE_URL/instantclient-sqlplus-$IC_ARCH.zip" \
    && unzip -qo basic.zip -d /opt/oracle \
    && unzip -qo sqlplus.zip -d /opt/oracle \
    && rm -f basic.zip sqlplus.zip \
    && mv /opt/oracle/instantclient_* /opt/oracle/instantclient \
    && echo /opt/oracle/instantclient > /etc/ld.so.conf.d/oracle-instantclient.conf \
    && ldconfig

ENV PATH="/opt/oracle/instantclient:${PATH}"

# Command history and line editing for interactive SQL*Plus sessions only;
# scripts keep calling the real binary.
RUN echo "alias sqlplus='rlwrap sqlplus'" >> /etc/bash.bashrc \
    && echo "alias sqlplus='rlwrap sqlplus'" >> /etc/zsh/zshrc
