import { readFileSync } from "node:fs";

const config = JSON.parse(
  readFileSync(new URL("./config.json", import.meta.url), "utf8"),
);

if (!config.server || !config.server.port) {
  throw new Error("APP_CONFIG_ERROR: missing server.port in config.json");
}

const port = config.server.port;
console.log(`listening on ${port}`);
