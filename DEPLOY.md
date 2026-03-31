# Deployment Guide - mqweb.holancloud.com

## Pre-deployment Checklist

- [ ] GitHub repository created
- [ ] VPS with Coolify installed
- [ ] DNS A record configured: `mqweb.holancloud.com` → VPS IP

---

## Step 1: Create GitHub Repository

```bash
# Create new repo on GitHub first, then:
cd C:/Users/holan/OneDrive/GitHub/MQL4-WEB
git remote add origin https://github.com/YOUR_USERNAME/MQL4-WEB.git
git branch -M main
git push -u origin main
```

---

## Step 2: Configure DNS

Add A record in your DNS provider:

| Type | Name | Value |
|------|------|-------|
| A | mqweb | YOUR_VPS_IP |

---

## Step 3: Deploy in Coolify

### 3.1 Create New Project

1. Open Coolify dashboard
2. Click "New Project"
3. Select "Dockerfile"
4. Connect GitHub repository

### 3.2 Configure Application

| Setting | Value |
|---------|-------|
| **Repository** | github.com/YOUR_USERNAME/MQL4-WEB |
| **Branch** | main |
| **Dockerfile Path** | ./Dockerfile |
| **Port** | 3030 |

### 3.3 Environment Variables

| Key | Value |
|-----|-------|
| `TCP_PORT` | 8080 |
| `HTTP_PORT` | 3030 |
| `NODE_ENV` | production |
| `HOST_URL` | https://mqweb.holancloud.com |

### 3.4 Domain Configuration

1. Go to "Domains" tab
2. Add custom domain: `mqweb.holancloud.com`
3. Coolify will generate SSL certificate automatically

### 3.5 Port Configuration

Expose both ports:
- **3030** → HTTP (public)
- **8080** → TCP (for MT4 connection)

---

## Step 4: Firewall Configuration

SSH into your VPS and configure firewall:

```bash
# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow custom ports
sudo ufw allow 3030/tcp  # HTTP Dashboard
sudo ufw allow 8080/tcp  # TCP for MT4

# Enable firewall
sudo ufw enable
```

---

## Step 5: Update MT4 EA

After deployment, update your EA:

```mql4
// Change these in MT4 EA inputs:
SERVER_HOST = "mqweb.holancloud.com"  // or VPS IP
SERVER_PORT = 8080
```

---

## Verification

### Test Dashboard
```bash
curl https://mqweb.holancloud.com/health
```

Expected response:
```json
{"server":"running","mt4_connected":false,"pending_commands":0}
```

### Test TCP Connection
```bash
nc -zv mqweb.holancloud.com 8080
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Container won't start | Check Coolify logs |
| 502 Gateway | Port conflict, check exposed ports |
| MT4 can't connect | Check firewall port 8080 |
| DNS not resolving | Wait for DNS propagation (up to 24h) |

---

## URLs After Deployment

| Service | URL |
|---------|-----|
| Dashboard | https://mqweb.holancloud.com |
| Health Check | https://mqweb.holancloud.com/health |
| TCP (MT4) | mqweb.holancloud.com:8080 |

---

## Post-Deployment

1. **Test MT4 Connection**
   - Update EA with new server address
   - Compile and attach to chart
   - Verify connection in Experts log

2. **Monitor Logs**
   ```bash
   # In Coolify: Application → Logs
   # Or SSH into VPS and check container logs
   ```

3. **Set up Backups** (optional in Coolify)
   - Database: N/A (in-memory)
   - Consider persistence if needed later
