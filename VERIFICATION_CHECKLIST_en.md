# ZeroClaw Post-Deployment Verification Checklist

Use this checklist **after deployment and before calling the system production-ready**. The goal is to confirm:

- secrets are stored in the right place
- permissions are not overly broad
- unnecessary ports are not exposed
- systemd / Docker behavior matches your expectations

This document is for **operational verification**. For adversarial testing, continue with [security-practice-guide/docs/Validation-Guide-en.md](security-practice-guide/docs/Validation-Guide-en.md).

## 1. Check Repo Hygiene and Secret Placement

Run from the repository root:

```bash
git status --short --ignored
git ls-files | grep -E '(config\\.toml|runtime\\.env|docker\\.env|\\.env|\\.pem|\\.key)$' || true
```

Expected result:

- Real `config.toml`, `runtime.env`, `docker.env`, `.env`, `*.pem`, and `*.key` files should not appear in tracked files.
- Secret files should live in private paths like `~/.zeroclaw/`, `~/.config/systemd/user/`, or `~/zeroclaw-docker/`, not inside the repo.

## 2. Check Directory and File Permissions

```bash
stat -c '%a %n' ~/.zeroclaw ~/.ssh ~/.config/systemd/user 2>/dev/null || true
stat -c '%a %n' ~/.zeroclaw/config.toml ~/.zeroclaw/runtime.env ~/zeroclaw-docker/docker.env ~/your-ec2-key.pem 2>/dev/null || true
```

Expected result:

- private directories are `700`
- `config.toml`, `runtime.env`, and `docker.env` are `600`
- SSH private keys / `.pem` files are `400` or `600`

## 3. Check External Exposure

```bash
ss -ltn
sudo ufw status
```

Expected result:

- `42617` is not broadly exposed to the internet; if webhook mode is enabled, the exposure is intentional
- `443` is only open if you intentionally configured reverse proxy / TLS
- SSH is restricted to the minimal source range you need

## 4. Validate the Systemd Path

If you use systemd:

```bash
systemctl --user status zeroclaw.service --no-pager
journalctl --user -u zeroclaw.service -n 50 --no-pager
```

Expected result:

- the service is `active (running)`
- logs do not show repeated `Permission denied` errors
- logs do not contain plaintext API keys, bot tokens, mnemonics, or private keys

## 5. Validate the Docker Path

If you use Docker:

```bash
cd ~/zeroclaw-docker
docker compose ps
docker compose logs --tail=50
```

Expected result:

- the container is healthy
- `config.toml` is mounted read-only
- logs do not contain plaintext secrets

## 6. Check ZeroClaw Functionality

```bash
zeroclaw --version
zeroclaw doctor
zeroclaw channel doctor
zeroclaw integrations info Telegram
```

Expected result:

- `doctor` and `channel doctor` do not report blocking failures
- the Telegram integration is healthy

## 7. Check Telegram Allowlist Behavior

Manually verify both of these:

- an allowlisted user can talk to the bot successfully
- a non-allowlisted user cannot drive privileged bot behavior

If you use the bot in groups, confirm that `mention_only` matches your intended behavior.

## 8. Spot-Check Logs for Plaintext Secret Exposure

```bash
tail -n 50 ~/.zeroclaw/logs/daemon.stdout.log 2>/dev/null || true
tail -n 50 ~/.zeroclaw/logs/daemon.stderr.log 2>/dev/null || true
cd ~/zeroclaw-docker 2>/dev/null && docker compose logs --tail=50 2>/dev/null || true
```

Expected result:

- logs should not contain full API keys, full bot tokens, mnemonics, or blockchain private keys
- if you forward errors elsewhere, confirm no secrets are sent with them

## 9. Final Sign-Off Flow

Complete these in order:

1. Fix every failed item in this checklist.
2. Record any intentional exceptions such as open ports, relaxed permissions, or deployment-specific tradeoffs.
3. Run [security-practice-guide/docs/Validation-Guide-en.md](security-practice-guide/docs/Validation-Guide-en.md) for adversarial testing.
4. Only then decide whether the deployment is ready for production.

## 10. Note on the Nightly Audit Script

`security-practice-guide/scripts/nightly-security-audit.sh` is still primarily aligned with upstream OpenClaw and currently references the `openclaw` command and `~/.openclaw` paths.

That means:

- it is useful as a design reference for future automation
- but it should be adapted and re-validated before being used as a drop-in ZeroClaw audit script
