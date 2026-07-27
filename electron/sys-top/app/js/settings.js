const { ipcRenderer } = require('electron');

const cpuOverloadInput = document.getElementById('cpu-overload');
const alertFrequencyInput = document.getElementById('alert-frequency');

// Get settings
ipcRenderer.on('settings:get', (event, settings) => {
    cpuOverloadInput.value = settings.cpuOverload;
    alertFrequencyInput.value = settings.alertFrequency;
});

// Submit settings
const settingsForm = document.getElementById('settings-form');
settingsForm.onsubmit = (event) => {
    event.preventDefault();

    // Send settings to main process
    ipcRenderer.send('settings:set', {
        cpuOverload: cpuOverloadInput.value,
        alertFrequency: alertFrequencyInput.value
    });
    showAlert('Settings saved successfully!', 'success');
};

function showAlert(message, type) {
    const alertBox = document.createElement('div');
    alertBox.className = `alert alert-${type}`;
    alertBox.textContent = message;
    document.body.appendChild(alertBox);

    setTimeout(() => {
        alertBox.remove();
    }, 3000);
}

ipcRenderer.on('toggle:nav', (event) => {
    const nav = document.getElementById('nav');
    nav.style.display = nav.style.display === 'none' ? 'block' : 'none';
});