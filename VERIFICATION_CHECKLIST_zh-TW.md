# ZeroClaw 部署後驗證清單

這份清單用於 **部署完成後、正式上線前** 的基礎自檢。它的目標是確認：

- Secret 沒有放錯位置
- 權限沒有設得太寬
- port 沒有多開
- systemd / Docker 的實際行為符合預期

這份文件偏向**營運驗收**；如果你要做對抗式驗證，請接著跑 [security-practice-guide/docs/Validation-Guide-zh-TW.md](security-practice-guide/docs/Validation-Guide-zh-TW.md)。

## 1. Repo 與 Secret 位置檢查

在 repo 根目錄執行：

```bash
git status --short --ignored
git ls-files | grep -E '(config\\.toml|runtime\\.env|docker\\.env|\\.env|\\.pem|\\.key)$' || true
```

預期結果：

- 真實的 `config.toml`、`runtime.env`、`docker.env`、`.env`、`*.pem`、`*.key` 不應該出現在 tracked files 中。
- Secret 檔案應該放在 `~/.zeroclaw/`、`~/.config/systemd/user/`、`~/zeroclaw-docker/` 這類私有路徑，而不是 repo 內。

## 2. 目錄與檔案權限檢查

```bash
stat -c '%a %n' ~/.zeroclaw ~/.ssh ~/.config/systemd/user 2>/dev/null || true
stat -c '%a %n' ~/.zeroclaw/config.toml ~/.zeroclaw/runtime.env ~/zeroclaw-docker/docker.env ~/your-ec2-key.pem 2>/dev/null || true
```

預期結果：

- 私有目錄是 `700`
- `config.toml`、`runtime.env`、`docker.env` 是 `600`
- SSH 私鑰 / `.pem` 是 `400` 或 `600`

## 3. 對外暴露面檢查

```bash
ss -ltn
sudo ufw status
```

預期結果：

- `42617` 沒有對整個網際網路暴露；若有使用 webhook，也應該是刻意配置
- `443` 只在你真的有反向代理 / TLS 時才開
- SSH 僅保留必要來源

## 4. Systemd 路徑驗證

如果你使用 systemd：

```bash
systemctl --user status zeroclaw.service --no-pager
journalctl --user -u zeroclaw.service -n 50 --no-pager
```

預期結果：

- 服務狀態為 `active (running)`
- 日誌中沒有反覆出現 `Permission denied`
- 日誌中沒有明文 API Key、Bot Token、助記詞、私鑰

## 5. Docker 路徑驗證

如果你使用 Docker：

```bash
cd ~/zeroclaw-docker
docker compose ps
docker compose logs --tail=50
```

預期結果：

- Container 狀態正常
- `config.toml` 以唯讀方式掛載
- 日誌中沒有明文 secret

## 6. ZeroClaw 功能檢查

```bash
zeroclaw --version
zeroclaw doctor
zeroclaw channel doctor
zeroclaw integrations info Telegram
```

預期結果：

- `doctor` 與 `channel doctor` 沒有阻斷性錯誤
- Telegram integration 狀態正常

## 7. Telegram Allowlist 檢查

手動驗證兩件事：

- allowlist 內的使用者能正常和 Bot 對話
- 非 allowlist 使用者無法驅動 Bot 執行高權限操作

如果你是在群組中使用，請確認 `mention_only` 的值符合你的預期。

## 8. 日誌與明文敏感資料抽查

```bash
tail -n 50 ~/.zeroclaw/logs/daemon.stdout.log 2>/dev/null || true
tail -n 50 ~/.zeroclaw/logs/daemon.stderr.log 2>/dev/null || true
cd ~/zeroclaw-docker 2>/dev/null && docker compose logs --tail=50 2>/dev/null || true
```

預期結果：

- 日誌中不應出現完整 API Key、完整 Bot Token、助記詞或鏈上私鑰
- 如果有把錯誤訊息發到外部系統，也要確認沒有把 secret 一起送出去

## 9. 最後簽核流程

依序完成：

1. 修掉這份清單裡任何一個未通過項目。
2. 記錄你刻意開放的 port、例外權限、部署方式。
3. 執行 [security-practice-guide/docs/Validation-Guide-zh-TW.md](security-practice-guide/docs/Validation-Guide-zh-TW.md) 做攻防驗證。
4. 再決定是否進正式上線。

## 10. 關於 nightly audit script 的說明

`security-practice-guide/scripts/nightly-security-audit.sh` 目前仍以 upstream OpenClaw 為主要參考，裡面使用的是 `openclaw` 指令與 `~/.openclaw` 路徑。

這代表：

- 它可以當作自動化巡檢設計的參考
- 但在直接套用到 ZeroClaw 前，應先做相容性調整與驗證
