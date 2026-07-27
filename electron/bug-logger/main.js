const path = require('path')
const url = require('url')
const { app, BrowserWindow, Menu } = require('electron')
const Log = require('./src/models/Log.js')
const { ipcMain } = require('electron')
const connectDB = require('./src/config/db.js')
require('dotenv').config();

connectDB()

let mainWindow

const isDev = process.env.NODE_ENV === 'development'
const isMac = process.platform === "darwin" ? true : false;

const menu = [
	...(isMac ? [{ role: "appMenu" }] : []),
	{
		role: "fileMenu",
	},
	{
		role: "editMenu",
	},
	{
		label: "Logs",
		submenu: [
		{
			label: "Clear Logs",
			click: () => clearLogs(),
		},
		],
	},
	...(isDev
		? [
			{
			label: "Developer",
			submenu: [
				{ role: "reload" },
				{ role: "forcereload" },
				{ type: "separator" },
				{ role: "toggledevtools" },
			],
			},
		]
		: []),
];

function createMainWindow() {
	mainWindow = new BrowserWindow({
		width: 1100,
		height: 800,
		show: false,
		backgroundColor: 'white',
		icon: './assets/icon.png',
		webPreferences: {
			nodeIntegration: true,
			contextIsolation: false,
		},
	})

	let indexPath

	if (isDev && process.argv.indexOf('--noDevServer') === -1) {
		indexPath = url.format({
			protocol: 'http:',
			host: 'localhost:8080',
			pathname: 'index.html',
			slashes: true,
		})
	} else {
		indexPath = url.format({
			protocol: 'file:',
			pathname: path.join(__dirname, 'dist', 'index.html'),
			slashes: true,
		})
	}

	mainWindow.loadURL(indexPath)

	// Don't show until we are ready and loaded
	mainWindow.once('ready-to-show', () => {
		mainWindow.show()

		// Open devtools if dev
		if (isDev) {
			const {
				default: installExtension,
				REACT_DEVELOPER_TOOLS,
			} = require('electron-devtools-installer')

			installExtension(REACT_DEVELOPER_TOOLS).catch((err) =>
				console.log('Error loading React DevTools: ', err)
			)
			mainWindow.webContents.openDevTools()
		}
	})

	mainWindow.on('closed', () => (mainWindow = null))
}


app.on('ready', () => {
	createMainWindow()
	const appMenu = Menu.buildFromTemplate(menu);
  	Menu.setApplicationMenu(appMenu);
})

app.on('window-all-closed', () => {
	if (process.platform !== 'darwin') {
		app.quit()
	}
})

app.on('activate', () => {
	if (mainWindow === null) {
		createMainWindow()
	}
})

// Stop error
app.allowRendererProcessReuse = true


async function sendLogs() {
  try {
    const logs = await Log.find().sort({ created: 1 });
    mainWindow.webContents.send("logs:get", JSON.stringify(logs));
  } catch (err) {
    console.log(err);
  }
}
async function clearLogs() {
  try {
    await Log.deleteMany({});
    mainWindow.webContents.send("logs:clear");
  } catch (err) {
    console.log(err);
  }
}


ipcMain.handle('logs:load', sendLogs);

ipcMain.handle('logs:add', async (event, log) => {
	try {
		await Log.create(log);
		sendLogs();
	} catch (err) {
		console.error('Add log failed:', err);
		throw err; // Forward error to renderer
	}
});
ipcMain.handle('logs:delete', async (event, id) => {
	try {
		await Log.findByIdAndDelete(id);
		sendLogs();
	} catch (err) {
		console.error('Delete log failed:', err);
		throw err; // Forward error to renderer
	}
});


