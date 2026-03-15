# ZeroClaw AWS Deployment Guide

> Deploy ZeroClaw AI Assistant on AWS from scratch — Telegram Bot integration & LLM API setup.

> **Security Hardening**: After deployment, we strongly recommend applying the [OpenClaw Security Practice Guide](security-practice-guide/) to establish a 3-tier defense matrix for your Agent. Originally from [SlowMist Security Team](https://github.com/slowmist/openclaw-security-practice-guide).
>
> **繁體中文版**: [SETUP_GUIDE_zh-TW.md](SETUP_GUIDE_zh-TW.md)

> **Read these four rules first**:
> 1. **Do not place on-chain private keys or mnemonic phrases on this host.** The agent should only prepare unsigned transaction data; actual signing must happen in an independent wallet.
> 2. **Treat API keys, bot tokens, `config.toml`, `.env`, and `*.pem` files as secrets.**
> 3. **Do not store secrets in a git repo, `~/.bashrc`, or `~/.profile`.**
> 4. **Tighten permissions before creating secret files** with settings like `umask 077`, directory `700`, and file `600`.

---

## Table of Contents

0. [Pre-Deployment Security Assumptions](#0-pre-deployment-security-assumptions)
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

## 0. Pre-Deployment Security Assumptions

This guide assumes you are running ZeroClaw on a clean EC2 host, but **you are not storing blockchain private keys or mnemonic phrases on this machine**.

### 0.1 — Separate infrastructure keys from signing keys

- **SSH private keys / AWS `.pem` files**: used only to log in to the host and must have restricted permissions.
- **On-chain private keys / mnemonic phrases**: **must not live on this host** and must never be handled by the agent. Real signing should happen in an external wallet or hardware wallet.

### 0.2 — What counts as a secret

Treat all of the following as secrets:

- LLM API keys
- Telegram bot token
- `~/.zeroclaw/config.toml`
- Any runtime `.env` file used later in this guide
- `~/.ssh/id_rsa`
- `~/your-key.pem`

### 0.3 — Tighten permissions before creating secret files

```bash
umask 077
mkdir -p ~/.zeroclaw ~/.ssh
chmod 700 ~/.zeroclaw ~/.ssh
```

### 0.4 — Keep secrets out of git repos and shell profiles

- Do not place real API keys, bot tokens, `.env` files, or `config.toml` inside a git repository.
- Do not store long-lived secrets in `~/.bashrc` or `~/.profile`.
- For production, prefer a dedicated runtime env file, systemd `EnvironmentFile`, or AWS Secrets Manager / SSM Parameter Store.

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
| SSH | TCP | 22 | My IP | SSH access (required by default) |

Default to **SSH only**. Add other rules only when needed:

- `42617/tcp`: only if you intentionally run webhook mode, ideally behind a reverse proxy or with restricted source ranges.
- `443/tcp`: only after you have a reverse proxy / TLS setup ready.

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

> **Security note**: the `zeroclaw onboard --api-key ...` commands below are acceptable for temporary testing, but for long-running deployments prefer a dedicated runtime env file instead of storing secrets in shell profiles or repos.

### Option 1: OpenRouter (Recommended — multi-model access)

1. Sign up at [openrouter.ai](https://openrouter.ai/)
2. Go to Dashboard → API Keys → Create new API Key
3. Configure ZeroClaw:

```bash
zeroclaw onboard --api-key <YOUR_OPENROUTER_API_KEY> --provider openrouter --model "openrouter/auto"
```

### Option 2: Anthropic (Claude series)

1. Get an API Key from [console.anthropic.com](https://console.anthropic.com/)
2. Configure:

```bash
zeroclaw onboard --api-key <YOUR_ANTHROPIC_API_KEY> --provider anthropic --model "anthropic/claude-sonnet-4-6"
```

### Option 3: OpenAI

1. Get an API Key from [platform.openai.com](https://platform.openai.com/)
2. Configure:

```bash
zeroclaw onboard --api-key <YOUR_OPENAI_API_KEY> --provider openai
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
umask 077
mkdir -p ~/.zeroclaw
chmod 700 ~/.zeroclaw
install -m 600 /dev/null ~/.zeroclaw/config.toml
nano ~/.zeroclaw/config.toml
```

> **Note**: `config.toml` can contain bot tokens and other sensitive settings. Keep it in a private path under your home directory, not inside a git repo.

### Step 7.2 — Full Configuration Example

```toml
# =========================
# ZeroClaw Main Settings
# =========================

# LLM Provider
default_provider = "openrouter"          # or "anthropic", "openai", etc.
# Prefer a dedicated runtime env file for API keys instead of a shell profile
# api_key = "<YOUR_API_KEY>"

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
bot_token = "<YOUR_TELEGRAM_BOT_TOKEN>"  # Token from BotFather

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

If you prefer not to store API keys in config.toml, you can test with a **current shell session only**:

```bash
# Temporary for the current shell session only; do not add to ~/.bashrc or ~/.profile
export OPENROUTER_API_KEY="<YOUR_OPENROUTER_API_KEY>"
# or
export ANTHROPIC_API_KEY="<YOUR_ANTHROPIC_API_KEY>"
# or
export OPENAI_API_KEY="<YOUR_OPENAI_API_KEY>"
```

For long-running deployments, switch to a dedicated runtime env file with systemd `EnvironmentFile`, or use AWS Secrets Manager / SSM Parameter Store.

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
install -d -m 700 ~/.zeroclaw/logs
nohup zeroclaw daemon > ~/.zeroclaw/logs/daemon.stdout.log 2> ~/.zeroclaw/logs/daemon.stderr.log &
```

---

## 10. Systemd Auto-Start on Boot

### Method A: Built-in Command (Quick Validation)

```bash
zeroclaw service install
zeroclaw service start
zeroclaw service status
```

### Method B: Hardened Systemd Template (Recommended for Production)

These commands assume you are running them from the root of this repository:

```bash
install -d -m 700 ~/.config/systemd/user ~/.zeroclaw ~/.zeroclaw/logs
install -m 600 templates/runtime.env.example ~/.zeroclaw/runtime.env
install -m 600 templates/zeroclaw.service.example ~/.config/systemd/user/zeroclaw.service

# Fill in your real API key
nano ~/.zeroclaw/runtime.env

# Confirm ExecStart if your zeroclaw binary lives elsewhere
nano ~/.config/systemd/user/zeroclaw.service
```

```bash
# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now zeroclaw.service

# Enable linger so service runs without login
sudo loginctl enable-linger ubuntu

# Check status
systemctl --user status zeroclaw.service
```

`templates/zeroclaw.service.example` already includes safer defaults such as `UMask=0077`, `NoNewPrivileges=yes`, `ProtectSystem=strict`, and `ReadWritePaths=%h/.zeroclaw`.

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

These commands assume you are running them from the root of this repository:

```bash
install -d -m 700 ~/zeroclaw-docker
cp templates/docker-compose.example.yml ~/zeroclaw-docker/docker-compose.yml
install -m 600 templates/docker.env.example ~/zeroclaw-docker/docker.env
install -m 600 templates/config.toml.example ~/zeroclaw-docker/config.toml
```

### Step 11.3 — Edit Docker Secret Files

```bash
nano ~/zeroclaw-docker/docker.env
nano ~/zeroclaw-docker/config.toml
```

The default template binds the port to `127.0.0.1:42617`. If you only use Telegram polling, you usually do not need any extra public inbound rule.

### Step 11.4 — Start

```bash
cd ~/zeroclaw-docker
docker compose up -d
docker compose ps
docker compose logs -f
```

`templates/docker-compose.example.yml` already applies `read_only: true`, `cap_drop: [ALL]`, `no-new-privileges`, and a read-only bind mount for `config.toml`.

---

## 12. Security Hardening

### 12.1 — Telegram Allowlist

**Never** use `allowed_users = ["*"]` in production. Only allow specific User IDs:

```toml
[channels_config.telegram]
allowed_users = ["123456789", "987654321"]   # Only these users can interact
```

### 12.2 — Minimize AWS Security Group

- Default to SSH only, restricted to your IP
- Open `443/tcp` only after your reverse proxy / TLS layer is ready
- Open `42617/tcp` only when webhook mode truly needs it, and avoid exposing it broadly to the internet
- Review Security Group rules regularly

### 12.3 — API Key Security

- Never hardcode API keys in source code
- Prefer a dedicated runtime env file (`600`) or AWS Secrets Manager
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
# If reverse proxy needed: sudo ufw allow 443/tcp
# If webhook gateway needed: sudo ufw allow 42617/tcp
sudo ufw enable
```

### 12.5 — SSH Key Authentication

Ensure only key authentication is used; disable password login:

```bash
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### 12.6 — File Permission Best Practices

Use `600` for config files that need read/write, `700` for private directories, and `400` for read-only credentials:

```bash
# Private directories → 700
chmod 700 ~/.zeroclaw
chmod 700 ~/.ssh
chmod 700 ~/.config/systemd/user

# Config files (read/write) → 600
chmod 600 ~/.zeroclaw/config.toml
chmod 600 ~/.zeroclaw/runtime.env
chmod 600 ~/zeroclaw-docker/docker.env

# SSH private keys (read-only) → 400
chmod 400 ~/.ssh/id_rsa
chmod 400 ~/your-ec2-key.pem
```

> **Troubleshooting Permission Errors**:
> - `Permission denied` on startup → Check file owner matches the daemon user: `ls -la ~/.zeroclaw/config.toml`
> - SSH rejects key (`Permissions are too open`) → Private keys must be `400` or `600`, never `644` or `755`
> - Running with `sudo` but files owned by regular user → Either `sudo chown root:root` or stop using sudo
>
> See the [Security Practice Guide](security-practice-guide/docs/OpenClaw-Security-Practice-Guide.md#a-permission-narrowing-restrict-access-scope) for a complete file-by-file permission reference.

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
