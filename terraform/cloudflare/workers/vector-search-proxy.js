// Proxy for vector-search.riri-inferno.com → GCP API Gateway.
//
// Why: Cloudflare proxied CNAME preserves the original Host header
// (vector-search.riri-inferno.com), but GCP API Gateway only accepts
// requests whose Host matches the gateway's own *.gateway.dev hostname.
// Rewriting the URL hostname here causes Workers runtime to send the
// correct Host header in the egress fetch automatically.
//
// See: gcp-serverless-vector-search docs/adr/0014-cloudflare-worker-host-rewrite.md

const ORIGIN = "vector-search-gateway-dzqjqk3y.an.gateway.dev";

export default {
  async fetch(request) {
    const url = new URL(request.url);
    url.hostname = ORIGIN;
    return fetch(new Request(url.toString(), request));
  },
};
