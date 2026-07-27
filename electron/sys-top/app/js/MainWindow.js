const { BrowserWindow } = require('electron');
const path = require('path');

class MainWindow extends BrowserWindow {
    constructor(app, store, template) {
        super({
            title: 'SysTop',
            width: app.isDev ? 700 : 450,
            height: 600,
            icon: path.join(__dirname, 'app', 'icons', 'icon.png'),
            resizable: app.isDev,
            show: false,
            opacity: app.isDev ? 0.75 : 0.9,
            backgroundColor: 'white',
            webPreferences: {
                nodeIntegration: true,
                contextIsolation: false,
                // preload: path.join(__dirname, 'preload.js') // safer alternative if used
            },
        });

        if (app.isDev) this.webContents.openDevTools();

        this.loadFile(template).catch(err => {
            console.error('Failed to load template:', err);
        });

        // Properly capture 'e' here
        this.on('close', (e) => this.onClose(e, app));

        this.webContents.on('dom-ready', () => this.onReady(store));
    }

    onReady(store) {
        this.webContents.send('settings:get', store.get('settings'));
    }

    onClose(e, app) {
        if (app.isMac && !app.isQuitting) {
            e.preventDefault();
            this.hide();
        }
    }
}

module.exports = MainWindow;
