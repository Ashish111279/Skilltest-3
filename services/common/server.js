const http = require("node:http");

const serviceName = process.env.SERVICE_NAME || "Demo";
const port = Number(process.env.PORT || 3000);

const server = http.createServer((request, response) => {
  response.setHeader("Content-Type", "application/json; charset=utf-8");

  if (request.url === "/health" || request.url === "/") {
    response.writeHead(200);
    response.end(JSON.stringify({
      status: "ok",
      message: `${serviceName} Service Running`,
      service: serviceName.toLowerCase(),
    }));
    return;
  }

  response.writeHead(404);
  response.end(JSON.stringify({ error: "Not found" }));
});

server.listen(port, "0.0.0.0", () => {
  console.log(`${serviceName} Service Running on port ${port}`);
});
