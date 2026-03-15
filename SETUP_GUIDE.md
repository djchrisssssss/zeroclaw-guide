# ZeroClaw AWS 部署完整指南

> 從零開始在 AWS 上部署 ZeroClaw AI Assistant，串接 Telegram Bot 與 LLM API。

> **安全防護**：部署完成後，強烈建議參考 [OpenClaw 安全實踐指南（繁體中文）](security-practice-guide/) 為你的 Agent 建立三層防禦矩陣。
> 原作來自 [SlowMist 慢霧安全團隊](https://github.com/slowmist/openclaw-security-practice-guide)。

---

## 目錄

1. [AWS 硬體選擇](#1-aws-硬體選擇)
2. [啟動 EC2 Instance](#2-啟動-ec2-instance)
3. [連線與基礎環境設定](#3-連線與基礎環境設定)
4. [安裝 ZeroClaw](#4-安裝-zeroclaw)
5. [設定 LLM Provider API](#5-設定-llm-provider-api)
6. [建立 Telegram Bot](#6-建立-telegram-bot)
7. [設定 ZeroClaw 組態檔](#7-設定-zeroclaw-組態檔)
8. [綁定 Telegram Channel](#8-綁定-telegram-channel)
9. [啟動 Daemon 服務](#9-啟動-daemon-服務)
10. [設定 Systemd 開機自動啟動](#10-設定-systemd-開機自動啟動)
11. [Docker 部署方式（替代方案）](#11-docker-部署方式替代方案)
12. [安全性強化](#12-安全性強化)
13. [監控與維護](#13-監控與維護)
14. [疑難排解](#14-疑難排解)

---

## 1. AWS 硬體選擇

ZeroClaw 是 Rust 編寫的輕量 binary（約 8.8MB），runtime 記憶體不到 5MB。但**編譯時**需要較多資源。

### 推薦方案

| 用途 | Instance Type | vCPU | RAM | 儲存空間 | 月費估算 (us-east-1) |
|------|--------------|------|-----|---------|---------------------|
| **推薦：從 source 編譯 + 運行** | `t3.medium` | 2 | 4 GB | 20 GB gp3 | ~$30/月 |
| 最低：使用 pre-built binary | `t3.micro` | 2 | 1 GB | 10 GB gp3 | ~$8/月 |
| 進階：多 channel + 高併發 | `t3.large` | 2 | 8 GB | 30 GB gp3 | ~$60/月 |

### 選擇建議

- **架構**：選擇 `x86_64 (amd64)` 或 `arm64 (Graviton)` 皆可，ZeroClaw 兩者都支援
- **ARM Graviton（如 `t4g.medium`）** 通常比 x86 便宜 20%，效能相當
- **儲存**：gp3 即可，不需要 io2
- **如果只是跑 pre-built binary**，`t3.micro`（Free Tier）就足夠

---

## 2. 啟動 EC2 Instance

### Step 2.1 — 登入 AWS Console

前往 [AWS Console](https://console.aws.amazon.com/) → EC2 → Launch Instance

### Step 2.2 — 設定 Instance

| 設定項目 | 建議值 |
|---------|--------|
| Name | `zeroclaw-bot` |
| AMI | **Ubuntu 24.04 LTS** (HVM, SSD Volume Type) |
| Architecture | 64-bit (x86) 或 64-bit (Arm) |
| Instance type | `t3.medium`（編譯用）或 `t3.micro`（binary 安裝） |
| Key pair | 建立新的或使用既有的 `.pem` key |
| Storage | 20 GB gp3 |

### Step 2.3 — 設定 Security Group

建立新的 Security Group `zeroclaw-sg`：

| 類型 | 協定 | Port | 來源 | 用途 |
|------|------|------|------|------|
| SSH | TCP | 22 | 你的 IP（My IP） | SSH 連線 |
| Custom TCP | TCP | 42617 | 0.0.0.0/0 | ZeroClaw Gateway（如需外部 webhook） |
| HTTPS | TCP | 443 | 0.0.0.0/0 | 反向代理（選用） |

> **注意**：如果只用 Telegram polling 模式，不需要開 42617 port。只有使用 webhook 時才需要。

### Step 2.4 — 啟動並記錄

點擊 **Launch Instance**，記下：
- Instance ID
- Public IP 或 Elastic IP（建議分配 Elastic IP 避免重啟後 IP 變動）

---

## 3. 連線與基礎環境設定

### Step 3.1 — SSH 連線

```bash
chmod 400 ~/your-key.pem
ssh -i ~/your-key.pem ubuntu@<YOUR_EC2_PUBLIC_IP>
```

### Step 3.2 — 系統更新與基礎套件

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential pkg-config libssl-dev git curl
```

### Step 3.3 — 安裝 Rust（僅從 source 編譯時需要）

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustc --version  # 確認安裝成功
```

### Step 3.4 — 設定 Swap（t3.medium 建議）

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 4. 安裝 ZeroClaw

### 方法 A：一鍵安裝（推薦）

```bash
curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash
```

如果是低規格機器，使用 pre-built binary：

```bash
curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash -s -- \
  --prefer-prebuilt \
  --install-system-deps \
  --install-rust
```

### 方法 B：從 Source 編譯

```bash
git clone https://github.com/zeroclaw-labs/zeroclaw.git
cd zeroclaw
cargo build --release --locked
cargo install --path . --force --locked
export PATH="$HOME/.cargo/bin:$PATH"
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
```

### 方法 C：下載 Pre-built Binary

```bash
# 根據你的架構選擇（x86_64 或 aarch64）
# 前往 https://github.com/zeroclaw-labs/zeroclaw/releases/latest 下載對應版本
# 範例：
wget https://github.com/zeroclaw-labs/zeroclaw/releases/latest/download/zeroclaw-linux-x86_64 -O zeroclaw
chmod +x zeroclaw
sudo mv zeroclaw /usr/local/bin/
```

### 驗證安裝

```bash
zeroclaw --version
zeroclaw doctor
```

---

## 5. 設定 LLM Provider API

ZeroClaw 支援 40+ 個 LLM provider。以下列出常見選項：

### 選項一：OpenRouter（推薦，多模型選擇）

1. 前往 [openrouter.ai](https://openrouter.ai/) 註冊帳號
2. 在 Dashboard → API Keys 建立新的 API Key
3. 設定 ZeroClaw：

```bash
zeroclaw onboard --api-key sk-or-v1-xxxx --provider openrouter --model "openrouter/auto"
```

### 選項二：Anthropic（Claude 系列）

1. 前往 [console.anthropic.com](https://console.anthropic.com/) 取得 API Key
2. 設定：

```bash
zeroclaw onboard --api-key sk-ant-xxxx --provider anthropic --model "anthropic/claude-sonnet-4-6"
```

### 選項三：OpenAI

1. 前往 [platform.openai.com](https://platform.openai.com/) 取得 API Key
2. 設定：

```bash
zeroclaw onboard --api-key sk-xxxx --provider openai
```

### 選項四：使用已有的 Claude Code / ChatGPT 訂閱

**Claude Code 訂閱：**
```bash
zeroclaw auth paste-token --provider anthropic --profile default --auth-kind authorization
```

**ChatGPT 訂閱：**
```bash
zeroclaw auth login --provider openai-codex --device-code
```

### 驗證 Provider 連線

```bash
zeroclaw agent -m "Hello, are you working?"
```

---

## 6. 建立 Telegram Bot

### Step 6.1 — 在 Telegram 上建立 Bot

1. 開啟 Telegram，搜尋 **@BotFather**
2. 輸入 `/newbot`
3. 依照提示設定：
   - **Bot 名稱**（顯示名稱）：例如 `ZeroClaw Assistant`
   - **Bot 用戶名**（唯一 ID）：例如 `my_zeroclaw_bot`（必須以 `bot` 結尾）
4. BotFather 會回覆一個 **Bot Token**，格式如：
   ```
   123456789:ABCdefGHIjklMNOpqrsTUVwxyz
   ```
5. **妥善保存此 Token**，不要外洩

### Step 6.2 — 設定 Bot 基本資訊（選用）

在 BotFather 中：
- `/setdescription` — 設定 Bot 描述
- `/setabouttext` — 設定關於文字
- `/setuserpic` — 設定 Bot 頭像
- `/setcommands` — 設定指令選單

### Step 6.3 — 取得你的 Telegram User ID

1. 搜尋 **@userinfobot** 或 **@raw_data_bot**
2. 向它發送任意訊息
3. 它會回覆你的 **User ID**（純數字），例如 `123456789`
4. 記下此 ID，稍後用於 allowlist

---

## 7. 設定 ZeroClaw 組態檔

### Step 7.1 — 編輯 config.toml

```bash
mkdir -p ~/.zeroclaw
nano ~/.zeroclaw/config.toml
```

### Step 7.2 — 完整組態範例

```toml
# =========================
# ZeroClaw 主要設定
# =========================

# LLM Provider 設定
default_provider = "openrouter"          # 或 "anthropic", "openai" 等
api_key = "sk-or-v1-your-api-key-here"   # 你的 API Key

# 模型選擇（選用，不設定則用 provider 預設）
# model = "openrouter/auto"
# model = "anthropic/claude-sonnet-4-6"

# Gateway 設定
# gateway_port = 42617
# gateway_host = "127.0.0.1"

# =========================
# Telegram Channel 設定
# =========================
[channels_config.telegram]
bot_token = "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"   # 從 BotFather 取得的 Token

# 允許與 Bot 互動的用戶
# "*" = 所有人都可以使用（不建議用於生產環境）
# 建議設定特定 User ID
allowed_users = ["123456789"]            # 你的 Telegram User ID

# 串流模式：off | partial
stream_mode = "partial"                  # 啟用部分串流，可即時看到回覆

# 串流更新間隔（毫秒）
draft_update_interval_ms = 1000

# 群組中是否需要 @mention 才回應
mention_only = false

# 是否在收到新訊息時中斷進行中的回覆
interrupt_on_new_message = false
```

### Step 7.3 — 設定環境變數（替代方案）

如果不想把 API Key 寫在 config.toml 裡，可以用環境變數：

```bash
# 加到 ~/.bashrc 或 ~/.profile
export OPENROUTER_API_KEY="sk-or-v1-xxxx"
# 或
export ANTHROPIC_API_KEY="sk-ant-xxxx"
# 或
export OPENAI_API_KEY="sk-xxxx"
```

---

## 8. 綁定 Telegram Channel

### Step 8.1 — 綁定

```bash
zeroclaw channel bind-telegram <YOUR_TELEGRAM_USER_ID>
```

### Step 8.2 — 驗證綁定

```bash
zeroclaw integrations info Telegram
zeroclaw channel doctor
```

### Step 8.3 — 測試

先手動啟動 daemon 測試：

```bash
zeroclaw daemon
```

然後到 Telegram 向你的 Bot 發送訊息，確認收到回覆。

用 `Ctrl+C` 停止 daemon。

---

## 9. 啟動 Daemon 服務

### 前景執行（測試用）

```bash
zeroclaw daemon
```

### 背景執行

```bash
nohup zeroclaw daemon > ~/.zeroclaw/logs/daemon.stdout.log 2> ~/.zeroclaw/logs/daemon.stderr.log &
```

---

## 10. 設定 Systemd 開機自動啟動

### 方法 A：使用內建指令（推薦）

```bash
zeroclaw service install
zeroclaw service start
zeroclaw service status
```

### 方法 B：手動建立 Systemd User Service

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

# 如果使用環境變數存放 API Key
# EnvironmentFile=%h/.zeroclaw/.env

# Logging
StandardOutput=append:%h/.zeroclaw/logs/daemon.stdout.log
StandardError=append:%h/.zeroclaw/logs/daemon.stderr.log

[Install]
WantedBy=default.target
EOF
```

```bash
# 啟用並啟動
systemctl --user daemon-reload
systemctl --user enable zeroclaw.service
systemctl --user start zeroclaw.service

# 確保用戶 linger（開機不登入也能執行）
sudo loginctl enable-linger ubuntu

# 確認狀態
systemctl --user status zeroclaw.service
```

### 查看日誌

```bash
journalctl --user -u zeroclaw.service -f
```

---

## 11. Docker 部署方式（替代方案）

如果偏好使用 Docker，可以跳過 Steps 3-10，直接用 Docker Compose。

### Step 11.1 — 安裝 Docker

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker ubuntu
newgrp docker
```

### Step 11.2 — 建立 docker-compose.yml

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

### Step 11.3 — 建立 .env 檔案

```bash
cat > .env << 'EOF'
API_KEY=sk-or-v1-your-api-key-here
PROVIDER=openrouter
ZEROCLAW_MODEL=openrouter/auto
HOST_PORT=42617
EOF
```

### Step 11.4 — 啟動

```bash
docker compose up -d
docker compose logs -f
```

> **注意**：Docker 模式下的 Telegram 設定需要透過掛載 config.toml 或進入 container 設定。建議掛載設定檔：
>
> ```yaml
> volumes:
>   - zeroclaw-data:/zeroclaw-data
>   - ./config.toml:/root/.zeroclaw/config.toml:ro
> ```

---

## 12. 安全性強化

### 12.1 — Telegram Allowlist

**永遠不要**在生產環境使用 `allowed_users = ["*"]`。只允許特定 User ID：

```toml
[channels_config.telegram]
allowed_users = ["123456789", "987654321"]   # 只有這些用戶可以互動
```

### 12.2 — AWS Security Group 最小化

- SSH：限制為你的 IP
- 如不需要 webhook，不要開放 42617 port
- 定期檢查 Security Group 規則

### 12.3 — API Key 安全

- 不要把 API Key 硬編碼在程式碼中
- 使用環境變數或 AWS Secrets Manager
- 定期輪換 API Key

### 12.4 — 系統安全

```bash
# 啟用自動安全更新
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# 設定防火牆
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
# 如需 gateway: sudo ufw allow 42617/tcp
sudo ufw enable
```

### 12.5 — SSH 金鑰認證

確保只使用金鑰認證，停用密碼登入：

```bash
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

---

## 13. 監控與維護

### 健康檢查指令

```bash
zeroclaw status          # Runtime 狀態總覽
zeroclaw doctor          # 組態驗證
zeroclaw channel doctor  # Channel 連線檢查
```

### 日誌查看

```bash
# Systemd
journalctl --user -u zeroclaw.service -f

# 直接日誌檔
tail -f ~/.zeroclaw/logs/daemon.stdout.log
tail -f ~/.zeroclaw/logs/daemon.stderr.log

# Docker
docker compose logs -f zeroclaw
```

### Daemon 狀態追蹤

```bash
cat ~/.zeroclaw/daemon_state.json
```

### 更新 ZeroClaw

```bash
# 如果用 install.sh 安裝
curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/master/install.sh | bash -s -- --prefer-prebuilt

# 如果從 source 編譯
cd ~/zeroclaw
git pull
cargo build --release --locked
cargo install --path . --force --locked

# 重啟服務
systemctl --user restart zeroclaw.service
# 或 Docker
docker compose pull && docker compose up -d
```

### 變更管理流程

1. 備份現有組態：`cp ~/.zeroclaw/config.toml ~/.zeroclaw/config.toml.bak`
2. 進行單一變更
3. 驗證：`zeroclaw doctor`
4. 重啟 daemon
5. 確認健康檢查通過

---

## 14. 疑難排解

### Bot 沒有回應

1. 確認 daemon 正在運行：`zeroclaw status`
2. 確認 Telegram Token 正確：`zeroclaw channel doctor`
3. 確認你的 User ID 在 `allowed_users` 中
4. 查看日誌是否有錯誤

### 編譯失敗 / OOM

- 增加 swap space（見 Step 3.4）
- 使用 pre-built binary 替代編譯
- 升級到更大的 instance type

### API 回應錯誤

- 確認 API Key 有效：`zeroclaw doctor`
- 確認帳戶餘額充足
- 嘗試切換 provider 或 model

### 服務無法啟動

```bash
# 查看詳細錯誤
journalctl --user -u zeroclaw.service --no-pager -n 50

# 確認 binary 路徑
which zeroclaw

# 手動執行測試
zeroclaw daemon
```

---

## 快速操作清單

```text
[ ] 1. 選擇 AWS Instance Type（建議 t3.medium）
[ ] 2. 啟動 EC2 + 設定 Security Group
[ ] 3. SSH 連線 + 系統更新
[ ] 4. 安裝 ZeroClaw（一鍵安裝或 Docker）
[ ] 5. 註冊 LLM Provider + 取得 API Key
[ ] 6. 在 BotFather 建立 Telegram Bot + 取得 Token
[ ] 7. 取得你的 Telegram User ID
[ ] 8. 編輯 ~/.zeroclaw/config.toml
[ ] 9. 綁定 Telegram Channel
[ ] 10. 啟動 Daemon + 測試訊息
[ ] 11. 設定 Systemd 開機自動啟動
[ ] 12. 安全性強化（allowlist / firewall / SSH）
[ ] 13. 驗證 zeroclaw doctor + channel doctor
```
