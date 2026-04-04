# GitHub OAuth Proxy for Autopilot Dashboard

Free proxy that enables "Login with GitHub" on the static dashboard.

## Why is this needed?

GitHub Pages is a static site — it can't store secrets. The OAuth flow requires a `client_secret` to exchange the authorization code for an access token. This Cloudflare Worker handles that exchange securely.

## Setup (5 minutes, $0)

### Step 1: Create GitHub OAuth App

1. Go to https://github.com/settings/developers
2. Click **New OAuth App**
3. Fill in:
   - **Application name**: `Autopilot Dashboard`
   - **Homepage URL**: `https://lucassfreiree.github.io/autopilot/`
   - **Authorization callback URL**: `https://lucassfreiree.github.io/autopilot/`
4. Click **Register application**
5. Copy the **Client ID**
6. Click **Generate a new client secret** → copy it

### Step 2: Deploy Cloudflare Worker

```bash
# Install Wrangler CLI
npm install -g wrangler

# Login to Cloudflare (free account)
wrangler login

# Create project
mkdir autopilot-oauth && cd autopilot-oauth
wrangler init --yes

# Copy the worker code
cp /path/to/panel/oauth-proxy/worker.js src/index.js

# Set secrets
wrangler secret put GITHUB_CLIENT_ID    # Paste your Client ID
wrangler secret put GITHUB_CLIENT_SECRET # Paste your Client Secret

# Deploy
wrangler deploy
```

### Step 3: Update Dashboard

Edit `panel/index.html` and `panel/dashboard/index.html`:

```javascript
// Replace these values:
const OAUTH_CLIENT_ID = 'your-github-oauth-app-client-id';
const OAUTH_PROXY_URL = 'https://your-worker.your-subdomain.workers.dev';
```

## How it works

```
User clicks "Login with GitHub"
    → Redirect to github.com/login/oauth/authorize
    → User authenticates with GitHub credentials
    → GitHub redirects back with ?code=XXX
    → Dashboard sends code to Cloudflare Worker
    → Worker exchanges code for token (using client_secret)
    → Token returned to dashboard
    → Dashboard validates user is in ALLOWED_USERS
    → Dashboard unlocks
```

## Security

- `client_secret` never leaves Cloudflare Worker (encrypted at rest)
- CORS restricted to `lucassfreiree.github.io` only
- ALLOWED_USERS whitelist still enforced on dashboard side
- Token stored in sessionStorage (cleared on tab close)
- Worker free tier: 100,000 requests/day (more than enough)

## Cost

**$0** — Cloudflare Workers free tier has no charges for this usage level.
