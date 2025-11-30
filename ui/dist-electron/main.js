import { app as _, BrowserWindow as x, ipcMain as p } from "electron";
import o from "path";
import { spawn as F } from "child_process";
import n from "fs";
import { fileURLToPath as V } from "node:url";
const S = o.dirname(V(import.meta.url));
process.env.DIST = o.join(S, "../dist");
process.env.VITE_PUBLIC = _.isPackaged ? process.env.DIST : o.join(S, "../public");
let h;
const R = o.resolve(S, "../../"), j = o.join(R, "venv", "Scripts", "python.exe"), D = "python", C = n.existsSync(j) ? j : D, L = o.resolve(S, "../api");
function N() {
  h = new x({
    width: 1200,
    height: 800,
    backgroundColor: "#1e1b4b",
    // Dark blue/purple FM theme base
    webPreferences: {
      preload: o.join(S, "preload.mjs"),
      nodeIntegration: !1,
      contextIsolation: !0
    }
  }), process.env.VITE_DEV_SERVER_URL && h.webContents.openDevTools(), h.webContents.on("did-finish-load", () => {
    h?.webContents.send("main-process-message", (/* @__PURE__ */ new Date()).toLocaleString());
  }), process.env.VITE_DEV_SERVER_URL ? h.loadURL(process.env.VITE_DEV_SERVER_URL) : h.loadFile(o.join(process.env.DIST, "index.html"));
}
_.on("window-all-closed", () => {
  process.platform !== "darwin" && _.quit();
});
_.on("activate", () => {
  x.getAllWindows().length === 0 && N();
});
_.whenReady().then(() => {
  N(), J();
});
function J() {
  p.handle("run-match-selector", async (t, s) => P("api_match_selector.py", s)), p.handle("run-training-advisor", async (t, s) => P("api_training_advisor.py", s)), p.handle("run-rest-advisor", async (t, s) => P("api_rest_advisor.py", s));
  const l = o.join(S, "../data"), v = o.join(l, "app_state.json");
  p.handle("get-app-state", async () => {
    try {
      if (n.existsSync(v)) {
        const t = n.readFileSync(v, "utf-8");
        return JSON.parse(t);
      }
      return null;
    } catch (t) {
      return console.error("Error reading app state:", t), null;
    }
  }), p.handle("save-app-state", async (t, s) => {
    try {
      return n.existsSync(l) || n.mkdirSync(l, { recursive: !0 }), n.writeFileSync(v, JSON.stringify(s, null, 2), "utf-8"), { success: !0 };
    } catch (e) {
      return console.error("Error saving app state:", e), { success: !1, error: String(e) };
    }
  }), p.handle("get-player-list", async (t, s) => {
    try {
      const e = s?.statusFile || "players-current.csv", c = o.join(R, e);
      if (!n.existsSync(c))
        return { success: !1, error: `File not found: ${e}` };
      const i = n.readFileSync(c, "utf-8").split(`
`);
      if (i.length < 2)
        return { success: !1, error: "CSV file is empty or invalid" };
      const y = i[0].split(",").map((r) => r.trim().replace(/"/g, "")), T = y.findIndex((r) => r === "Name");
      let w = y.findIndex((r) => r === "Best Position");
      if (w === -1 && (w = y.findIndex((r) => r === "Positions")), T === -1)
        return { success: !1, error: "Required column (Name) not found" };
      const E = [], O = (r) => {
        const u = [];
        let d = "", f = !1;
        for (let g = 0; g < r.length; g++) {
          const I = r[g];
          I === '"' ? f = !f : I === "," && !f ? (u.push(d.trim()), d = "") : d += I;
        }
        return u.push(d.trim()), u;
      };
      for (let r = 1; r < i.length; r++) {
        const u = i[r].trim();
        if (!u) continue;
        const d = O(u), f = d[T], g = w !== -1 ? d[w] : "Unknown";
        f && f !== "" && E.push({ name: f, position: g || "Unknown" });
      }
      return E.sort((r, u) => r.name.localeCompare(u.name)), { success: !0, players: E };
    } catch (e) {
      return console.error("Error reading player list:", e), { success: !1, error: String(e) };
    }
  });
  const a = o.join(l, "confirmed_lineups.json");
  p.handle("get-confirmed-lineups", async () => {
    try {
      if (n.existsSync(a)) {
        const t = n.readFileSync(a, "utf-8");
        return JSON.parse(t);
      }
      return { lineups: [] };
    } catch (t) {
      return console.error("Error reading confirmed lineups:", t), { lineups: [] };
    }
  }), p.handle("save-confirmed-lineup", async (t, s) => {
    try {
      n.existsSync(l) || n.mkdirSync(l, { recursive: !0 });
      let e = { lineups: [] };
      return n.existsSync(a) && (e = JSON.parse(n.readFileSync(a, "utf-8"))), e.lineups = e.lineups.filter((c) => c.matchId !== s.matchId), e.lineups.push(s), e.lineups.sort((c, m) => c.date.localeCompare(m.date)), n.writeFileSync(a, JSON.stringify(e, null, 2), "utf-8"), { success: !0 };
    } catch (e) {
      return console.error("Error saving confirmed lineup:", e), { success: !1, error: String(e) };
    }
  });
}
function P(l, v) {
  return new Promise((a, t) => {
    const s = o.join(L, l), e = F(C, [s], { cwd: R });
    let c = "", m = "";
    e.stdin.write(JSON.stringify(v)), e.stdin.end(), e.stdout.on("data", (i) => {
      c += i.toString();
    }), e.stderr.on("data", (i) => {
      m += i.toString();
    }), e.on("close", (i) => {
      if (i !== 0)
        console.error(`Python script error (${i}):`, m), a({ success: !1, error: m || `Process exited with code ${i}` });
      else
        try {
          const y = JSON.parse(c);
          a(y);
        } catch {
          console.error("Failed to parse JSON output:", c), a({ success: !1, error: "Failed to parse Python output", raw: c });
        }
    });
  });
}
