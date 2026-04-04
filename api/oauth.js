// Autopilot OAuth Proxy — exchanges GitHub OAuth code for access token
// Deployed on Vercel as serverless function at /api/oauth
export default async function handler(req, res) {
  const origin = req.headers.origin || '';
  const allowed = origin.includes('lucassfreiree.github.io') || origin.includes('localhost');

  // CORS
  res.setHeader('Access-Control-Allow-Origin', allowed ? origin : 'https://lucassfreiree.github.io');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { code } = req.body;
    if (!code) return res.status(400).json({ error: 'Missing code' });

    const resp = await fetch('https://github.com/login/oauth/access_token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify({
        client_id: 'Ov23lil3RyaSwe1xETjb',
        client_secret: process.env.GITHUB_CLIENT_SECRET,
        code
      })
    });

    const data = await resp.json();

    if (data.error) return res.status(400).json({ error: data.error_description || data.error });

    return res.status(200).json({ access_token: data.access_token });
  } catch (e) {
    return res.status(500).json({ error: 'Internal error' });
  }
}
