/* eslint-disable @typescript-eslint/no-require-imports */
const http = require("http");
const { WebSocketServer, WebSocket } = require("ws");
const jwt = require("jsonwebtoken");
// On Render, env vars come from the dashboard / blueprint. Loading .env files here
// can overwrite them with empty values if a stray .env exists in the deploy bundle.
if (!process.env.RENDER_SERVICE_ID && process.env.RENDER !== "true") {
  require("dotenv").config({ path: ".env.local" });
  require("dotenv").config();
}

const port = Number(process.env.PORT || process.env.REALTIME_GATEWAY_PORT || 4000);
const model =
  process.env.OPENAI_REALTIME_MODEL || "gpt-4o-realtime-preview";
const openaiKey = process.env.OPENAI_API_KEY?.trim();
const jwtSecret = process.env.JWT_SECRET?.trim();

if (!openaiKey) {
  console.error(
    "Missing OPENAI_API_KEY — set it on this Render service (Environment → ai-phone-realtime-gateway).",
  );
  process.exit(1);
}
if (!jwtSecret) {
  console.error(
    "Missing JWT_SECRET — ensure env group ai-phone-shared is linked, or set JWT_SECRET to match ai-phone-web.",
  );
  process.exit(1);
}

const server = http.createServer((_req, res) => {
  res.writeHead(200);
  res.end("AI Phone Assistant realtime gateway");
});

const wss = new WebSocketServer({ noServer: true });

server.on("upgrade", (req, socket, head) => {
  try {
    const host = req.headers.host || "";
    const url = new URL(req.url || "", `http://${host}`);
    const token = url.searchParams.get("token");
    if (!token) {
      socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
      socket.destroy();
      return;
    }
    jwt.verify(token, jwtSecret);
  } catch {
    socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
    socket.destroy();
    return;
  }

  wss.handleUpgrade(req, socket, head, (clientWs) => {
    wss.emit("connection", clientWs, req);
  });
});

wss.on("connection", (clientWs, req) => {
  const host = req.headers.host || "";
  const url = new URL(req.url || "", `http://${host}`);
  const token = url.searchParams.get("token");
  let userSub = "";
  try {
    const decoded = jwt.verify(token, jwtSecret);
    userSub = decoded.sub;
  } catch {
    clientWs.close(4401, "unauthorized");
    return;
  }

  const upstreamUrl = `wss://api.openai.com/v1/realtime?model=${encodeURIComponent(
    model,
  )}`;

  const upstream = new WebSocket(upstreamUrl, {
    headers: {
      Authorization: `Bearer ${openaiKey}`,
      "OpenAI-Beta": "realtime=v1",
    },
  });

  const forward = (from, to, label) => {
    from.on("message", (data, isBinary) => {
      if (to.readyState === WebSocket.OPEN) {
        to.send(data, { binary: !!isBinary });
      }
    });
    from.on("close", () => {
      try {
        to.close();
      } catch {
        /* ignore */
      }
    });
    from.on("error", (err) => {
      console.error(label, err);
      try {
        to.close();
      } catch {
        /* ignore */
      }
    });
  };

  upstream.on("open", () => {
    forward(clientWs, upstream, "client->openai");
    forward(upstream, clientWs, "openai->client");
  });

  upstream.on("error", (err) => {
    console.error("upstream error", userSub, err);
    clientWs.close(1011, "upstream error");
  });
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Realtime gateway listening on port ${port}`);
});
