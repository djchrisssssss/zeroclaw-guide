# OpenClaw 安全實踐指南（繁體中文版）

> 本指南翻譯自 SlowMist（慢霧）安全團隊的 OpenClaw Security Practice Guide，所有簡體中文內容已轉換為繁體中文。

---

## 原作資訊

| 項目 | 內容 |
|------|------|
| **原作倉庫** | [slowmist/openclaw-security-practice-guide](https://github.com/slowmist/openclaw-security-practice-guide) |
| **原作者** | SlowMist 慢霧安全團隊 ([@SlowMist_Team](https://x.com/SlowMist_Team)) |
| **貢獻者** | Edmund.X ([@leixing0309](https://x.com/leixing0309))、zhixianio ([@zhixianio](https://x.com/zhixianio))、Feng Liu ([@fishkiller](https://x.com/fishkiller)) |
| **原始授權** | [MIT License](LICENSE-slowmist) |
| **原始版本** | v2.7 |

---

## 這是什麼？

專為 **高權限自主智慧體（如 ZeroClaw / OpenClaw）** 設計的安全實踐框架。將傳統「主機靜態防禦」轉變為「智慧體零信任架構（Zero-Trust Architecture）」，有效應對：

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

---

## 檔案結構

```text
security-practice-guide/
├── README.md                              ← 你正在看的這個檔案
├── README_en.md                           ← 英文版 README
├── README_zh-TW.md                        ← 繁體中文版 README（完整版）
├── LICENSE-slowmist                       ← 原作 MIT 授權
├── docs/
│   ├── OpenClaw極簡安全實踐指南.md         ← 核心指南（繁體中文）
│   ├── OpenClaw-Security-Practice-Guide.md ← 核心指南（English）
│   ├── Validation-Guide-zh-TW.md          ← 攻防演練手冊（繁體中文）
│   └── Validation-Guide-en.md             ← 攻防演練手冊（English）
└── scripts/
    └── nightly-security-audit.sh          ← 每晚巡檢參考腳本
```

---

## 如何搭配 ZeroClaw 使用

本安全指南雖然是為 OpenClaw 編寫，但其核心安全理念同樣適用於 **ZeroClaw** 或任何高權限 AI Agent：

1. **閱讀** [核心指南（繁體中文）](docs/OpenClaw極簡安全實踐指南.md) 了解完整防禦架構
2. **將指南發送給你的 AI Agent**，讓它自行評估並部署防禦矩陣
3. **使用** [攻防演練手冊](docs/Validation-Guide-zh-TW.md) 驗證防禦是否生效
4. **搭配** [ZeroClaw AWS 部署指南](../SETUP_GUIDE.md) 完成從零到上線的完整流程

---

## 與 ZeroClaw 部署指南的關係

| 文件 | 用途 |
|------|------|
| [SETUP_GUIDE.md](../SETUP_GUIDE.md) | ZeroClaw 在 AWS 上的安裝、Telegram 串接、API 設定 |
| [security-practice-guide/](.) | Agent 運行後的安全防護、巡檢、災備 |

建議流程：**先完成部署 → 再套用安全指南 → 最後跑攻防演練驗證**

---

## 授權

本繁體中文翻譯版遵循原作的 [MIT License](LICENSE-slowmist)。

原作版權歸 SlowMist 慢霧安全團隊及其貢獻者所有。
