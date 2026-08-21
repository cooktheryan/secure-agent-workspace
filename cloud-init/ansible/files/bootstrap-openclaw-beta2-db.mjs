import { mkdirSync } from "node:fs";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";

const stateDir = process.env.OPENCLAW_STATE_DIR;
if (!stateDir) throw new Error("OPENCLAW_STATE_DIR is required");

const databasePath = path.join(stateDir, "agents/main/agent/openclaw-agent.sqlite");
mkdirSync(path.dirname(databasePath), { recursive: true, mode: 0o700 });

const database = new DatabaseSync(databasePath);
try {
  const { count } = database.prepare("SELECT count(*) AS count FROM sqlite_schema").get();
  if (count === 0) {
    database.exec(`
      PRAGMA auto_vacuum = NONE;
      VACUUM;
      CREATE TABLE openclaw_beta2_bootstrap (value INTEGER);
      DROP TABLE openclaw_beta2_bootstrap;
    `);
  }
} finally {
  database.close();
}
