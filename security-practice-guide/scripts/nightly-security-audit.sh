#!/usr/bin/env bash
# OpenClaw 極簡安全實踐指南 v2.7 - 每晚全面安全巡檢指令碼
# 覆蓋 13 項核心指標；災備失敗不阻斷巡檢彙報

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
OC="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
REPORT_DIR="/tmp/openclaw/security-reports"
mkdir -p "$REPORT_DIR"

DATE_STR=$(date +%F)
REPORT_FILE="$REPORT_DIR/report-$DATE_STR.txt"
SUMMARY="🛡️ OpenClaw 每日安全巡檢簡報 ($DATE_STR)\n\n"

echo "=== OpenClaw Security Audit Detailed Report ($DATE_STR) ===" > "$REPORT_FILE"

append_warn() {
  SUMMARY+="$1\n"
}

# 1) OpenClaw 基礎審計
echo "[1/13] OpenClaw 基礎審計 (--deep)" >> "$REPORT_FILE"
if openclaw security audit --deep >> "$REPORT_FILE" 2>&1; then
  SUMMARY+="1. 平臺審計: ✅ 已執行原生掃描\n"
else
  append_warn "1. 平臺審計: ⚠️ 執行失敗（詳見詳細報告）"
fi

# 2) 程序與網路
echo -e "\n[2/13] 監聽埠與高資源程序" >> "$REPORT_FILE"
ss -tunlp >> "$REPORT_FILE" 2>/dev/null || true
top -b -n 1 | head -n 15 >> "$REPORT_FILE" 2>/dev/null || true
SUMMARY+="2. 程序網路: ✅ 已採集監聽埠與程序快照\n"

# 3) 敏感目錄變更
echo -e "\n[3/13] 敏感目錄近 24h 變更檔案數" >> "$REPORT_FILE"
MOD_FILES=$(find "$OC" /etc ~/.ssh ~/.gnupg /usr/local/bin -type f -mtime -1 2>/dev/null | wc -l | xargs)
echo "Total modified files: $MOD_FILES" >> "$REPORT_FILE"
SUMMARY+="3. 目錄變更: ✅ $MOD_FILES 個檔案 (位於 /etc/ 或 ~/.ssh 等)\n"

# 4) 系統定時任務
echo -e "\n[4/13] 系統級定時任務與 Systemd Timers" >> "$REPORT_FILE"
ls -la /etc/cron.* /var/spool/cron/crontabs/ >> "$REPORT_FILE" 2>/dev/null || true
systemctl list-timers --all >> "$REPORT_FILE" 2>/dev/null || true
if [ -d "$HOME/.config/systemd/user" ]; then
  ls -la "$HOME/.config/systemd/user" >> "$REPORT_FILE" 2>/dev/null || true
fi
SUMMARY+="4. 系統 Cron: ✅ 已採集系統級定時任務資訊\n"

# 5) OpenClaw 定時任務
echo -e "\n[5/13] OpenClaw Cron Jobs" >> "$REPORT_FILE"
if openclaw cron list >> "$REPORT_FILE" 2>&1; then
  SUMMARY+="5. 本地 Cron: ✅ 已拉取內部任務列表\n"
else
  append_warn "5. 本地 Cron: ⚠️ 拉取失敗（可能是 token/許可權問題）"
fi

# 6) 登入與 SSH 審計
echo -e "\n[6/13] 最近登入記錄與 SSH 失敗嘗試" >> "$REPORT_FILE"
last -a -n 5 >> "$REPORT_FILE" 2>/dev/null || true
FAILED_SSH=0
if command -v journalctl >/dev/null 2>&1; then
  FAILED_SSH=$(journalctl -u sshd --since "24 hours ago" 2>/dev/null | grep -Ei "Failed|Invalid" | wc -l | xargs)
fi
if [ "$FAILED_SSH" = "0" ]; then
  for LOGF in /var/log/auth.log /var/log/secure /var/log/messages; do
    if [ -f "$LOGF" ]; then
      FAILED_SSH=$(grep -Ei "sshd.*(Failed|Invalid)" "$LOGF" 2>/dev/null | tail -n 1000 | wc -l | xargs)
      break
    fi
  done
fi
echo "Failed SSH attempts (recent): $FAILED_SSH" >> "$REPORT_FILE"
SUMMARY+="6. SSH 安全: ✅ 近24h失敗嘗試 $FAILED_SSH 次\n"

# 7) 關鍵檔案完整性與許可權
echo -e "\n[7/13] 關鍵配置檔案許可權與雜湊基線" >> "$REPORT_FILE"
HASH_RES="MISSING_BASELINE"
if [ -f "$OC/.config-baseline.sha256" ]; then
  HASH_RES=$(cd "$OC" && sha256sum -c .config-baseline.sha256 2>&1 || true)
fi
echo "Hash Check: $HASH_RES" >> "$REPORT_FILE"
PERM_OC=$(stat -c "%a" "$OC/openclaw.json" 2>/dev/null || echo "MISSING")
PERM_PAIRED=$(stat -c "%a" "$OC/devices/paired.json" 2>/dev/null || echo "MISSING")
PERM_SSHD=$(stat -c "%a" /etc/ssh/sshd_config 2>/dev/null || echo "N/A")
PERM_AUTH_KEYS=$(stat -c "%a" "$HOME/.ssh/authorized_keys" 2>/dev/null || echo "N/A")
echo "Permissions: openclaw=$PERM_OC, paired=$PERM_PAIRED, sshd_config=$PERM_SSHD, authorized_keys=$PERM_AUTH_KEYS" >> "$REPORT_FILE"
if [[ "$HASH_RES" == *"OK"* ]] && [[ "$PERM_OC" == "600" ]]; then
  SUMMARY+="7. 配置基線: ✅ 雜湊校驗透過且許可權合規\n"
else
  append_warn "7. 配置基線: ⚠️ 基線缺失/校驗異常或許可權不合規"
fi

# 8) 黃線操作交叉驗證
echo -e "\n[8/13] 黃線操作對比 (sudo logs vs memory)" >> "$REPORT_FILE"
SUDO_COUNT=0
for LOGF in /var/log/auth.log /var/log/secure /var/log/messages; do
  if [ -f "$LOGF" ]; then
    SUDO_COUNT=$(grep -Ei "sudo.*COMMAND" "$LOGF" 2>/dev/null | tail -n 2000 | wc -l | xargs)
    break
  fi
done
MEM_FILE="$OC/workspace/memory/$DATE_STR.md"
MEM_COUNT=$(grep -i "sudo" "$MEM_FILE" 2>/dev/null | wc -l | xargs)
echo "Sudo Logs(recent): $SUDO_COUNT, Memory Logs(today): $MEM_COUNT" >> "$REPORT_FILE"
SUMMARY+="8. 黃線審計: ✅ sudo記錄=$SUDO_COUNT, memory記錄=$MEM_COUNT\n"

# 9) 磁碟使用
echo -e "\n[9/13] 磁碟使用率與最近大檔案" >> "$REPORT_FILE"
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
LARGE_FILES=$(find / -xdev -type f -size +100M -mtime -1 2>/dev/null | wc -l | xargs)
echo "Disk Usage: $DISK_USAGE, Large Files (>100M): $LARGE_FILES" >> "$REPORT_FILE"
SUMMARY+="9. 磁碟容量: ✅ 根分割槽佔用 $DISK_USAGE, 新增 $LARGE_FILES 個大檔案\n"

# 10) Gateway 環境變數
echo -e "\n[10/13] Gateway 環境變數洩露掃描" >> "$REPORT_FILE"
GW_PID=$(pgrep -f "openclaw-gateway" | head -n 1 || true)
if [ -n "$GW_PID" ] && [ -r "/proc/$GW_PID/environ" ]; then
  strings "/proc/$GW_PID/environ" | grep -iE 'SECRET|TOKEN|PASSWORD|KEY' | awk -F= '{print $1"=(Hidden)"}' >> "$REPORT_FILE" 2>/dev/null || true
  SUMMARY+="10. 環境變數: ✅ 已執行閘道器程序敏感變數名掃描\n"
else
  append_warn "10. 環境變數: ⚠️ 未定位到 openclaw-gateway 程序"
fi

# 11) 明文憑證洩露掃描 (DLP)
echo -e "\n[11/13] 明文私鑰/助記詞洩露掃描 (DLP)" >> "$REPORT_FILE"
SCAN_ROOT="$OC/workspace"
DLP_HITS=0
if [ -d "$SCAN_ROOT" ]; then
  # ETH private key-ish: 0x + 64 hex
  H1=$(grep -RInE --exclude-dir=.git --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.gif' --exclude='*.webp' '\b0x[a-fA-F0-9]{64}\b' "$SCAN_ROOT" 2>/dev/null | wc -l | xargs)
  # 12/24-word mnemonic-ish (rough heuristic)
  H2=$(grep -RInE --exclude-dir=.git --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.gif' --exclude='*.webp' '\b([a-z]{3,12}\s+){11}([a-z]{3,12})\b|\b([a-z]{3,12}\s+){23}([a-z]{3,12})\b' "$SCAN_ROOT" 2>/dev/null | wc -l | xargs)
  DLP_HITS=$((H1 + H2))
fi
echo "DLP hits (heuristic): $DLP_HITS" >> "$REPORT_FILE"
if [ "$DLP_HITS" -gt 0 ]; then
  append_warn "11. 敏感憑證掃描: ⚠️ 檢測到疑似明文敏感資訊($DLP_HITS)，請人工複核"
else
  SUMMARY+="11. 敏感憑證掃描: ✅ 未發現明顯私鑰/助記詞模式\n"
fi

# 12) Skill/MCP 完整性（基線diff）
echo -e "\n[12/13] Skill/MCP 完整性基線對比" >> "$REPORT_FILE"
SKILL_DIR="$OC/workspace/skills"
MCP_DIR="$OC/workspace/mcp"
HASH_DIR="$OC/security-baselines"
mkdir -p "$HASH_DIR"
CUR_HASH="$HASH_DIR/skill-mcp-current.sha256"
BASE_HASH="$HASH_DIR/skill-mcp-baseline.sha256"
: > "$CUR_HASH"
for D in "$SKILL_DIR" "$MCP_DIR"; do
  if [ -d "$D" ]; then
    find "$D" -type f -print0 2>/dev/null | sort -z | xargs -0 sha256sum 2>/dev/null >> "$CUR_HASH" || true
  fi
done
if [ -s "$CUR_HASH" ]; then
  if [ -f "$BASE_HASH" ]; then
    if diff -u "$BASE_HASH" "$CUR_HASH" >> "$REPORT_FILE" 2>&1; then
      SUMMARY+="12. Skill/MCP基線: ✅ 與上次基線一致\n"
    else
      append_warn "12. Skill/MCP基線: ⚠️ 檢測到檔案雜湊變化（詳見diff）"
    fi
  else
    cp "$CUR_HASH" "$BASE_HASH"
    SUMMARY+="12. Skill/MCP基線: ✅ 首次生成基線完成\n"
  fi
else
  SUMMARY+="12. Skill/MCP基線: ✅ 未發現skills/mcp目錄檔案\n"
fi

# 13) 大腦災備自動同步（失敗不阻斷）
echo -e "\n[13/13] 大腦災備 (Git Backup)" >> "$REPORT_FILE"
BACKUP_STATUS=""
if [ -d "$OC/.git" ]; then
  (
    cd "$OC" || exit 1
    git add . >> "$REPORT_FILE" 2>&1 || true
    if git diff --cached --quiet; then
      echo "No staged changes" >> "$REPORT_FILE"
      BACKUP_STATUS="skip"
    else
      if git commit -m "🛡️ Nightly brain backup ($DATE_STR)" >> "$REPORT_FILE" 2>&1 && git push origin main >> "$REPORT_FILE" 2>&1; then
        BACKUP_STATUS="ok"
      else
        BACKUP_STATUS="fail"
      fi
    fi
  )
else
  BACKUP_STATUS="nogit"
fi

case "$BACKUP_STATUS" in
  ok)   SUMMARY+="13. 災備備份: ✅ 已自動推送至遠端倉庫\n" ;;
  skip) SUMMARY+="13. 災備備份: ✅ 無新變更，跳過推送\n" ;;
  nogit) append_warn "13. 災備備份: ⚠️ 未初始化Git倉庫，已跳過" ;;
  *)    append_warn "13. 災備備份: ⚠️ 推送失敗（不影響本次巡檢）" ;;
esac

echo -e "$SUMMARY\n📝 詳細戰報已儲存本機: $REPORT_FILE"
exit 0
