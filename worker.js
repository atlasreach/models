// Cloudflare Worker - CORS Proxy for MaxStudio API
// Deploy this at: https://workers.cloudflare.com/

const API_KEY = 'bae0c714-f708-4d00-99b3-b740d0af3fda';
const ALLOWED_ORIGINS = [
  'https://atlasreach.github.io',
  'http://localhost:8000',
  'http://127.0.0.1:8000'
];

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  // Handle CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Max-Age': '86400',
      }
    });
  }

  const url = new URL(request.url);
  const path = url.pathname;

  // Route requests to MaxStudio API
  let targetUrl;
  if (path.startsWith('/enhance')) {
    targetUrl = 'https://api.maxstudio.ai/image-enhancer';
  } else if (path.startsWith('/enhance-status/')) {
    const jobId = path.replace('/enhance-status/', '');
    targetUrl = `https://api.maxstudio.ai/image-enhancer/${jobId}`;
  } else if (path.startsWith('/detect')) {
    targetUrl = 'https://api.maxstudio.ai/detect-face-image';
  } else if (path.startsWith('/swap-status/')) {
    const jobId = path.replace('/swap-status/', '');
    targetUrl = `https://api.maxstudio.ai/faceswap/${jobId}`;
  } else if (path.startsWith('/swap')) {
    targetUrl = 'https://api.maxstudio.ai/faceswap';
  } else {
    return new Response('Not Found', { status: 404 });
  }

  try {
    // Forward request to MaxStudio with API key
    const headers = new Headers();
    headers.set('Content-Type', 'application/json');
    headers.set('x-api-key', API_KEY);

    let body = null;
    if (request.method === 'POST') {
      body = await request.text();
    }

    const response = await fetch(targetUrl, {
      method: request.method,
      headers: headers,
      body: body
    });

    const responseBody = await response.text();

    // Return with CORS headers
    return new Response(responseBody, {
      status: response.status,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      }
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      }
    });
  }
}
