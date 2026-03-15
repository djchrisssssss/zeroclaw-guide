# ZeroClaw 完整部署與安全指南

> ZeroClaw AI Agent 的一站式中文指南：從 AWS 開機到 Telegram 串接，再到 Agent 安全防護。

---

## 這個 Repo 包含什麼？

| 文件 | 說明 | 語言 |
|------|------|------|
| [SETUP_GUIDE.md](SETUP_GUIDE.md) | AWS 部署教學 — 硬體選擇、安裝、Telegram Bot、API 串接、Systemd、Docker | 繁體中文 |
| [security-practice-guide/](security-practice-guide/) | Agent 安全實踐指南 — 三層防禦矩陣、巡檢、災備、攻防演練 | 繁體中文 + English |

---

## 建議閱讀順序

```text
Step 1                        Step 2                         Step 3
┌─────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
│  SETUP_GUIDE.md │ ──▶ │  安全實踐指南         │ ──▶ │  攻防演練手冊         │
│                 │     │  (security-practice-  │     │  (Validation Guide)  │
│  AWS + 安裝     │     │   guide/)             │     │                      │
│  Telegram 串接  │     │  紅線/黃線規則        │     │  19 個測試用例        │
│  API 設定       │     │  權限收窄             │     │  驗證防禦是否生效     │
│  Daemon 啟動    │     │  每晚巡檢 13 項指標   │     │                      │
└─────────────────┘     └──────────────────────┘     └──────────────────────┘
```

---

## 快速開始

### 1. 部署 ZeroClaw 到 AWS

閱讀 **[SETUP_GUIDE.md](SETUP_GUIDE.md)**，涵蓋：

- AWS EC2 硬體選擇（`t3.medium` 推薦，約 $30/月）
- Ubuntu 環境設定與 ZeroClaw 安裝（一鍵安裝 / Source 編譯 / Docker）
- LLM Provider API 串接（OpenRouter / Anthropic / OpenAI）
- Telegram Bot 建立與綁定
- Systemd 開機自動啟動
- 安全性基礎設定（防火牆、SSH）

### 2. 套用安全防護

閱讀 **[security-practice-guide/](security-practice-guide/)**，涵蓋：

- **事前**：行為黑名單（紅線/黃線命令）+ Skill 安裝審計
- **事中**：權限收窄 + SHA256 雜湊基線 + 業務風控前置檢查
- **事後**：每晚自動巡檢 13 項核心指標 + Git 災備同步

### 3. 驗證防禦

閱讀 **[攻防演練手冊](security-practice-guide/docs/Validation-Guide-zh-TW.md)**，包含 19 個測試用例：

- 認知層注入防禦（供應鏈投毒、角色扮演越獄、編碼混淆）
- 主機提權與環境破壞（破壞性指令、資料外傳、後門植入）
- 業務風控（高危地址阻斷、私鑰洩露防護、簽名隔離）
- 審計追溯（腳本防篡改、日誌保護、災備連通性）

---

## 關於 ZeroClaw

[ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw) 是一個用 Rust 打造的輕量級 AI Agent Runtime：

- 單一 Binary，約 8.8MB，Runtime 記憶體 < 5MB
- 支援 40+ LLM Provider（OpenRouter、Anthropic、OpenAI、Ollama 等）
- 支援 Telegram / Discord / Slack / Matrix 等 Channel
- 跨架構：ARM、x86、RISC-V

---

## 致謝

安全實踐指南部分翻譯自 **SlowMist 慢霧安全團隊** 的開源專案：

- **原作倉庫**：[slowmist/openclaw-security-practice-guide](https://github.com/slowmist/openclaw-security-practice-guide)
- **原作者**：SlowMist Security Team ([@SlowMist_Team](https://x.com/SlowMist_Team))
- **貢獻者**：Edmund.X、zhixianio、Feng Liu
- **授權**：MIT License

---

## License

- 部署教學（SETUP_GUIDE.md）：本倉庫原創內容
- 安全實踐指南（security-practice-guide/）：遵循原作 [MIT License](security-practice-guide/LICENSE-slowmist)
