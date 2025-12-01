import { app as _, BrowserWindow as x, ipcMain as l } from "electron";
import i from "path";
import { spawn as F } from "child_process";
import r from "fs";
import { fileURLToPath as V } from "node:url";
const h = i.dirname(V(import.meta.url));
process.env.DIST = i.join(h, "../dist");
process.env.VITE_PUBLIC = _.isPackaged ? process.env.DIST : i.join(h, "../public");
let S;
const R = i.resolve(h, "../../"), N = i.join(R, "venv", "Scripts", "python.exe"), D = "python", C = r.existsSync(N) ? N : D, J = i.resolve(h, "../api");
function O() {
  S = new x({
    width: 1200,
    height: 800,
    backgroundColor: "#1e1b4b",
    // Dark blue/purple FM theme base
    webPreferences: {
      preload: i.join(h, "preload.mjs"),
      nodeIntegration: !1,
      contextIsolation: !0
    }
  }), process.env.VITE_DEV_SERVER_URL && S.webContents.openDevTools(), S.webContents.on("did-finish-load", () => {
    S?.webContents.send("main-process-message", (/* @__PURE__ */ new Date()).toLocaleString());
  }), process.env.VITE_DEV_SERVER_URL ? S.loadURL(process.env.VITE_DEV_SERVER_URL) : S.loadFile(i.join(process.env.DIST, "index.html"));
}
_.on("window-all-closed", () => {
  process.platform !== "darwin" && _.quit();
});
_.on("activate", () => {
  x.getAllWindows().length === 0 && O();
});
_.whenReady().then(() => {
  O(), L();
});
function L() {
  l.handle("run-match-selector", async (s, n) => P("api_match_selector.py", n)), l.handle("run-training-advisor", async (s, n) => P("api_training_advisor.py", n)), l.handle("run-rest-advisor", async (s, n) => P("api_rest_advisor.py", n));
  const u = i.join(h, "../data"), v = i.join(u, "app_state.json");
  l.handle("get-app-state", async () => {
    try {
      if (r.existsSync(v)) {
        const s = r.readFileSync(v, "utf-8");
        return JSON.parse(s);
      }
      return null;
    } catch (s) {
      return console.error("Error reading app state:", s), null;
    }
  }), l.handle("save-app-state", async (s, n) => {
    try {
      return r.existsSync(u) || r.mkdirSync(u, { recursive: !0 }), r.writeFileSync(v, JSON.stringify(n, null, 2), "utf-8"), { success: !0 };
    } catch (e) {
      return console.error("Error saving app state:", e), { success: !1, error: String(e) };
    }
  }), l.handle("get-player-list", async (s, n) => {
    try {
      const e = n?.statusFile || "players-current.csv", o = i.join(R, e);
      if (!r.existsSync(o))
        return { success: !1, error: `File not found: ${e}` };
      const a = r.readFileSync(o, "utf-8").split(`
`);
      if (a.length < 2)
        return { success: !1, error: "CSV file is empty or invalid" };
      const m = a[0].split(",").map((t) => t.trim().replace(/"/g, "")), T = m.findIndex((t) => t === "Name");
      let w = m.findIndex((t) => t === "Best Position");
      if (w === -1 && (w = m.findIndex((t) => t === "Positions")), T === -1)
        return { success: !1, error: "Required column (Name) not found" };
      const E = [], j = (t) => {
        const p = [];
        let d = "", f = !1;
        for (let g = 0; g < t.length; g++) {
          const I = t[g];
          I === '"' ? f = !f : I === "," && !f ? (p.push(d.trim()), d = "") : d += I;
        }
        return p.push(d.trim()), p;
      };
      for (let t = 1; t < a.length; t++) {
        const p = a[t].trim();
        if (!p) continue;
        const d = j(p), f = d[T], g = w !== -1 ? d[w] : "Unknown";
        f && f !== "" && E.push({ name: f, position: g || "Unknown" });
      }
      return E.sort((t, p) => t.name.localeCompare(p.name)), { success: !0, players: E };
    } catch (e) {
      return console.error("Error reading player list:", e), { success: !1, error: String(e) };
    }
  });
  const c = i.join(u, "confirmed_lineups.json");
  l.handle("get-confirmed-lineups", async () => {
    try {
      if (r.existsSync(c)) {
        const s = r.readFileSync(c, "utf-8");
        return JSON.parse(s);
      }
      return { lineups: [] };
    } catch (s) {
      return console.error("Error reading confirmed lineups:", s), { lineups: [] };
    }
  }), l.handle("save-confirmed-lineup", async (s, n) => {
    try {
      r.existsSync(u) || r.mkdirSync(u, { recursive: !0 });
      let e = { lineups: [] };
      return r.existsSync(c) && (e = JSON.parse(r.readFileSync(c, "utf-8"))), e.lineups = e.lineups.filter((o) => o.matchId !== n.matchId), e.lineups.push(n), e.lineups.sort((o, y) => o.date.localeCompare(y.date)), r.writeFileSync(c, JSON.stringify(e, null, 2), "utf-8"), { success: !0 };
    } catch (e) {
      return console.error("Error saving confirmed lineup:", e), { success: !1, error: String(e) };
    }
  }), l.handle("remove-confirmed-lineup", async (s, n) => {
    try {
      if (!r.existsSync(c))
        return { success: !0 };
      const e = JSON.parse(r.readFileSync(c, "utf-8"));
      return e.lineups = e.lineups.filter((o) => o.matchId !== n), r.writeFileSync(c, JSON.stringify(e, null, 2), "utf-8"), { success: !0 };
    } catch (e) {
      return console.error("Error removing confirmed lineup:", e), { success: !1, error: String(e) };
    }
  });
}
function P(u, v) {
  return new Promise((c, s) => {
    const n = i.join(J, u), e = F(C, [n], { cwd: R });
    let o = "", y = "";
    e.stdin.write(JSON.stringify(v)), e.stdin.end(), e.stdout.on("data", (a) => {
      o += a.toString();
    }), e.stderr.on("data", (a) => {
      y += a.toString();
    }), e.on("close", (a) => {
      if (a !== 0)
        console.error(`Python script error (${a}):`, y), c({ success: !1, error: y || `Process exited with code ${a}` });
      else
        try {
          const m = JSON.parse(o);
          c(m);
        } catch {
          console.error("Failed to parse JSON output:", o), c({ success: !1, error: "Failed to parse Python output", raw: o });
        }
    });
  });
}
