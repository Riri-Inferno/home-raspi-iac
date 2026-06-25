// Proxy for vector-search.riri-inferno.com → GCP API Gateway.
//
// Why: Cloudflare proxied CNAME preserves the original Host header
// (vector-search.riri-inferno.com), but GCP API Gateway only accepts
// requests whose Host matches the gateway's own *.gateway.dev hostname.
// Rewriting the URL hostname here causes Workers runtime to send the
// correct Host header in the egress fetch automatically.
//
// CORS: Browser clients (CF Pages) need CORS headers on all responses.
// API Gateway cannot add them directly, so we inject them here.
//
// See: gcp-serverless-vector-search docs/adr/0014-cloudflare-worker-host-rewrite.md

const ORIGIN = "vector-search-gateway-dzqjqk3y.an.gateway.dev";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS, PUT, PATCH, DELETE",
  "Access-Control-Allow-Headers": "Content-Type, X-API-Key",
  "Access-Control-Max-Age": "86400",
};

export default {
  async fetch(request) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    url.hostname = ORIGIN;
    const response = await fetch(new Request(url.toString(), request));

    const newResponse = new Response(response.body, response);
    for (const [k, v] of Object.entries(CORS_HEADERS)) {
      newResponse.headers.set(k, v);
    }
    return newResponse;
  },
};
