FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash claudeuser && \
    echo "claudeuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up application directory
WORKDIR /home/claudeuser/app
COPY . /home/claudeuser/app
RUN chown -R claudeuser:claudeuser /home/claudeuser/app

USER claudeuser

# Install Claude CLI using the official installer (no npm required)
RUN curl -fsSL https://claude.ai/install.sh | bash

# Create virtualenv and install dependencies
RUN python3 -m venv /home/claudeuser/venv && \
    /home/claudeuser/venv/bin/pip install --upgrade pip setuptools wheel && \
    /home/claudeuser/venv/bin/pip install -e . --use-pep517 || \
    /home/claudeuser/venv/bin/pip install -e .

ENV PATH="/home/claudeuser/venv/bin:/home/claudeuser/.local/bin:/home/claudeuser/.bun/bin:${PATH}"

# Copy Claude credentials and create workspace directory
COPY --chown=claudeuser:claudeuser claudespace/.credentials.json /home/claudeuser/.claude/.credentials.json
RUN mkdir -p /home/claudeuser/.config/claude /home/claudeuser/app/workspace

EXPOSE 8000

ENV HOST=0.0.0.0
ENV PORT=8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

COPY --chown=claudeuser:claudeuser entrypoint.sh /home/claudeuser/entrypoint.sh
RUN sed -i 's/\r$//' /home/claudeuser/entrypoint.sh && \
    chmod +x /home/claudeuser/entrypoint.sh

ENTRYPOINT ["/home/claudeuser/entrypoint.sh"]
