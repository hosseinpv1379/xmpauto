# xmpauto

Ready-to-use scripts for **XMPlus** installation and **6to4/GRE6** tunnel setup on Linux servers (Iran and foreign).

---

## Table of Contents

- [Introduction](#introduction)
- [Repository Structure](#repository-structure)
- [1. XMPlus Setup](#1-xmplus-setup)
- [2. 6to4 + GRE6 Tunnel](#2-6to4--gre6-tunnel)
- [Troubleshooting](#troubleshooting)
- [Command Summary](#command-summary)
- [License](#license)

---

## Introduction

This repository contains two main scripts:

| Script | Description |
|--------|-------------|
| **setup.sh** | Install XMPlus and auto-generate config with ApiHost, ApiKey, and multiple NodeIDs |
| **6to4-tunnel.sh** | Interactive setup for 6to4 and GRE6 tunnels between Iran and foreign servers (no real IPv6 needed) |

Both scripts can be run directly from GitHub without cloning.

---

## Repository Structure

```
xmpauto/
├── README.md           # This file
├── setup.sh            # XMPlus install and config generator
├── 6to4-tunnel.sh      # Interactive 6to4 + GRE6 tunnel setup
├── config.yml          # Sample XMPlus config (reference)
├── install.txt         # Official XMPlus install link
└── 6t4.md              # 6to4 reference documentation
```

---

# 1. XMPlus Setup

Install XMPlus and auto-generate config with ApiHost, ApiKey, and NodeIDs.

## Prerequisites

- Linux: **CentOS 7+**, **Ubuntu 16+**, or **Debian 8+**
- **root** or **sudo** access

## Run (one-liner)

**Single node:**
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/setup.sh) --apihost "https://www.xyz.com" --apikey "YOUR_KEY" --nodes 1
```

**Multiple nodes:**
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/setup.sh) --apihost "https://www.xyz.com" --apikey "YOUR_KEY" --nodes 1 2 3
```

**Config only (no install):**
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/setup.sh) --apihost "https://www.xyz.com" --apikey "YOUR_KEY" --nodes 1 2 --config-only
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `--apihost` | API panel URL (same for all nodes) |
| `--apikey` | API key (same for all nodes) |
| `--nodes` | List of Node IDs (creates a config block per node) |
| `--config-only` | Generate config only, skip install |

## Output

- XMPlus installed in `/usr/local/XMPlus/`
- Config in `/etc/XMPlus/config.yml`
- systemd service: **XMPlus**

## XMPlus Management Commands

| Command | Description |
|---------|-------------|
| `XMPlus` | Show menu |
| `XMPlus start` | Start service |
| `XMPlus stop` | Stop service |
| `XMPlus restart` | Restart service |
| `XMPlus status` | Service status |
| `XMPlus log` | View logs |
| `XMPlus config` | Show config |

---

# 2. 6to4 + GRE6 Tunnel

**Interactive script** for 6to4 and GRE6 tunnels between Iran and foreign servers, **without real IPv6**. Supports **multiple Iran servers** to **one foreign server**.

## Prerequisites

- Two servers: one in Iran, one abroad
- Public **IPv4** on both
- **root** or **sudo** access

## Run

```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/6to4-tunnel.sh)
```

The script shows a menu and asks for inputs interactively. No arguments needed.

## Menu Options

| Option | Description |
|--------|-------------|
| 1 | Setup Iran server (tunnel endpoint) |
| 2 | Setup Foreign server (tunnel endpoint) |
| 3 | Remove tunnel |
| 4 | Show tunnel status |
| 5 | Exit |

## Usage Flow

### 1. Iran Server

1. Run the script.
2. Select option **1** (Setup Iran server).
3. Enter:
   - Iran server public IPv4
   - Foreign server public IPv4
   - Tunnel ID (1 for first Iran, 2 for second, etc.)
   - IPv6 base prefix (optional, default: fde8:b030:25cf)
4. Confirm to create the tunnel.

### 2. Foreign Server

1. Run the script.
2. Select option **2** (Setup Foreign server).
3. Enter:
   - Foreign server public IPv4
   - Iran server public IPv4
   - Tunnel ID (must match the Iran server)
   - IPv6 base prefix (optional)
4. Confirm to create the tunnel.

### 3. Testing

**From Iran server:**
```bash
ping6 fde8:b030:25cf:1::2
ping 172.20.20.2
```

**From Foreign server:**
```bash
ping6 fde8:b030:25cf:1::1
ping 172.20.20.1
```

## Generated Addresses (Default)

| Tunnel | Iran IPv6 | Foreign IPv6 | Iran Local IPv4 | Foreign Local IPv4 |
|--------|-----------|--------------|-----------------|---------------------|
| 1 | fde8:b030:25cf:1::1 | fde8:b030:25cf:1::2 | 172.20.20.1 | 172.20.20.2 |
| 2 | fde8:b030:25cf:2::1 | fde8:b030:25cf:2::2 | 172.20.21.1 | 172.20.21.2 |
| 3 | fde8:b030:25cf:3::1 | fde8:b030:25cf:3::2 | 172.20.22.1 | 172.20.22.2 |

## Persistence After Reboot

Tunnel config is saved in **`/etc/rc.local`** and runs automatically after reboot.

---

## Troubleshooting

### XMPlus

| Issue | Solution |
|-------|----------|
| Install fails / download error | Check internet and GitHub access; use proxy if blocked. |
| Service won't start | Run `XMPlus log`; check `/etc/XMPlus/config.yml` and permissions. |
| Config not updating | Rebuild config with `--config-only`, then `XMPlus restart`. |

### 6to4 Tunnel

| Issue | Solution |
|-------|----------|
| Ping fails | Run tunnel setup on both sides, then test again. |
| Tunnel gone after reboot | Verify `/etc/rc.local` exists and is executable; check boot logs. |
| "File exists" or duplicate interface | Remove the tunnel first (option 3), then run setup again. |

---

## Command Summary

| Task | Command |
|------|---------|
| XMPlus install (single node) | `sudo bash <(curl -Ls .../setup.sh) --apihost "URL" --apikey "KEY" --nodes 1` |
| XMPlus install (multiple nodes) | `... --nodes 1 2 3` |
| XMPlus config only | `... --config-only --nodes 1 2` |
| 6to4 tunnel (interactive) | `sudo bash <(curl -Ls .../6to4-tunnel.sh)` |

**Repository:** https://github.com/hosseinpv1379/xmpauto

---

## License

- **Repository:** [github.com/hosseinpv1379/xmpauto](https://github.com/hosseinpv1379/xmpauto)
- These scripts are for **learning and personal use**.
- XMPlus is a separate project; the script uses its official install and licensing.
