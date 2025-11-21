import { app, BrowserWindow, ipcMain } from "electron";
import path from "path";
import { spawn } from "child_process";
import fs from "fs";
import { fileURLToPath } from "node:url";
const __dirname$1 = path.dirname(fileURLToPath(import.meta.url));
process.env.DIST = path.join(__dirname$1, "../dist");
process.env.VITE_PUBLIC = app.isPackaged ? process.env.DIST : path.join(__dirname$1, "../public");
let win;
const PROJECT_ROOT = path.resolve(__dirname$1, "../../");
const VENV_PYTHON = path.join(PROJECT_ROOT, "venv", "Scripts", "python.exe");
const SYSTEM_PYTHON = "python";
const PYTHON_PATH = fs.existsSync(VENV_PYTHON) ? VENV_PYTHON : SYSTEM_PYTHON;
const API_DIR = path.resolve(__dirname$1, "../api");
function createWindow() {
  win = new BrowserWindow({
    width: 1200,
    height: 800,
    backgroundColor: "#1e1b4b",
    // Dark blue/purple FM theme base
    webPreferences: {
      preload: path.join(__dirname$1, "preload.mjs"),
      nodeIntegration: false,
      contextIsolation: true
    }
  });
  if (process.env.VITE_DEV_SERVER_URL) {
    win.webContents.openDevTools();
  }
  win.webContents.on("did-finish-load", () => {
    win?.webContents.send("main-process-message", (/* @__PURE__ */ new Date()).toLocaleString());
  });
  if (process.env.VITE_DEV_SERVER_URL) {
    win.loadURL(process.env.VITE_DEV_SERVER_URL);
  } else {
    win.loadFile(path.join(process.env.DIST, "index.html"));
  }
}
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
app.whenReady().then(() => {
  createWindow();
  setupIpcHandlers();
});
function setupIpcHandlers() {
  ipcMain.handle("run-match-selector", async (event, args) => {
    return runPythonScript("api_match_selector.py", args);
  });
  ipcMain.handle("run-training-advisor", async (event, args) => {
    return runPythonScript("api_training_advisor.py", args);
  });
  ipcMain.handle("run-rest-advisor", async (event, args) => {
    return runPythonScript("api_rest_advisor.py", args);
  });
  const DATA_DIR = path.join(__dirname$1, "../data");
  const STATE_FILE = path.join(DATA_DIR, "app_state.json");
  ipcMain.handle("get-app-state", async () => {
    try {
      if (fs.existsSync(STATE_FILE)) {
        const data = fs.readFileSync(STATE_FILE, "utf-8");
        return JSON.parse(data);
      }
      return null;
    } catch (error) {
      console.error("Error reading app state:", error);
      return null;
    }
  });
  ipcMain.handle("save-app-state", async (event, state) => {
    try {
      if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
      }
      fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), "utf-8");
      return { success: true };
    } catch (error) {
      console.error("Error saving app state:", error);
      return { success: false, error: String(error) };
    }
  });
}
function runPythonScript(scriptName, args) {
  return new Promise((resolve, reject) => {
    const scriptPath = path.join(API_DIR, scriptName);
    const pyProcess = spawn(PYTHON_PATH, [scriptPath], { cwd: PROJECT_ROOT });
    let stdout = "";
    let stderr = "";
    pyProcess.stdin.write(JSON.stringify(args));
    pyProcess.stdin.end();
    pyProcess.stdout.on("data", (data) => {
      stdout += data.toString();
    });
    pyProcess.stderr.on("data", (data) => {
      stderr += data.toString();
    });
    pyProcess.on("close", (code) => {
      if (code !== 0) {
        console.error(`Python script error (${code}):`, stderr);
        resolve({ success: false, error: stderr || `Process exited with code ${code}` });
      } else {
        try {
          const jsonResponse = JSON.parse(stdout);
          resolve(jsonResponse);
        } catch (e) {
          console.error("Failed to parse JSON output:", stdout);
          resolve({ success: false, error: "Failed to parse Python output", raw: stdout });
        }
      }
    });
  });
}
