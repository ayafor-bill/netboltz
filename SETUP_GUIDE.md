# NetBoltZ Setup Guide

Complete step-by-step instructions to replicate NetBoltZ in any environment.

---

## Table of Contents
1. [Local Testing (Windows)](#local-testing-windows)
2. [Local Testing (Linux/Kali)](#local-testing-linuxkali)
3. [Two-Machine Testing](#two-machine-testing)
4. [AWS Cloud Deployment](#aws-cloud-deployment)
5. [Oracle Cloud Deployment](#oracle-cloud-deployment)
6. [Enabling QUIC/HTTP3](#enabling-quichttp3)
7. [Running Benchmarks](#running-benchmarks)

---

## Local Testing (Windows)

### Step 1: Download Caddy
1. Go to: https://caddyserver.com/download
2. Select: **Windows amd64**
3. Extract `caddy.exe` to `C:\netboltz\`

### Step 2: Create Caddyfile
Open Notepad, paste this, save as `Caddyfile` (no extension):
```
:8080 {
    reverse_proxy https://www.youtube.com {
        header_up Host {upstream_hostport}
    }
}
```

**Important:** In Notepad → Save As → change "Save as type" to "All Files" → name it `Caddyfile`

### Step 3: Open Firewall
Open PowerShell **as Administrator**:
```powershell
New-NetFirewallRule -DisplayName "Caddy TCP" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Caddy UDP" -Direction Inbound -LocalPort 8080 -Protocol UDP -Action Allow
```

### Step 4: Run Caddy
```powershell
cd C:\netboltz
.\caddy.exe run --config Caddyfile
```

### Step 5: Test
Open browser: `http://localhost:8080`

---

## Local Testing (Linux/Kali)

### Step 1: Install Caddy
```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install caddy
```

### Step 2: Create Caddyfile
```bash
mkdir ~/netboltz && cd ~/netboltz
nano Caddyfile
```

Paste:
```
:8080 {
    reverse_proxy https://www.youtube.com {
        header_up Host {upstream_hostport}
    }
}
```

### Step 3: Run
```bash
sudo caddy run --config Caddyfile
```

### Step 4: Test
```bash
curl http://localhost:8080
```

---

## Two-Machine Testing

This is how the original NetBoltZ validation was done:

**Machine 1 (Server):** Windows laptop running Caddy
**Machine 2 (Client):** Kali Linux running speed tests
**Network:** Both connected to same hotspot/router

### Setup Machine 1 (Server):
1. Follow Windows setup above
2. Get your IP: `ipconfig` → note IPv4 address (e.g., `192.168.182.102`)
3. **Disable Windows Firewall** or add firewall rules above

### Setup Machine 2 (Client):
```bash
# Test connection
curl http://192.168.182.102:8080

# Speed test: Direct vs Proxy
time curl -o /dev/null -s https://www.youtube.com
time curl -o /dev/null -s http://192.168.182.102:8080
```

### Common Issue: Devices Can't Talk to Each Other
**Cause:** Router/hotspot AP isolation is enabled

**Fix on Phone Hotspot:** Settings → Hotspot → disable "AP Isolation" or "Client Isolation"

**Fix on Router:** Access router admin (usually 192.168.1.1) → Wireless → disable AP/Client Isolation

**If still failing:** Test from Windows itself first (`http://localhost:8080`) - if that works, it's a network isolation issue

---

## AWS Cloud Deployment

### Step 1: Launch EC2 Instance
- AMI: Ubuntu Server 24.04 LTS
- Instance Type: t2.micro (free tier)
- Security Group - Add inbound rules:
  ```
  Port 22  TCP  → SSH
  Port 80  TCP  → HTTP
  Port 443 TCP  → HTTPS
  Port 443 UDP  → QUIC ← CRITICAL
  ```

### Step 2: Connect
```bash
ssh -i your-key.pem ubuntu@YOUR_EC2_IP
```

### Step 3: Install & Configure
```bash
# Clone repo
git clone https://github.com/ayafor-bill/netboltz.git
cd netboltz

# Run setup script
chmod +x scripts/setup_server.sh
bash scripts/setup_server.sh your-domain.com
```

### Step 4: Verify
```bash
# Check Caddy is running
sudo systemctl status caddy

# Test QUIC
curl --http3 https://your-domain.com
```

---

## Oracle Cloud Deployment

### Step 1: Create Free Tier Instance
- Shape: VM.Standard.E2.1.Micro (Always Free)
- Image: Ubuntu 24.04
- Add ingress rules in Security List:
  ```
  Port 80  TCP
  Port 443 TCP
  Port 443 UDP ← CRITICAL for QUIC
  ```

### Step 2: Fix Oracle Firewall (Important!)
Oracle instances have an internal iptables firewall:
```bash
# Allow HTTP/HTTPS/QUIC
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 443 -j ACCEPT

# Save rules
sudo apt install iptables-persistent -y
sudo netfilter-persistent save
```

### Step 3: Install & Configure
```bash
git clone https://github.com/ayafor-bill/netboltz.git
cd netboltz
bash scripts/setup_server.sh your-domain.com
```

---

## Enabling QUIC/HTTP3

QUIC **requires HTTPS** which requires a domain. You have two options:

### Option A: Free Domain (Recommended)
1. Go to https://freedns.afraid.org
2. Sign up free
3. Add subdomain (e.g., `netboltz.mooo.com`)
4. Point to your server IP
5. Wait 10-15 minutes for DNS propagation
6. Update Caddyfile:
```
netboltz.mooo.com {
    reverse_proxy https://www.youtube.com {
        header_up Host {upstream_hostport}
    }
}
```
7. `sudo systemctl reload caddy`
8. Caddy auto-generates SSL + enables QUIC

### Option B: Self-Signed (Local Testing Only)
```
{
    auto_https off
}

:8443 {
    tls internal
    reverse_proxy https://www.youtube.com {
        header_up Host {upstream_hostport}
    }
}
```
Test with: `curl --http3 -k https://localhost:8443`

### Verify QUIC is Active
```bash
# Check protocol in response headers
curl -I --http3 https://your-domain.com 2>&1 | grep -i "alt-svc\|http"

# Capture UDP packets (QUIC uses UDP)
sudo tcpdump -i any udp port 443
# Should see traffic when making requests

# Wireshark filter
# Open: wireshark
# Filter: quic
```

---

## Running Benchmarks

### Quick Test
```bash
# Direct
time curl -o /dev/null -s https://youtube.com

# Through NetBoltZ
time curl --http3 -o /dev/null -s https://your-domain.com
```

### Full Benchmark
```bash
chmod +x scripts/test_speed.sh
./scripts/test_speed.sh youtube.com https://your-domain.com
./scripts/test_speed.sh facebook.com https://your-domain.com
./scripts/test_speed.sh wikipedia.org https://your-domain.com
```

### Calculate Improvement
```bash
DIRECT=0.850
QUIC=0.284
echo "scale=1; (($DIRECT - $QUIC) / $DIRECT) * 100" | bc
# Output: 66.5 (66.5% faster)
```

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| Can't connect from other machine | Firewall blocking | Open port in firewall/security group |
| HTTP/3 skipped | No TLS/HTTPS | Use domain or `tls internal` |
| SSL errors | Self-signed cert | Add `-k` flag to curl |
| Caddy won't start | Config syntax error | Run `caddy validate --config Caddyfile` |
| Devices can't ping each other | AP isolation | Disable in router/hotspot settings |
| No improvement in speed | QUIC not active | Check `h3` in Caddy logs |
| curl: HTTP3 not supported | Old curl version | Use Firefox or install newer curl |
