# OpenClaw Security Practice Guide

**[繁體中文](#繁體中文) | [English](#english)**

---

## English

> Translated from [SlowMist Security Team](https://github.com/slowmist/openclaw-security-practice-guide)'s OpenClaw Security Practice Guide. Traditional Chinese content converted from Simplified Chinese using OpenCC.

### Original Authors

| | |
|---|---|
| **Source Repo** | [slowmist/openclaw-security-practice-guide](https://github.com/slowmist/openclaw-security-practice-guide) |
| **Authors** | SlowMist Security Team ([@SlowMist_Team](https://x.com/SlowMist_Team)) |
| **Contributors** | Edmund.X ([@leixing0309](https://x.com/leixing0309)), zhixianio ([@zhixianio](https://x.com/zhixianio)), Feng Liu ([@fishkiller](https://x.com/fishkiller)) |
| **License** | [MIT License](LICENSE-slowmist) |
| **Version** | v2.7 |

### What Is This?

A security practice framework for **high-privilege autonomous AI agents (ZeroClaw / OpenClaw)**. Transforms traditional "host-based static defense" into "Agentic Zero-Trust Architecture" to mitigate:

- Destructive operations (`rm -rf /`, etc.)
- Prompt Injection
- Supply Chain Poisoning
- High-risk business logic execution

### 3-Tier Defense Matrix

```text
Pre-action ─── Behavior blacklists (red/yellow lines) + Skill installation audit
 │
In-action ──── Permission narrowing + hash baseline + business risk pre-flight checks
 │
Post-action ── Nightly auto-audit (13 core metrics) + Git disaster recovery sync
```

### Documents

| Document | Language |
|----------|----------|
| [OpenClaw-Security-Practice-Guide.md](docs/OpenClaw-Security-Practice-Guide.md) | English |
| [OpenClaw 極簡安全實踐指南.md](docs/OpenClaw極簡安全實踐指南.md) | 繁體中文 |
| [Validation-Guide-en.md](docs/Validation-Guide-en.md) | English |
| [Validation-Guide-zh-TW.md](docs/Validation-Guide-zh-TW.md) | 繁體中文 |
| [nightly-security-audit.sh](scripts/nightly-security-audit.sh) | Bash script |

### How to Use with ZeroClaw

1. **Read** the [core guide](docs/OpenClaw-Security-Practice-Guide.md) to understand the defense architecture
2. **Send the guide to your AI Agent** and let it self-assess and deploy the defense matrix
3. **Run** the [Red Teaming Guide](docs/Validation-Guide-en.md) to verify defenses are working
4. **Pair with** the [ZeroClaw AWS Deployment Guide](../SETUP_GUIDE_en.md) for a complete zero-to-production flow

---

## 繁體中文

> 翻譯自 [SlowMist 慢霧安全團隊](https://github.com/slowmist/openclaw-security-practice-guide) 的 OpenClaw Security Practice Guide，所有簡體中文內容已使用 OpenCC 轉換為繁體中文。

### 原作資訊

| | |
|---|---|
| **原作倉庫** | [slowmist/openclaw-security-practice-guide](https://github.com/slowmist/openclaw-security-practice-guide) |
| **原作者** | SlowMist 慢霧安全團隊 ([@SlowMist_Team](https://x.com/SlowMist_Team)) |
| **貢獻者** | Edmund.X ([@leixing0309](https://x.com/leixing0309))、zhixianio ([@zhixianio](https://x.com/zhixianio))、Feng Liu ([@fishkiller](https://x.com/fishkiller)) |
| **原始授權** | [MIT License](LICENSE-slowmist) |
| **原始版本** | v2.7 |

### 這是什麼？

專為 **高權限自主智慧體（ZeroClaw / OpenClaw）** 設計的安全實踐框架。將傳統「主機靜態防禦」轉變為「智慧體零信任架構（Zero-Trust Architecture）」，有效應對：

- 破壞性操作（`rm -rf /` 等）
- 提示詞注入（Prompt Injection）
- 供應鏈投毒（Supply Chain Poisoning）
- 高危業務邏輯執行

### 三層防禦矩陣

```text
事前 ─── 行為黑名單（紅線/黃線）+ Skill 安裝安全審計
 │
事中 ─── 權限收窄 + 雜湊基線 + 業務風控前置檢查
 │
事後 ─── 每晚自動巡檢（13 項核心指標）+ Git 災備同步
```

### 文件一覽

| 文件 | 語言 |
|------|------|
| [OpenClaw 極簡安全實踐指南.md](docs/OpenClaw極簡安全實踐指南.md) | 繁體中文 |
| [OpenClaw-Security-Practice-Guide.md](docs/OpenClaw-Security-Practice-Guide.md) | English |
| [Validation-Guide-zh-TW.md](docs/Validation-Guide-zh-TW.md) | 繁體中文 |
| [Validation-Guide-en.md](docs/Validation-Guide-en.md) | English |
| [nightly-security-audit.sh](scripts/nightly-security-audit.sh) | Bash 腳本 |

### 如何搭配 ZeroClaw 使用

1. **閱讀** [核心指南（繁體中文）](docs/OpenClaw極簡安全實踐指南.md) 了解完整防禦架構
2. **將指南發送給你的 AI Agent**，讓它自行評估並部署防禦矩陣
3. **使用** [攻防演練手冊](docs/Validation-Guide-zh-TW.md) 驗證防禦是否生效
4. **搭配** [ZeroClaw AWS 部署指南](../SETUP_GUIDE_zh-TW.md) 完成從零到上線的完整流程

---

## License / 授權

This translation follows the original [MIT License](LICENSE-slowmist).

本繁體中文翻譯版遵循原作的 [MIT License](LICENSE-slowmist)。原作版權歸 SlowMist 慢霧安全團隊及其貢獻者所有。
