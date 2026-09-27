const http = require("node:http");

const port = Number(process.env.PORT || 3000);
const services = {
  users: process.env.USER_SERVICE_URL || "http://user-service:3001",
  products: process.env.PRODUCT_SERVICE_URL || "http://products-service:3002",
  orders: process.env.ORDER_SERVICE_URL || "http://orders-service:3003",
  cart: process.env.CART_SERVICE_URL || "http://cart-service:3004",
};

const page = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Commerce / Service Status</title>
  <style>
    :root { color-scheme: light; font-family: ui-monospace, "Cascadia Code", monospace; background: #f2f4ee; color: #172621; }
    body { max-width: 900px; margin: 0 auto; padding: 48px 24px; }
    header { border-bottom: 2px solid #172621; padding-bottom: 24px; }
    .eyebrow { color: #39735a; text-transform: uppercase; font-size: 12px; }
    h1 { font-size: clamp(32px, 7vw, 56px); margin: 16px 0 8px; }
    p { color: #53645a; }
    ul { list-style: none; padding: 0; margin: 32px 0; border-top: 1px solid #bdc8bd; }
    li { display: flex; justify-content: space-between; gap: 16px; padding: 18px 8px; border-bottom: 1px solid #bdc8bd; }
    .status { color: #8a4b16; }
    .status.ok { color: #167147; }
    footer { font-size: 12px; color: #64736a; }
  </style>
</head>
<body>
  <header>
    <div class="eyebrow">Commerce / deployment check</div>
    <h1>Frontend is Live</h1>
    <p>Five containers, one reachable storefront.</p>
  </header>
  <ul id="services">
    <li><span>Users</span><span class="status">Checking...</span></li>
    <li><span>Products</span><span class="status">Checking...</span></li>
    <li><span>Orders</span><span class="status">Checking...</span></li>
    <li><span>Cart</span><span class="status">Checking...</span></li>
  </ul>
  <footer>Node.js microservices deployment</footer>
  <script>
    Promise.all(["users", "products", "orders", "cart"].map(async (name) => {
      const target = document.querySelectorAll("#services li")[
        ["users", "products", "orders", "cart"].indexOf(name)
      ].querySelector(".status");
      try {
        const response = await fetch("/api/" + name + "/health");
        const result = await response.json();
        target.textContent = response.ok ? result.message : "Unavailable";
        target.classList.toggle("ok", response.ok);
      } catch {
        target.textContent = "Unavailable";
      }
    }));
  </script>
</body>
</html>`;

const server = http.createServer(async (request, response) => {
  const path = new URL(request.url, "http://localhost").pathname;
  const match = path.match(/^\/api\/(users|products|orders|cart)(\/.*)?$/);

  if (path === "/health") {
    response.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    response.end(JSON.stringify({ status: "ok", message: "Frontend is Live" }));
    return;
  }

  if (match) {
    try {
      const upstream = await fetch(`${services[match[1]]}${match[2] || "/"}`, {
        method: request.method,
      });
      response.writeHead(upstream.status, {
        "Content-Type": upstream.headers.get("content-type") || "application/json",
      });
      response.end(await upstream.text());
    } catch {
      response.writeHead(502, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ error: "Service unavailable" }));
    }
    return;
  }

  if (path === "/" && request.method === "GET") {
    response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    response.end(page);
    return;
  }

  response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
  response.end("Not found");
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Frontend is Live on port ${port}`);
});
