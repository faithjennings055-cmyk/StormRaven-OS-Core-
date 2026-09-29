/* Secure bridge: exposes kernel status to the PWA renderer. */
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('stormravenDesktop', {
  getStatus: () => ipcRenderer.invoke('kernel-status'),
  onStatus: (cb) => ipcRenderer.on('kernel-status', (_e, data) => cb(data)),
});
