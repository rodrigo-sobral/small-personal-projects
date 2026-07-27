const path = require('path');
const osu = require('node-os-utils');

const cpu = osu.cpu;
const mem = osu.mem;
const os = osu.os;
const disk = osu.drive;

// Set model
document.getElementById('cpu-model').innerText = cpu.model();
document.getElementById('comp-name').innerText = os.hostname();
document.getElementById('os-name').innerText = os.platform() + ' ' + os.arch();

// Info to be updated every second
setInterval(() => {
    cpu.usage().then(info => {
        document.getElementById('cpu-usage').innerText = info + '%';
        document.getElementById('cpu-progress').style.width = info + '%';
        if (info >= document.getElementById('cpu-overload').value) {
            document.getElementById('cpu-progress').style.background = 'red';
            if (runNotify(document.getElementById('alert-frequency').value)) {
                notifyUser({
                    title: "CPU Overload",
                    body: `CPU usage is over ${document.getElementById('cpu-overload').value}%, please check the system.`,
                    icon: path.join(__dirname, 'icons', 'icon.png')
                });
                localStorage.setItem('lastNotify', Date.now());
            }
        }
        else document.getElementById('cpu-progress').style.background = '#30c88b';
    });
    cpu.free().then(info => {
        document.getElementById('cpu-free').innerText = info.toFixed(2) + '%';
    });
    
    document.getElementById('sys-uptime').innerText = (() => {
        const uptime = os.uptime();
        const days = Math.floor(uptime / (24 * 3600));
        const hours = Math.floor((uptime % (24 * 3600)) / 3600);
        const minutes = Math.floor((uptime % 3600) / 60);
        const seconds = uptime % 60;
        return `${days}d ${hours}h ${minutes}m ${seconds}s`;
    })();

    mem.info().then(info => {
        document.getElementById('mem-used').innerText = (info.usedMemMb / 1024).toFixed(2) + ' / ' + (info.totalMemMb / 1024) + ' GB (' + info.usedMemPercentage + '%)';
        document.getElementById('mem-progress-used').style.width = info.usedMemPercentage + '%';
    });
    disk.info().then(info => {
        document.getElementById('disk-used').innerText = info.usedGb + ' / ' + info.totalGb + ' GB (' + info.usedPercentage + '%)';
        document.getElementById('disk-progress-used').style.width = info.usedPercentage + '%';
    });
}, 1000);

function notifyUser(options) {
    new Notification(options.title, options);

}

function runNotify(frequency) {
    const lastNotify = localStorage.getItem('lastNotify');
    const now = Date.now();
    if (!lastNotify) {
        localStorage.setItem('lastNotify', now);
        return true;
    }
    const diff = Math.ceil(Math.abs(now - parseInt(lastNotify)) / (1000*60)); // in minutes
    return diff > frequency;
}