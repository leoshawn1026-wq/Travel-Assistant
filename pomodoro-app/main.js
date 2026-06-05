const { app, BrowserWindow, Tray, Menu, globalShortcut, nativeImage, Notification, ipcMain } = require('electron');
const path = require('path');

// ===== State =====
let mainWindow = null;
let tray = null;
let isQuitting = false;

// ===== Window =====
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 750,
    height: 620,
    minWidth: 480,
    minHeight: 560,
    frame: false,
    resizable: true,
    show: false,
    backgroundColor: '#F5F5F5',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  // Show when ready (avoids white flash)
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  // Minimize to tray instead of closing
  mainWindow.on('close', (e) => {
    if (!isQuitting) {
      e.preventDefault();
      mainWindow.hide();
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// ===== Tray =====
function createTrayIcon(size) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">
    <circle cx="${size / 2}" cy="${size / 2}" r="${size / 2 - 1}" fill="#E84C3D"/>
  </svg>`;
  const dataUrl = 'data:image/svg+xml;base64,' + Buffer.from(svg).toString('base64');
  return nativeImage.createFromDataURL(dataUrl);
}

function createTray() {
  try {
    tray = new Tray(createTrayIcon(16));
  } catch {
    return;
  }

  tray.setToolTip('🍅 番茄钟');

  const contextMenu = Menu.buildFromTemplate([
    {
      label: '显示窗口',
      click: toggleWindow,
    },
    { type: 'separator' },
    {
      label: '退出',
      click: () => {
        isQuitting = true;
        app.quit();
      },
    },
  ]);

  tray.setContextMenu(contextMenu);
  tray.on('click', toggleWindow);
}

function toggleWindow() {
  if (!mainWindow) return;
  if (mainWindow.isVisible()) {
    mainWindow.hide();
  } else {
    mainWindow.show();
    mainWindow.focus();
  }
}

// ===== Global Shortcut =====
function registerShortcuts() {
  globalShortcut.register('CommandOrControl+Shift+T', toggleWindow);
}

// ===== IPC: System Notification =====
ipcMain.on('show-notification', (_event, { title, body }) => {
  if (Notification.isSupported()) {
    const notif = new Notification({ title, body });
    notif.on('click', toggleWindow);
    notif.show();
  }
});

// ===== IPC: Window Controls =====
ipcMain.on('window-minimize', () => {
  if (mainWindow) mainWindow.minimize();
});

ipcMain.on('window-close', () => {
  if (mainWindow) mainWindow.hide();
});

// ===== IPC: Flash taskbar =====
ipcMain.on('flash-taskbar', () => {
  if (mainWindow) {
    mainWindow.flashFrame(true);
    setTimeout(() => {
      if (mainWindow) mainWindow.flashFrame(false);
    }, 5000);
  }
});

// ===== IPC: App version =====
ipcMain.handle('get-app-version', () => {
  return app.getVersion();
});

// ===== App Lifecycle =====
app.whenReady().then(() => {
  createWindow();
  createTray();
  registerShortcuts();
});

app.on('window-all-closed', () => {
  // App stays alive in system tray — handled by close event
});

app.on('activate', () => {
  if (mainWindow === null) {
    createWindow();
  } else {
    mainWindow.show();
  }
});

app.on('before-quit', () => {
  isQuitting = true;
});

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
});
