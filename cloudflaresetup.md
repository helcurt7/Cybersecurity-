Here are the **key commands for Cloudflare free tunnel** - minimal, straight to the point:

## **1. INSTALL cloudflared**:
```bash
# Download
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
# Make executable
chmod +x cloudflared-linux-amd64
# Move to PATH
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
```

## **2. LOGIN (FREE account)**:
```bash
cloudflared tunnel login
```
- Opens browser
- Sign up FREE at Cloudflare (no credit card)
- Authorize

## **3. CREATE tunnel**:
```bash
cloudflared tunnel create my-tunnel
```

## **4. RUN tunnel** (with your local server):
```bash
# If using Express on port 3000:
cloudflared tunnel run my-tunnel --url http://localhost:3000

# If using PHP server on port 8080:
cloudflared tunnel run my-tunnel --url http://localhost:8080

# If using Python server:
cloudflared tunnel run my-tunnel --url http://localhost:8000
```

## **5. That's it!** You'll get a URL like:
```
https://my-tunnel.trycloudflare.com
```

## **Extra useful commands**:

**List tunnels**:
```bash
cloudflared tunnel list
```

**Delete tunnel**:
```bash
cloudflared tunnel delete my-tunnel
```

**Run in background**:
```bash
cloudflared tunnel run my-tunnel --url http://localhost:3000 &
```

**View tunnel info**:
```bash
cloudflared tunnel info my-tunnel
```

## **Quick setup with Express**:
```bash
# 1. Create Express app
mkdir my-app && cd my-app
npm init -y
npm install express
# Add server.js with your code

# 2. Start Express
node server.js &
# Runs on http://localhost:3000

# 3. Expose with Cloudflare
cloudflared tunnel run my-tunnel --url http://localhost:3000
```

That's the bare minimum. **Free URL, free SSL, global access.**
