/**
 * Cloudflare Worker — GitHub OAuth Proxy for Autopilot Dashboard
 *
 * This worker exchanges the OAuth authorization code for an access token.
 * It keeps the client_secret secure (stored as Cloudflare secret, never exposed to browser).
 *
 * SETUP:
 * 1. Create a GitHub OAuth App: https://github.com/settings/developers
 *    - Application name: Autopilot Dashboard
 *    - Homepage URL: https://lucassfreiree.github.io/autopilot/
 *    - Authorization callback URL: https://lucassfreiree.github.io/autopilot/
 * 2. Copy the Client ID and Client Secret
 * 3. Deploy this worker to Cloudflare Workers (free tier):
 *    - npx wrangler init autopilot-oauth
 *    - Copy this file as src/index.js
 *    - npx wrangler secret put GITHUB_CLIENT_SECRET
 *    - npx wrangler secret put GITHUB_CLIENT_ID
 *    - npx wrangler deploy
 * 4. Update OAUTH_PROXY_URL in panel/index.html with your worker URL
 *
 * COST: $0 (Cloudflare Workers free tier = 100,000 requests/day)
 */

const ALLOWED_ORIGINS = [
  'https://lucassfreiree.github.io',
  'http://localhost:8000',
  'http://127.0.0.1:8000'
];

function corsHeaders(origin) {
  const allowed = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
  };
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    // Only accept POST
    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' }
      });
    }

    try {
      const { code } = await request.json();

      if (!code) {
        return new Response(JSON.stringify({ error: 'Missing code parameter' }), {
          status: 400,
          headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' }
        });
      }

      // Exchange authorization code for access token
      const tokenResponse = await fetch('https://github.com/login/oauth/access_token', {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          client_id: env.GITHUB_CLIENT_ID,
          client_secret: env.GITHUB_CLIENT_SECRET,
          code: code,
        }),
      });

      const tokenData = await tokenResponse.json();

      if (tokenData.error) {
        return new Response(JSON.stringify({ error: tokenData.error_description || tokenData.error }), {
          status: 400,
          headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' }
        });
      }

      // Return only the access token (don't expose other fields)
      return new Response(JSON.stringify({ access_token: tokenData.access_token }), {
        status: 200,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' }
      });

    } catch (e) {
      return new Response(JSON.stringify({ error: 'Internal error' }), {
        status: 500,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' }
      });
    }
  }
};
