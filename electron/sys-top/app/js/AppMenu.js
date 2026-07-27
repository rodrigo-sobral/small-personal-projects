const { app, Menu } = require('electron');


function buildMenu(mainWindow) {
    const menu = [
      ...(app.isMac ? [{ role: 'appMenu' }] : []),
      {
        role: 'fileMenu',
      },
      {
        label: 'View',
        submenu: [
          { 
            label: 'Toggle Navigation', 
            click: () => mainWindow.webContents.send('toggle:nav')
          },
        ],
      },
      ...(app.isDev
        ? [
            {
              label: 'Developer',
              submenu: [
                { role: 'reload' },
                { role: 'forcereload' },
                { type: 'separator' },
                { role: 'toggledevtools' },
              ],
            },
          ]
        : []),
    ]
  const appMenu = Menu.buildFromTemplate(menu);
  Menu.setApplicationMenu(appMenu);
}

module.exports = {
  buildMenu,
};