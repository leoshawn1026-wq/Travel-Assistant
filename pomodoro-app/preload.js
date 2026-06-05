const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  // Window controls
  minimize: () => ipcRenderer.send('window-minimize'),
  close: () => ipcRenderer.send('window-close'),

  // Notifications
  showNotification: (title, body) => ipcRenderer.send('show-notification', { title, body }),

  // Flash taskbar
  flashTaskbar: () => ipcRenderer.send('flash-taskbar'),

  // App version
  getVersion: () => ipcRenderer.invoke('get-app-version'),
});
