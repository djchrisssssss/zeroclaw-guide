# Secure Templates

These templates are meant to be copied into a **private path outside this git repository**.

Recommended locations:

- `~/.zeroclaw/config.toml`
- `~/.zeroclaw/runtime.env`
- `~/.config/systemd/user/zeroclaw.service`
- `~/zeroclaw-docker/docker-compose.yml`
- `~/zeroclaw-docker/docker.env`

Before creating any real secret file, tighten permissions first:

```bash
umask 077
mkdir -p ~/.zeroclaw ~/.config/systemd/user ~/zeroclaw-docker
chmod 700 ~/.zeroclaw ~/.config/systemd/user ~/zeroclaw-docker
```

Rules for these templates:

- Never place blockchain private keys or mnemonic phrases on the ZeroClaw host.
- Keep real API keys, bot tokens, and `.env` files out of git repositories.
- Use `600` for secret files and `700` for secret-bearing directories.
- Copy `.example` files to real filenames, then fill in only the values you actually need.
