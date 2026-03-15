# ZeroClaw AWS Deployment Guide

> Deploy ZeroClaw AI Assistant on AWS from scratch — Telegram Bot integration & LLM API setup.

> **Security Hardening**: After deployment, we strongly recommend applying the [OpenClaw Security Practice Guide](security-practice-guide/) to establish a 3-tier defense matrix for your Agent. Originally from [SlowMist Security Team](https://github.com/slowmist/openclaw-security-practice-guide).
>
> **繁體中文版**: [SETUP_GUIDE_zh-TW.md](SETUP_GUIDE_zh-TW.md)

---

## Table of Contents

1. [AWS Hardware Selection](#1-aws-hardware-selection)
2. [Launch EC2 Instance](#2-launch-ec2-instance)
3. [Connect & Base Environment Setup](#3-connect--base-environment-setup)
4. [Install ZeroClaw](#4-install-zeroclaw)
5. [Configure LLM Provider API](#5-configure-llm-provider-api)
6. [Create Telegram Bot](#6-create-telegram-bot)
7. [Configure ZeroClaw](#7-configure-zeroclaw)
8. [Bind Telegram Channel](#8-bind-telegram-channel)
9. [Start Daemon Service](#9-start-daemon-service)
10. [Systemd Auto-Start on Boot](#10-systemd-auto-start-on-boot)
11. [Docker Deployment (Alternative)](#11-docker-deployment-alternative)
12. [Security Hardening](#12-security-hardening)
13. [Monitoring & Maintenance](#13-monitoring--maintenance)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. AWS Hardware Selection

ZeroClaw is a lightweight Rust binary (~8.8MB) with < 5MB runtime memory. However, **compiling from source** requires more resources.

### Recommended Options

| Use Case | Instance Type | vCPU | RAM | Storage | Est. Cost (us-east-1) |
|----------|--------------|------|-----|---------|----------------------|
| **Recommended: build from source + run** | `t3.medium` | 2 | 4 GB | 20 GB gp3 | ~$30/mo |
| Minimum: pre-built binary only | `t3.micro` | 2 | 1 GB | 10 GB gp3 | ~$8/mo |
| Advanced: multi-channel + high concurrency | `t3.large` | 2 | 8 GB | 30 GB gp3 | ~$60/mo |

### Selection Tips

- **Architecture**: Both `x86_64 (amd64)` and `arm64 (Graviton)` are supported
- **ARM Graviton (e.g., `t4g.medium`)** is typically ~20% cheaper with comparable performance
- **Storage**: gp3 is sufficient; no need for io2
- **For pre-built binary only**, `t3.micro` (Free Tier eligible) is enough

---

## 2. Launch EC2 Instance

### Step 2.1 — Log in to AWS Console

Go to [AWS Console](https://console.aws.amazon.com/) → EC2 → Launch Instance

### Step 2.2 — Configure Instance

| Setting | Recommended Value |
|---------|-------------------|
| Name | `zeroclaw-bot` |
| AMI | **Ubuntu 24.04 LTS** (HVM, SSD Volume Type) |
| Architecture | 64-bit (x86) or 64-bit (Arm) |
| Instance type | `t3.medium` (for building) or `t3.micro` (binary install) |
| Key pair | Create new or use existing `.pem` key |
| Storage | 20 GB gp3 |

### Step 2.3 — Configure Security Group

Create a new Security Group `zeroclaw-sg`:

| Type | Protocol | Port | Source | Purpose |
|------|----------|------|--------|---------|
| SSH | TCP | 22 | My IP | SSH access |
| Custom TCP | TCP | 42617 | 0.0.0.0/0 | ZeroClaw Gateway (if external webhook needed) |
| HTTPS | TCP | 443 | 0.0.0.0/0 | Reverse proxy (optional) |

> **Note**: Port 42617 is only needed for webhook mode. If using Telegram polling mode, you can skip it.

### Step 2.4 — Launch & Record

Click **Launch Instance** and note:
- Instance ID
- Public IP or Elastic IP (recommended to allocate an Elastic IP to prevent IP changes on reboot)

---

## 3. Connect & Base Environment Setup

### Step 3.1 — SSH Connection

```bash
chmod 400 ~/your-key.pem
ssh -i ~/your-key.pem ubuntu@<YOUR_EC2_PUBLIC_IP>
```

### Step 3.2 — System Update & Base Packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential pkg-config libssl-dev git curl
```

### Step 3.3 — Install Rust (only needed for building from source)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustc --version  # Verify installation
```

### Step 3.4 — Configure Swap (recommended for t3.medium)

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 4. Install ZeroClaw

### Method A: One-Click Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash
```

For low-spec machines, use pre-built binary:

```bash
curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash -s -- \
  --prefer-prebuilt \
  --install-system-deps \
  --install-rust
```

### Method B: Build from Source

```bash
git clone https://github.com/zeroclaw-labs/zeroclaw.git
cd zeroclaw
cargo build --release --locked
cargo install --path . --force --locked
export PATH="$HOME/.cargo/bin:$PATH"
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
```

### Method C: Download Pre-built Binary

```bash
# Choose based on your architecture (x86_64 or aarch64)
# Visit https://github.com/zeroclaw-labs/zeroclaw/releases/latest for the right version
# Example:
wget https://github.com/zeroclaw-labs/zeroclaw/releases/latest/download/zeroclaw-linux-x86_64 -O zeroclaw
chmod +x zeroclaw
sudo mv zeroclaw /usr/local/bin/
```

### Verify Installation

```bash
zeroclaw --version
zeroclaw doctor
```

---

## 5. Configure LLM Provider API

ZeroClaw supports 40+ LLM providers. Common options below:

### Option 1: OpenRouter (Recommended — multi-model access)

1. Sign up at [openrouter.ai](https://openrouter.ai/)
2. Go to Dashboard → API Keys → Create new API Key
3. Configure ZeroClaw:

```bash
zeroclaw onboard --api-key sk-or-v1-xxxx --provider openrouter --model "openrouter/auto"
```

### Option 2: Anthropic (Claude series)

1. Get an API Key from [console.anthropic.com](https://console.anthropic.com/)
2. Configure:

```bash
zeroclaw onboard --api-key sk-ant-xxxx --provider anthropic --model "anthropic/claude-sonnet-4-6"
```

### Option 3: OpenAI

1. Get an API Key from [platform.openai.com](https://platform.openai.com/)
2. Configure:

```bash
zeroclaw onboard --api-key sk-xxxx --provider openai
```

### Option 4: Use Existing Claude Code / ChatGPT Subscription

**Claude Code subscription:**
```bash
zeroclaw auth paste-token --provider anthropic --profile default --auth-kind authorization
```

**ChatGPT subscription:**
```bash
zeroclaw auth login --provider openai-codex --device-code
```

### Verify Provider Connection

```bash
zeroclaw agent -m "Hello, are you working?"
```

---

## 6. Create Telegram Bot

### Step 6.1 — Create Bot on Telegram

1. Open Telegram, search for **@BotFather**
2. Send `/newbot`
3. Follow the prompts:
   - **Bot name** (display name): e.g., `ZeroClaw Assistant`
   - **Bot username** (unique ID): e.g., `my_zeroclaw_bot` (must end with `bot`)
4. BotFather will reply with a **Bot Token** in this format:
   ```
   123456789:ABCdefGHIjklMNOpqrsTUVwxyz
   ```
5. **Save this token securely** — do not share it

### Step 6.2 — Configure Bot Info (Optional)

In BotFather:
- `/setdescription` — Set bot description
- `/setabouttext` — Set about text
- `/setuserpic` — Set bot avatar
- `/setcommands` — Set command menu

### Step 6.3 — Get Your Telegram User ID

1. Search for **@userinfobot** or **@raw_data_bot**
2. Send it any message
3. It will reply with your **User ID** (numeric), e.g., `123456789`
4. Note this ID for the allowlist configuration

---

## 7. Configure ZeroClaw

### Step 7.1 — Edit config.toml

```bash
mkdir -p ~/.zeroclaw
nano ~/.zeroclaw/config.toml
```

### Step 7.2 — Full Configuration Example

```toml
# =========================
# ZeroClaw Main Settings
# =========================

# LLM Provider
default_provider = "openrouter"          # or "anthropic", "openai", etc.
api_key = "sk-or-v1-your-api-key-here"   # Your API Key

# Model selection (optional, uses provider default if not set)
# model = "openrouter/auto"
# model = "anthropic/claude-sonnet-4-6"

# Gateway settings
# gateway_port = 42617
# gateway_host = "127.0.0.1"

# =========================
# Telegram Channel Settings
# =========================
[channels_config.telegram]
bot_token = "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"   # Token from BotFather

# Users allowed to interact with the bot
# "*" = everyone (NOT recommended for production)
# Recommend setting specific User IDs
allowed_users = ["123456789"]            # Your Telegram User ID

# Streaming mode: off | partial
stream_mode = "partial"                  # Enable partial streaming for real-time replies

# Stream update interval (milliseconds)
draft_update_interval_ms = 1000

# Require @mention in groups to respond
mention_only = false

# Cancel in-flight reply when new message received
interrupt_on_new_message = false
```

### Step 7.3 — Environment Variables (Alternative)

If you prefer not to store API keys in config.toml:

```bash
# Add to ~/.bashrc or ~/.profile
export OPENROUTER_API_KEY="sk-or-v1-xxxx"
# or
export ANTHROPIC_API_KEY="sk-ant-xxxx"
# or
export OPENAI_API_KEY="sk-xxxx"
```

---

## 8. Bind Telegram Channel

### Step 8.1 — Bind

```bash
zeroclaw channel bind-telegram <YOUR_TELEGRAM_USER_ID>
```

### Step 8.2 — Verify Binding

```bash
zeroclaw integrations info Telegram
zeroclaw channel doctor
```

### Step 8.3 — Test

Start the daemon manually first:

```bash
zeroclaw daemon
```

Send a message to your Bot on Telegram and confirm you receive a reply.

Press `Ctrl+C` to stop the daemon.

---

## 9. Start Daemon Service

### Foreground (for testing)

```bash
zeroclaw daemon
```

### Background

```bash
nohup zeroclaw daemon > ~/.zeroclaw/logs/daemon.stdout.log 2> ~/.zeroclaw/logs/daemon.stderr.log &
```

---

## 10. Systemd Auto-Start on Boot

### Method A: Built-in Command (Recommended)

```bash
zeroclaw service install
zeroclaw service start
zeroclaw service status
```

### Method B: Manual Systemd User Service

```bash
mkdir -p ~/.config/systemd/user/

cat > ~/.config/systemd/user/zeroclaw.service << 'EOF'
[Unit]
Description=ZeroClaw AI Assistant Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.cargo/bin/zeroclaw daemon
Restart=on-failure
RestartSec=10
Environment="PATH=%h/.cargo/bin:/usr/local/bin:/usr/bin:/bin"

# If using environment variables for API keys
# EnvironmentFile=%h/.zeroclaw/.env

# Logging
StandardOutput=append:%h/.zeroclaw/logs/daemon.stdout.log
StandardError=append:%h/.zeroclaw/logs/daemon.stderr.log

[Install]
WantedBy=default.target
EOF
```

```bash
# Enable and start
systemctl --user daemon-reload
systemctl --user enable zeroclaw.service
systemctl --user start zeroclaw.service

# Enable linger so service runs without login
sudo loginctl enable-linger ubuntu

# Check status
systemctl --user status zeroclaw.service
```

### View Logs

```bash
journalctl --user -u zeroclaw.service -f
```

---

## 11. Docker Deployment (Alternative)

If you prefer Docker, you can skip Steps 3-10 and use Docker Compose directly.

### Step 11.1 — Install Docker

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker ubuntu
newgrp docker
```

### Step 11.2 — Create docker-compose.yml

```bash
mkdir -p ~/zeroclaw-docker && cd ~/zeroclaw-docker

cat > docker-compose.yml << 'EOF'
services:
  zeroclaw:
    image: ghcr.io/zeroclaw-labs/zeroclaw:latest
    container_name: zeroclaw
    restart: unless-stopped
    ports:
      - "${HOST_PORT:-42617}:${ZEROCLAW_GATEWAY_PORT:-42617}"
    environment:
      - API_KEY=${API_KEY}
      - PROVIDER=${PROVIDER:-openrouter}
      - ZEROCLAW_MODEL=${ZEROCLAW_MODEL:-}
      - ZEROCLAW_ALLOW_PUBLIC_BIND=true
      - ZEROCLAW_GATEWAY_PORT=${ZEROCLAW_GATEWAY_PORT:-42617}
    volumes:
      - zeroclaw-data:/zeroclaw-data
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 2G
        reservations:
          cpus: "0.5"
          memory: 512M
    healthcheck:
      test: ["CMD", "zeroclaw", "status"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 10s

volumes:
  zeroclaw-data:
EOF
```

### Step 11.3 — Create .env File

```bash
cat > .env << 'EOF'
API_KEY=sk-or-v1-your-api-key-here
PROVIDER=openrouter
ZEROCLAW_MODEL=openrouter/auto
HOST_PORT=42617
EOF
```

### Step 11.4 — Start

```bash
docker compose up -d
docker compose logs -f
```

> **Note**: For Telegram configuration in Docker mode, mount your config.toml into the container:
>
> ```yaml
> volumes:
>   - zeroclaw-data:/zeroclaw-data
>   - ./config.toml:/root/.zeroclaw/config.toml:ro
> ```

---

## 12. Security Hardening

### 12.1 — Telegram Allowlist

**Never** use `allowed_users = ["*"]` in production. Only allow specific User IDs:

```toml
[channels_config.telegram]
allowed_users = ["123456789", "987654321"]   # Only these users can interact
```

### 12.2 — Minimize AWS Security Group

- SSH: Restrict to your IP only
- Don't open port 42617 unless you need webhooks
- Review Security Group rules regularly

### 12.3 — API Key Security

- Never hardcode API keys in source code
- Use environment variables or AWS Secrets Manager
- Rotate API keys periodically

### 12.4 — System Security

```bash
# Enable automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
# If gateway needed: sudo ufw allow 42617/tcp
sudo ufw enable
```

### 12.5 — SSH Key Authentication

Ensure only key authentication is used; disable password login:

```bash
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

---

## 13. Monitoring & Maintenance

### Health Check Commands

```bash
zeroclaw status          # Runtime status overview
zeroclaw doctor          # Configuration validation
zeroclaw channel doctor  # Channel connectivity check
```

### View Logs

```bash
# Systemd
journalctl --user -u zeroclaw.service -f

# Direct log files
tail -f ~/.zeroclaw/logs/daemon.stdout.log
tail -f ~/.zeroclaw/logs/daemon.stderr.log

# Docker
docker compose logs -f zeroclaw
```

### Daemon State Tracking

```bash
cat ~/.zeroclaw/daemon_state.json
```

### Update ZeroClaw

```bash
# If installed via install.sh
curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash -s -- --prefer-prebuilt

# If built from source
cd ~/zeroclaw
git pull
cargo build --release --locked
cargo install --path . --force --locked

# Restart service
systemctl --user restart zeroclaw.service
# Or Docker
docker compose pull && docker compose up -d
```

### Change Management Process

1. Backup existing config: `cp ~/.zeroclaw/config.toml ~/.zeroclaw/config.toml.bak`
2. Make a single change
3. Validate: `zeroclaw doctor`
4. Restart daemon
5. Confirm health checks pass

---

## 14. Troubleshooting

### Bot Not Responding

1. Confirm daemon is running: `zeroclaw status`
2. Verify Telegram token: `zeroclaw channel doctor`
3. Check your User ID is in `allowed_users`
4. Check logs for errors

### Build Failure / OOM

- Add more swap space (see Step 3.4)
- Use pre-built binary instead of building from source
- Upgrade to a larger instance type

### API Response Errors

- Verify API key is valid: `zeroclaw doctor`
- Check account balance
- Try switching provider or model

### Service Won't Start

```bash
# View detailed errors
journalctl --user -u zeroclaw.service --no-pager -n 50

# Confirm binary path
which zeroclaw

# Test manual execution
zeroclaw daemon
```

---

## Quick Checklist

```text
[ ] 1. Choose AWS Instance Type (recommended: t3.medium)
[ ] 2. Launch EC2 + configure Security Group
[ ] 3. SSH in + system update
[ ] 4. Install ZeroClaw (one-click or Docker)
[ ] 5. Sign up for LLM Provider + get API Key
[ ] 6. Create Telegram Bot via BotFather + get Token
[ ] 7. Get your Telegram User ID
[ ] 8. Edit ~/.zeroclaw/config.toml
[ ] 9. Bind Telegram Channel
[ ] 10. Start Daemon + test messaging
[ ] 11. Set up Systemd auto-start on boot
[ ] 12. Security hardening (allowlist / firewall / SSH)
[ ] 13. Verify: zeroclaw doctor + channel doctor
```
