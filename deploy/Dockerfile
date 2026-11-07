# Job-hunt loop for Raspberry Pi 5 (linux/arm64; also builds on x86_64).
# Tooling only: the job-hunt folder (career-ops, ai-job-search, your data) is mounted at /work.
FROM node:22-bookworm

ARG PLAYWRIGHT_VERSION=1.64.1
ARG SUPERCRONIC_VERSION=v0.2.33
ENV TZ=Australia/Perth \
    DEBIAN_FRONTEND=noninteractive \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    DISPLAY=:99 \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    DISABLE_AUTOUPDATER=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-yaml jq git curl ca-certificates tzdata unzip procps \
      xvfb x11vnc novnc websockify fluxbox \
      fonts-noto-core fonts-noto-color-emoji fonts-liberation \
 && rm -rf /var/lib/apt/lists/*

# Scheduler (cron for containers)
RUN arch="$(dpkg --print-architecture)" \
 && curl -fsSL -o /usr/local/bin/supercronic \
      "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${arch}" \
 && chmod +x /usr/local/bin/supercronic

# Claude Code, Playwright MCP (the loop's browser), Vercel CLI, Bun (ai-job-search portal CLIs)
RUN npm install -g @anthropic-ai/claude-code @playwright/mcp vercel bun \
 && npm cache clean --force

# Chromium for career-ops (pinned playwright) and for the Playwright MCP's own playwright version
RUN npx -y "playwright@${PLAYWRIGHT_VERSION}" install --with-deps chromium \
 && MCP_DIR="$(npm root -g)/@playwright/mcp" \
 && PW_CLI="$(node -e "const p=process.argv[1];let c;try{c=require.resolve('playwright/cli.js',{paths:[p]})}catch{c=require.resolve('playwright-core/cli.js',{paths:[p]})}console.log(c)" "$MCP_DIR")" \
 && node "$PW_CLI" install chromium \
 && chmod -R a+rX /ms-playwright \
 && rm -rf /var/lib/apt/lists/* /root/.npm

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
# /work/career-ops/node_modules exists in the image so the Windows compose volume mounted there is owned by node
RUN chmod +x /usr/local/bin/entrypoint.sh && mkdir -p /work/career-ops/node_modules && chown -R node:node /work

USER node
WORKDIR /work
EXPOSE 6080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["scheduler"]
