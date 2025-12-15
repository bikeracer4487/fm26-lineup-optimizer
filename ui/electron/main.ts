import { app, BrowserWindow, ipcMain } from 'electron'
import path from 'path'
import { spawn } from 'child_process'
import fs from 'fs'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// The built directory structure
// dist-electron/main.js
// dist-index.html
// public
process.env.DIST = path.join(__dirname, '../dist')
process.env.VITE_PUBLIC = app.isPackaged ? process.env.DIST : path.join(__dirname, '../public')

let win: BrowserWindow | null

// Path to Python Interpreter
// In dev: ../../venv/Scripts/python.exe (from ui/dist-electron/main.js) -> relative to project root
// We need to resolve this carefully.
const PROJECT_ROOT = path.resolve(__dirname, '../../') 
const VENV_PYTHON = path.join(PROJECT_ROOT, 'venv', 'Scripts', 'python.exe')
const SYSTEM_PYTHON = 'python'

const PYTHON_PATH = fs.existsSync(VENV_PYTHON) ? VENV_PYTHON : SYSTEM_PYTHON

// API Scripts Path
const API_DIR = path.resolve(__dirname, '../api')

function createWindow() {
  win = new BrowserWindow({
    width: 1200,
    height: 800,
    backgroundColor: '#1e1b4b', // Dark blue/purple FM theme base
    webPreferences: {
      preload: path.join(__dirname, 'preload.mjs'),
      nodeIntegration: false,
      contextIsolation: true,
    },
  })

  // Open DevTools in development
  if (process.env.VITE_DEV_SERVER_URL) {
    win.webContents.openDevTools()
  }

  // Test active push message to Renderer-process.
  win.webContents.on('did-finish-load', () => {
    win?.webContents.send('main-process-message', (new Date).toLocaleString())
  })

  if (process.env.VITE_DEV_SERVER_URL) {
    win.loadURL(process.env.VITE_DEV_SERVER_URL)
  } else {
    // win.loadFile('dist/index.html')
    win.loadFile(path.join(process.env.DIST, 'index.html'))
  }
}

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow()
  }
})

app.whenReady().then(() => {
  createWindow()
  setupIpcHandlers()
})

function setupIpcHandlers() {
  // 1. Run Match Selector
  ipcMain.handle('run-match-selector', async (event, args) => {
    return runPythonScript('api_match_selector.py', args)
  })

  // 2. Run Training Advisor
  ipcMain.handle('run-training-advisor', async (event, args) => {
    return runPythonScript('api_training_advisor.py', args)
  })

  // 3. Run Rest Advisor
  ipcMain.handle('run-rest-advisor', async (event, args) => {
    return runPythonScript('api_rest_advisor.py', args)
  })

  // 3b. Run Player Removal Advisor
  ipcMain.handle('run-player-removal-advisor', async (event, args) => {
    return runPythonScript('api_player_removal.py', args)
  })

  // 4. App State Management
  const DATA_DIR = path.join(__dirname, '../data')
  const STATE_FILE = path.join(DATA_DIR, 'app_state.json')

  ipcMain.handle('get-app-state', async () => {
    try {
      if (fs.existsSync(STATE_FILE)) {
        const data = fs.readFileSync(STATE_FILE, 'utf-8')
        return JSON.parse(data)
      }
      return null
    } catch (error) {
      console.error('Error reading app state:', error)
      return null
    }
  })

  ipcMain.handle('save-app-state', async (event, state) => {
    try {
      if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true })
      }
      fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), 'utf-8')
      return { success: true }
    } catch (error) {
      console.error('Error saving app state:', error)
      return { success: false, error: String(error) }
    }
  })
  
  // 5. Get Player List (for override modal)
  ipcMain.handle('get-player-list', async (event, args) => {
    try {
      const filename = args?.statusFile || 'players-current.csv'
      const csvPath = path.join(PROJECT_ROOT, filename)

      if (!fs.existsSync(csvPath)) {
        return { success: false, error: `File not found: ${filename}` }
      }

      const content = fs.readFileSync(csvPath, 'utf-8')
      const lines = content.split('\n')

      if (lines.length < 2) {
        return { success: false, error: 'CSV file is empty or invalid' }
      }

      // Parse header to find column indices
      const header = lines[0].split(',').map(h => h.trim().replace(/"/g, ''))
      const nameIdx = header.findIndex(h => h === 'Name')
      // Try 'Best Position' first, then fall back to 'Positions'
      let posIdx = header.findIndex(h => h === 'Best Position')
      if (posIdx === -1) {
        posIdx = header.findIndex(h => h === 'Positions')
      }

      if (nameIdx === -1) {
        return { success: false, error: 'Required column (Name) not found' }
      }

      // Parse rows (skip header)
      const players: { name: string, position: string }[] = []

      // CSV parser that handles quoted fields with commas
      const parseCSVLine = (line: string): string[] => {
        const result: string[] = []
        let current = ''
        let inQuotes = false

        for (let j = 0; j < line.length; j++) {
          const char = line[j]
          if (char === '"') {
            inQuotes = !inQuotes
          } else if (char === ',' && !inQuotes) {
            result.push(current.trim())
            current = ''
          } else {
            current += char
          }
        }
        result.push(current.trim())
        return result
      }

      for (let i = 1; i < lines.length; i++) {
        const line = lines[i].trim()
        if (!line) continue

        const values = parseCSVLine(line)
        const name = values[nameIdx]
        const position = posIdx !== -1 ? values[posIdx] : 'Unknown'

        if (name && name !== '') {
          players.push({ name, position: position || 'Unknown' })
        }
      }

      // Sort alphabetically by name
      players.sort((a, b) => a.name.localeCompare(b.name))

      return { success: true, players }
    } catch (error) {
      console.error('Error reading player list:', error)
      return { success: false, error: String(error) }
    }
  })

  // 6. Confirmed Lineups Management
  const CONFIRMED_LINEUPS_FILE = path.join(DATA_DIR, 'confirmed_lineups.json')

  ipcMain.handle('get-confirmed-lineups', async () => {
    try {
      if (fs.existsSync(CONFIRMED_LINEUPS_FILE)) {
        const data = fs.readFileSync(CONFIRMED_LINEUPS_FILE, 'utf-8')
        return JSON.parse(data)
      }
      return { lineups: [] }
    } catch (error) {
      console.error('Error reading confirmed lineups:', error)
      return { lineups: [] }
    }
  })

  ipcMain.handle('save-confirmed-lineup', async (event, lineup) => {
    try {
      if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true })
      }

      // Load existing
      let data = { lineups: [] as any[] }
      if (fs.existsSync(CONFIRMED_LINEUPS_FILE)) {
        data = JSON.parse(fs.readFileSync(CONFIRMED_LINEUPS_FILE, 'utf-8'))
      }

      // Remove existing entry for same matchId if any
      data.lineups = data.lineups.filter((l: any) => l.matchId !== lineup.matchId)

      // Add new lineup
      data.lineups.push(lineup)

      // Sort by date
      data.lineups.sort((a: any, b: any) => a.date.localeCompare(b.date))

      fs.writeFileSync(CONFIRMED_LINEUPS_FILE, JSON.stringify(data, null, 2), 'utf-8')
      return { success: true }
    } catch (error) {
      console.error('Error saving confirmed lineup:', error)
      return { success: false, error: String(error) }
    }
  })

  ipcMain.handle('remove-confirmed-lineup', async (event, matchId: string) => {
    try {
      if (!fs.existsSync(CONFIRMED_LINEUPS_FILE)) {
        return { success: true } // Nothing to remove
      }

      const data = JSON.parse(fs.readFileSync(CONFIRMED_LINEUPS_FILE, 'utf-8'))
      data.lineups = data.lineups.filter((l: any) => l.matchId !== matchId)
      fs.writeFileSync(CONFIRMED_LINEUPS_FILE, JSON.stringify(data, null, 2), 'utf-8')
      return { success: true }
    } catch (error) {
      console.error('Error removing confirmed lineup:', error)
      return { success: false, error: String(error) }
    }
  })

  // 4. File Picker (Dialog) - if needed for selecting CSVs
  // ipcMain.handle('select-file', ...)
}

function runPythonScript(scriptName: string, args: any): Promise<any> {
  return new Promise((resolve, reject) => {
    const scriptPath = path.join(API_DIR, scriptName)
    
    // Spawn python process
    const pyProcess = spawn(PYTHON_PATH, [scriptPath], { cwd: PROJECT_ROOT })
    
    let stdout = ''
    let stderr = ''

    // Send JSON input to stdin
    pyProcess.stdin.write(JSON.stringify(args))
    pyProcess.stdin.end()

    pyProcess.stdout.on('data', (data) => {
      stdout += data.toString()
    })

    pyProcess.stderr.on('data', (data) => {
      stderr += data.toString()
    })

    pyProcess.on('close', (code) => {
      // Always log stderr if there's any output (for debugging)
      if (stderr) {
        console.log(`[Python ${scriptName}] stderr:`, stderr)
      }

      if (code !== 0) {
        console.error(`Python script error (${code}):`, stderr)
        resolve({ success: false, error: stderr || `Process exited with code ${code}` })
      } else {
        try {
          // Try to parse the last line or the whole output as JSON
          // The scripts print JSON as the final output
          // But there might be other stdout noise if we missed something (though we tried to strip prints)
          const jsonResponse = JSON.parse(stdout)
          resolve(jsonResponse)
        } catch (e) {
            console.error("Failed to parse JSON output:", stdout)
            resolve({ success: false, error: "Failed to parse Python output", raw: stdout })
        }
      }
    })
  })
}

