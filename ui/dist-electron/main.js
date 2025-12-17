import { app as w, BrowserWindow as N, ipcMain as l } from "electron";
import i from "path";
import { spawn as F } from "child_process";
import n from "fs";
import { fileURLToPath as V } from "node:url";
const S = i.dirname(V(import.meta.url));
process.env.DIST = i.join(S, "../dist");
process.env.VITE_PUBLIC = w.isPackaged ? process.env.DIST : i.join(S, "../public");
let h;
const R = i.resolve(S, "../../"), x = i.join(R, "venv", "Scripts", "python.exe"), D = "python", C = n.existsSync(x) ? x : D, J = i.resolve(S, "../api");
function O() {
  h = new N({
    width: 1200,
    height: 800,
    backgroundColor: "#1e1b4b",
    // Dark blue/purple FM theme base
    webPreferences: {
      preload: i.join(S, "preload.mjs"),
      nodeIntegration: !1,
      contextIsolation: !0
    }
  }), process.env.VITE_DEV_SERVER_URL && h.webContents.openDevTools(), h.webContents.on("did-finish-load", () => {
    h?.webContents.send("main-process-message", (/* @__PURE__ */ new Date()).toLocaleString());
  }), process.env.VITE_DEV_SERVER_URL ? h.loadURL(process.env.VITE_DEV_SERVER_URL) : h.loadFile(i.join(process.env.DIST, "index.html"));
}
w.on("window-all-closed", () => {
  process.platform !== "darwin" && w.quit();
});
w.on("activate", () => {
  N.getAllWindows().length === 0 && O();
});
w.whenReady().then(() => {
  O(), L();
});
function L() {
  l.handle("run-match-selector", async (t, r) => _("api_match_selector.py", r)), l.handle("run-training-advisor", async (t, r) => _("api_training_advisor.py", r)), l.handle("run-rest-advisor", async (t, r) => _("api_rest_advisor.py", r)), l.handle("run-player-removal-advisor", async (t, r) => _("api_player_removal.py", r)), l.handle("run-rotation-selector", async (t, r) => _("api_rotation_selector.py", r));
  const u = i.join(S, "../data"), v = i.join(u, "app_state.json");
  l.handle("get-app-state", async () => {
    try {
      if (n.existsSync(v)) {
        const t = n.readFileSync(v, "utf-8");
        return JSON.parse(t);
      }
      return null;
    } catch (t) {
      return console.error("Error reading app state:", t), null;
    }
  }), l.handle("save-app-state", async (t, r) => {
    try {
      return n.existsSync(u) || n.mkdirSync(u, { recursive: !0 }), n.writeFileSync(v, JSON.stringify(r, null, 2), "utf-8"), { success: !0 };
    } catch (e) {
      return console.error("Error saving app state:", e), { success: !1, error: String(e) };
    }
  }), l.handle("get-player-list", async (t, r) => {
    try {
      const e = r?.statusFile || "players-current.csv", o = i.join(R, e);
      if (!n.existsSync(o))
        return { success: !1, error: `File not found: ${e}` };
      const a = n.readFileSync(o, "utf-8").split(`
`);
      if (a.length < 2)
        return { success: !1, error: "CSV file is empty or invalid" };
      const m = a[0].split(",").map((s) => s.trim().replace(/"/g, "")), T = m.findIndex((s) => s === "Name");
      let E = m.findIndex((s) => s === "Best Position");
      if (E === -1 && (E = m.findIndex((s) => s === "Positions")), T === -1)
        return { success: !1, error: "Required column (Name) not found" };
      const I = [], j = (s) => {
        const d = [];
        let f = "", y = !1;
        for (let g = 0; g < s.length; g++) {
          const P = s[g];
          P === '"' ? y = !y : P === "," && !y ? (d.push(f.trim()), f = "") : f += P;
        }
        return d.push(f.trim()), d;
      };
      for (let s = 1; s < a.length; s++) {
        const d = a[s].trim();
        if (!d) continue;
        const f = j(d), y = f[T], g = E !== -1 ? f[E] : "Unknown";
        y && y !== "" && I.push({ name: y, position: g || "Unknown" });
      }
      return I.sort((s, d) => s.name.localeCompare(d.name)), { success: !0, players: I };
    } catch (e) {
      return console.error("Error reading player list:", e), { success: !1, error: String(e) };
    }
  });
  const c = i.join(u, "confirmed_lineups.json");
  l.handle("get-confirmed-lineups", async () => {
    try {
      if (n.existsSync(c)) {
        const t = n.readFileSync(c, "utf-8");
        return JSON.parse(t);
      }
      return { lineups: [] };
    } catch (t) {
      return console.error("Error reading confirmed lineups:", t), { lineups: [] };
    }
  }), l.handle("save-confirmed-lineup", async (t, r) => {
    try {
      n.existsSync(u) || n.mkdirSync(u, { recursive: !0 });
      let e = { lineups: [] };
      return n.existsSync(c) && (e = JSON.parse(n.readFileSync(c, "utf-8"))), e.lineups = e.lineups.filter((o) => o.matchId !== r.matchId), e.lineups.push(r), e.lineups.sort((o, p) => o.date.localeCompare(p.date)), n.writeFileSync(c, JSON.stringify(e, null, 2), "utf-8"), { success: !0 };
    } catch (e) {
      return console.error("Error saving confirmed lineup:", e), { success: !1, error: String(e) };
    }
  }), l.handle("remove-confirmed-lineup", async (t, r) => {
    try {
      if (!n.existsSync(c))
        return { success: !0 };
      const e = JSON.parse(n.readFileSync(c, "utf-8"));
      return e.lineups = e.lineups.filter((o) => o.matchId !== r), n.writeFileSync(c, JSON.stringify(e, null, 2), "utf-8"), { success: !0 };
    } catch (e) {
      return console.error("Error removing confirmed lineup:", e), { success: !1, error: String(e) };
    }
  });
}
function _(u, v) {
  return new Promise((c, t) => {
    const r = i.join(J, u), e = F(C, [r], { cwd: R });
    let o = "", p = "";
    e.stdin.write(JSON.stringify(v)), e.stdin.end(), e.stdout.on("data", (a) => {
      o += a.toString();
    }), e.stderr.on("data", (a) => {
      p += a.toString();
    }), e.on("close", (a) => {
      if (p && console.log(`[Python ${u}] stderr:`, p), a !== 0)
        console.error(`Python script error (${a}):`, p), c({ success: !1, error: p || `Process exited with code ${a}` });
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
