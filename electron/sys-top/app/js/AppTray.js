const { Menu, Tray } = require('electron');

class AppTray {
  constructor(app, iconPath, mainWindow) {
    this.tray = new Tray(iconPath);
    this.mainWindow = mainWindow;

    this.tray.setToolTip('SysTop');

    // Arrow functions here preserve context correctly
    this.tray.on('click', () => this.onClick());
    this.tray.on('right-click', () => this.onRightClick(app));
  }

  onClick() {
    this.mainWindow.isVisible() ? this.mainWindow.hide() : this.mainWindow.show();
  }

  onRightClick() {
    const contextMenu = Menu.buildFromTemplate([
      {
        label: 'Show',
        click: () => this.mainWindow.show(),
      },
      {
        label: 'Quit',
        click: () => {
          app.isQuitting = true;
          app.quit();
        },
      },
    ]);
    this.tray.popUpContextMenu(contextMenu);
  }
}

module.exports = AppTray;
