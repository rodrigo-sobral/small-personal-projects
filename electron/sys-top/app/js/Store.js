const electron = require('electron');
const path = require('path');
const fs = require('fs');

class Store {
    defaults = {
        settings: {
            cpuOverload: 80,
            alertFrequency: 5,
        }
    };

    constructor(configFileName) {
        const userDataPath = (electron.app || electron.remote.app).getPath('userData');
        this.path = path.join(userDataPath, configFileName + '.json');
        this.data = parseDataFile(this.path);
    }

    get(key) {
        return this.data[key];
    }

    set(key, value) {
        this.data[key] = value;
        fs.writeFileSync(this.path, JSON.stringify(this.data));
    }
}

function parseDataFile(filePath) {
    try {
        return JSON.parse(fs.readFileSync(filePath));
    } catch (error) {
        if (error.code === 'ENOENT') {
            return this.defaults || {};
        } else {
            console.error(`Error reading file ${filePath}:`, error);
            return {};
        }
    }
}

module.exports = Store;