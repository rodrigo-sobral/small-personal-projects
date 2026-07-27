const { app, ipcMain } = require('electron')
const path = require('path')
const Store = require('./app/js/Store.js')
const MainWindow = require('./app/js/MainWindow.js')
const AppTray = require('./app/js/AppTray.js')
const buildMenu = require('./app/js/AppMenu.js').buildMenu

process.env.NODE_ENV = 'production'
// process.env.NODE_ENV = 'development'

let mainWindow, tray
app.isDev = process.env.NODE_ENV !== 'production';
app.isMac = process.platform === 'darwin';
app.allowRendererProcessReuse = true;

// Init store and defaults
const store = new Store('user-settings')

app.on('ready', () => {
  const icon = path.join(__dirname, 'app', 'icons', 'icon.png')
  const tray_icon = path.join(__dirname, 'app', 'icons', 'tray_icon.png')
  
  mainWindow = new MainWindow(app, store, 'app/index.html')
  buildMenu(mainWindow)

  app.dock.setIcon(icon)
  tray = new AppTray(app, tray_icon, mainWindow)
})

app.on('window-all-closed', () => {
  if (!app.isMac) app.quit()
})
app.on('before-quit', () => {
  app.isQuitting = true
  if (tray) tray.tray.destroy() // Clean up tray icon
})
app.on('activate', () => {
  if (mainWindow) {
    mainWindow.isVisible() ? mainWindow.focus() : mainWindow.show()
  }
})

ipcMain.on('settings:set', (event, settings) => {
  store.set('settings', settings)
  mainWindow.webContents.send('settings:get', store.get('settings'))
})
