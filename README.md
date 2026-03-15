# ZeroClaw Deployment & Security Guide

**[繁體中文](#繁體中文) | [English](#english)**

---

## English

A secure-by-default guide for deploying **ZeroClaw AI Agent** on AWS with Telegram integration and agent-level security hardening.

### Security-First Rules

- Never place on-chain private keys or mnemonic phrases on the ZeroClaw host. The agent should only prepare unsigned calldata; signing must happen in an external wallet.
- Treat `config.toml`, bot tokens, API keys, `.env` files, and SSH keys as secrets. Create them with restrictive permissions and keep them out of git repositories.
- Do not expose gateway ports publicly unless you are intentionally running webhook mode.
- Read the setup guide's "Section 0" before following any install command.

### What's in This Repo?

| Document | Description |
|----------|-------------|
| [SETUP_GUIDE_en.md](SETUP_GUIDE_en.md) | AWS deployment — hardware, installation, Telegram Bot, API, Systemd, Docker |
| [VERIFICATION_CHECKLIST_en.md](VERIFICATION_CHECKLIST_en.md) | Post-deploy verification — permissions, secret placement, port exposure, service health |
| [security-practice-guide/](security-practice-guide/) | Agent security — 3-tier defense matrix, nightly audits, disaster recovery, red teaming |

### Recommended Reading Order

```text
Step 0                     Step 1                        Step 2                        Step 3                        Step 4
┌──────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐
│  Security        │  │  SETUP_GUIDE            │  │  Verification           │  │  Security Practice      │  │  Validation Guide       │
│  Assumptions     │  │                         │  │  Checklist              │  │  Guide                  │  │                         │
│  No private keys │──│  AWS + Install          │──│  Permissions            │──│  Red/Yellow line rules  │──│  19 test cases          │
│  No secret in git│  │  Telegram setup         │  │  Port exposure          │  │  Permission narrowing   │  │  Verify defenses work   │
│  Least privilege │  │  API config             │  │  Service health         │  │  13-metric nightly audit│  │                         │
│                  │  │  Daemon launch          │  │                         │  │  Git disaster recovery  │  │                         │
└──────────────────┘  └─────────────────────────┘  └─────────────────────────┘  └─────────────────────────┘  └─────────────────────────┘
```

### Quick Start

**0. Read the security assumptions first** — Start with Section 0 in [SETUP_GUIDE_en.md](SETUP_GUIDE_en.md)
- Never store blockchain private keys or mnemonics on this host
- Keep secrets outside git repositories and shell profiles
- Create secret files with restrictive permissions from the start

**1. Deploy ZeroClaw on AWS** — Read [SETUP_GUIDE_en.md](SETUP_GUIDE_en.md)
- EC2 hardware selection (`t3.medium` recommended, ~$30/mo)
- Ubuntu setup & ZeroClaw installation (one-click / source / Docker)
- LLM provider API (OpenRouter / Anthropic / OpenAI)
- Telegram Bot creation & binding
- Systemd auto-start & basic security (firewall, SSH)

**2. Run the post-deploy verification checklist** — Read [VERIFICATION_CHECKLIST_en.md](VERIFICATION_CHECKLIST_en.md)
- Confirm secrets are outside git and shell profiles
- Verify `700/600/400` permissions across directories, configs, and keys
- Confirm the expected ports, logs, and service/container health

**3. Apply Security Hardening** — Read [security-practice-guide/](security-practice-guide/)
- **Pre-action**: Behavior blacklists (red/yellow-line commands) + Skill audit
- **In-action**: Permission narrowing + SHA256 hash baseline + business risk control
- **Post-action**: Nightly audit covering 13 core metrics + Git disaster recovery

**4. Validate Defenses** — Read [Validation Guide](security-practice-guide/docs/Validation-Guide-en.md)
- Cognitive injection (supply chain poisoning, roleplay jailbreak, obfuscated payloads)
- Host exploitation (destructive commands, data exfiltration, persistence)
- Business risk control (high-risk address blocking, key leakage, signature isolation)
- Audit trail (script tampering, log protection, DR connectivity)

### About ZeroClaw

[ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw) is a lightweight Rust-based AI Agent runtime:

- Single binary ~8.8MB, runtime memory < 5MB
- 40+ LLM providers (OpenRouter, Anthropic, OpenAI, Ollama, etc.)
- Telegram / Discord / Slack / Matrix channels
- Cross-architecture: ARM, x86, RISC-V

---

## 繁體中文

ZeroClaw AI Agent 的 secure-by-default 一站式指南：從 AWS 部署到 Telegram 串接，再到 Agent 安全防護。

### 安全前提

- 不要把鏈上私鑰或助記詞放到 ZeroClaw 主機上。Agent 只負責準備未簽名交易資料，簽名必須在外部錢包完成。
- 把 `config.toml`、Bot Token、API Key、`.env`、SSH 金鑰都視為敏感資料；建立時就套最小權限，且不要放進 git repo。
- 除非你真的要跑 webhook，否則不要把 gateway port 對外公開。
- 開始執行任何安裝指令前，先看 setup guide 的「第 0 節」。

### 這個 Repo 包含什麼？

| 文件 | 說明 |
|------|------|
| [SETUP_GUIDE_zh-TW.md](SETUP_GUIDE_zh-TW.md) | AWS 部署教學 — 硬體選擇、安裝、Telegram Bot、API 串接、Systemd、Docker |
| [VERIFICATION_CHECKLIST_zh-TW.md](VERIFICATION_CHECKLIST_zh-TW.md) | 部署後驗證 — 權限、secret 位置、port 暴露、服務健康 |
| [security-practice-guide/](security-practice-guide/) | Agent 安全實踐指南 — 三層防禦矩陣、巡檢、災備、攻防演練 |

### 建議閱讀順序

```text
Step 0                     Step 1                        Step 2                        Step 3                        Step 4
┌──────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐
│  安全前提         │  │  部署教學               │  │  驗證清單               │  │  安全實踐指南            │  │  攻防演練手冊            │
│                  │  │                         │  │                         │  │                         │  │                         │
│  不落地私鑰      │──│  AWS + 安裝             │──│  權限與 secret          │──│  紅線/黃線規則           │──│  19 個測試用例           │
│  Secret 不進 git │  │  Telegram 串接          │  │  Port 與服務狀態        │  │  權限收窄               │  │  驗證防禦是否生效        │
│  最小權限        │  │  API 設定              │  │                         │  │  每晚巡檢 13 項指標      │  │                         │
│                  │  │  Daemon 啟動           │  │                         │  │  Git 災備同步            │  │                         │
└──────────────────┘  └─────────────────────────┘  └─────────────────────────┘  └─────────────────────────┘  └─────────────────────────┘
```

### 快速開始

**0. 先讀安全前提** — 從 [SETUP_GUIDE_zh-TW.md](SETUP_GUIDE_zh-TW.md) 的第 0 節開始
- 鏈上私鑰與助記詞永遠不要放在這台主機
- Secret 不要放進 git repo，也不要寫進 shell profile
- 敏感檔案建立時就套上最小權限

**1. 部署 ZeroClaw 到 AWS** — 閱讀 [SETUP_GUIDE_zh-TW.md](SETUP_GUIDE_zh-TW.md)
- AWS EC2 硬體選擇（`t3.medium` 推薦，約 $30/月）
- Ubuntu 環境設定與 ZeroClaw 安裝（一鍵安裝 / Source 編譯 / Docker）
- LLM Provider API 串接（OpenRouter / Anthropic / OpenAI）
- Telegram Bot 建立與綁定
- Systemd 開機自動啟動與安全性基礎設定（防火牆、SSH）

**2. 先做部署後驗證** — 閱讀 [VERIFICATION_CHECKLIST_zh-TW.md](VERIFICATION_CHECKLIST_zh-TW.md)
- 確認 secret 沒有進 repo 或 shell profile
- 驗證目錄、設定檔、金鑰的 `700/600/400` 權限
- 確認 port、日誌、服務／容器狀態符合預期

**3. 套用安全防護** — 閱讀 [security-practice-guide/](security-practice-guide/)
- **事前**：行為黑名單（紅線/黃線命令）+ Skill 安裝審計
- **事中**：權限收窄 + SHA256 雜湊基線 + 業務風控前置檢查
- **事後**：每晚自動巡檢 13 項核心指標 + Git 災備同步

**4. 驗證防禦** — 閱讀 [攻防演練手冊](security-practice-guide/docs/Validation-Guide-zh-TW.md)
- 認知層注入防禦（供應鏈投毒、角色扮演越獄、編碼混淆）
- 主機提權與環境破壞（破壞性指令、資料外傳、後門植入）
- 業務風控（高危地址阻斷、私鑰洩露防護、簽名隔離）
- 審計追溯（腳本防篡改、日誌保護、災備連通性）

### 關於 ZeroClaw

[ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw) 是一個用 Rust 打造的輕量級 AI Agent Runtime：

- 單一 Binary，約 8.8MB，Runtime 記憶體 < 5MB
- 支援 40+ LLM Provider（OpenRouter、Anthropic、OpenAI、Ollama 等）
- 支援 Telegram / Discord / Slack / Matrix 等 Channel
- 跨架構：ARM、x86、RISC-V

---

## Acknowledgments / 致謝

Security practice guide translated from **SlowMist Security Team**'s open-source project:

安全實踐指南翻譯自 **SlowMist 慢霧安全團隊** 的開源專案：

- **Source / 原作倉庫**: [slowmist/openclaw-security-practice-guide](https://github.com/slowmist/openclaw-security-practice-guide)
- **Authors / 原作者**: SlowMist Security Team ([@SlowMist_Team](https://x.com/SlowMist_Team))
- **Contributors / 貢獻者**: Edmund.X, zhixianio, Feng Liu
- **License / 授權**: MIT License

## License

- Deployment guide (SETUP_GUIDE): Original content in this repository
- Security practice guide: [MIT License](security-practice-guide/LICENSE-slowmist) (from SlowMist)
