# NetBoltZ Troubleshooting Guide

---

## Caddy Issues

### "Invalid character looking for beginning of object key"
**Cause:** Caddyfile has wrong encoding or hidden characters
**Fix:**
```bash
# Check for hidden characters
cat -A Caddyfile
# Each line should end with $ only, not ^M$ (Windows line endings)

# Fix Windows line endings
sed -i 's/\r//' Caddyfile

# Or delete and recreate the file
rm Caddyfile
nano Caddyfile  # type content manually, don't paste
```

### "HTTP/2 skipped because it requires TLS" / "HTTP/3 skipped because it requires TLS"
**Cause:** Using plain HTTP (`:8080`) without TLS
**Fix:** Add `tls internal` for local testing or use a real domain for production
```
:8443 {
    tls internal  # Add this line
    reverse_proxy https://...
}
```

### Caddy starts but browser shows error
**Cause:** Usually accessing HTTP when HTTPS configured or vice versa
**Fix:**
- If Caddyfile has `:8080` → access `http://localhost:8080`
- If Caddyfile has `:8443` → access `https://localhost:8443`
- Accept certificate warning for self-signed certs

---

## Connection Issues

### Machine 2 can't connect to Machine 1

**Step 1: Test if machines can see each other**
```bash
# From Machine 2
ping MACHINE1_IP
```

If ping fails → AP isolation (see below)
If ping works → firewall issue

**Step 2: If ping works but HTTP fails**
```bash
# Check if port is open
nc -zv MACHINE1_IP 8080
# or
Test-NetConnection -ComputerName MACHINE1_IP -Port 8080  # Windows PowerShell
```

If port is closed → open it in firewall:
```powershell
# Windows (run as Administrator)
New-NetFirewallRule -DisplayName "Caddy" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
```

**Step 3: If firewall is disabled but still failing**
```bash
# Temporarily disable Windows Defender Firewall to test
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
# Test connection, then re-enable:
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
```

### AP Isolation (Devices on same network can't communicate)

**Phone Hotspot (Android):**
Settings → Network & Internet → Hotspot → Advanced → disable "AP Isolation"

**Phone Hotspot (iPhone):**
iOS forces AP isolation - use Android hotspot or router instead

**MTN/Orange Modem:**
1. Open browser on either device
2. Go to: `192.168.1.1` (or check `ipconfig` for Default Gateway)
3. Login (usually admin/admin or check sticker on modem)
4. Wireless Settings → disable "AP Isolation" or "Client Isolation"
5. Save and reconnect

**If AP isolation can't be disabled:**
Use ngrok as workaround:
```bash
# Download ngrok, run on Machine 1:
ngrok http 8080
# Use the public URL from Machine 2
```

---

## QUIC/HTTP3 Issues

### curl doesn't support HTTP/3
```bash
# Check
curl --version | grep HTTP3

# If missing, test with Firefox instead:
# 1. Open Firefox
# 2. about:config
# 3. Set network.http.http3.enable = true
# 4. Visit your proxy URL
# 5. F12 → Network → check Protocol column for "h3"
```

### QUIC packets not showing in Wireshark
```bash
# Make sure you're filtering correctly
# In Wireshark filter bar, type exactly:
quic

# If nothing shows:
# 1. Make sure HTTPS is working first
# 2. Verify curl is using HTTP/3:
curl -v --http3 https://your-url 2>&1 | head -20
# Look for "Using HTTP/3"
```

### TLS/SSL Errors
```bash
# For self-signed cert (local testing) - ignore errors:
curl -k https://localhost:8443

# Error: "SSL_ERROR_INTERNAL_ERROR_ALERT"
# Cause: TLS version mismatch
# Fix: Try different TLS version
curl -k --tlsv1.2 https://localhost:8443
curl -k --tlsv1.3 https://localhost:8443
```

---

## Cloud/Server Issues

### AWS: Can't connect to server on port 443
1. Check Security Group has port 443 TCP AND UDP open
2. Check UFW firewall:
```bash
sudo ufw status
sudo ufw allow 443/udp
sudo ufw reload
```
3. Check Caddy is running:
```bash
sudo systemctl status caddy
sudo journalctl -u caddy -f
```

### Let's Encrypt certificate fails
```bash
# Check DNS is propagated first
nslookup your-domain.com
# Should return your server IP

# Check Caddy logs
sudo journalctl -u caddy -f

# Common error: "no challenge types available"
# Fix: Make sure port 80 is open (Let's Encrypt uses HTTP challenge)
sudo ufw allow 80/tcp
```

### Oracle Cloud: Port is open but can't connect
Oracle has TWO firewalls: Security List (in console) AND iptables on the instance.
```bash
# Check iptables
sudo iptables -L -n | grep 443

# If port 443 not in rules, add it:
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

---

## Speed Test Issues

### Results vary a lot between runs
**Normal.** Network latency fluctuates.
**Fix:** Run 5-10 tests and take the average. Our scripts do this automatically.

### Proxy is slower than direct
**Possible causes:**
1. Server is far away (high latency) → Use server closer to your location
2. QUIC not actually enabled → Verify with `curl -v --http3`
3. Server is overloaded → Check server CPU/RAM
4. DNS resolution slow → Add server IP to /etc/hosts for testing

### Wikipedia showing huge improvement (could be outlier)
We observed 14.8s direct vs 0.626s through QUIC in one test run.
This is likely because:
- Wikipedia had a slow response on that particular request
- QUIC connection was already warm (0-RTT)
- MTN network had a spike at that moment

Always average multiple runs to account for outliers.

---

## Getting Help

1. Check this troubleshooting guide first
2. Run `sudo journalctl -u caddy -f` for Caddy logs
3. Run `sudo tcpdump -i any udp port 443` to verify QUIC traffic
4. Open an issue on GitHub with:
   - Your OS and Caddy version (`caddy version`)
   - Your Caddyfile contents
   - The exact error message
   - Output of `sudo journalctl -u caddy -n 50`
