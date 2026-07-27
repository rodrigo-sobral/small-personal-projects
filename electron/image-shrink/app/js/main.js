const path = require('path');
const os = require('os');
const { ipcRenderer } = require('electron');

const form = document.getElementById('image-form');
const slider = document.getElementById('slider');
const img = document.getElementById('img');
const sliderValue = document.getElementById('slider-value');

sliderValue.textContent = slider.value;
slider.addEventListener('input', () => {
    sliderValue.textContent = slider.value;
});

document.getElementById('output-path').innerText = path.join(os.homedir(), 'imageshrink');

form.addEventListener('submit', (e) => {
    e.preventDefault();

    const imgPath = img.files[0].path;
    const quality = slider.value;

    ipcRenderer.send('image:minimize', {
        imgPath, quality
    });
});

ipcRenderer.on('image:minimize:response', (e, { success, error }) => {
    const response_text = success ? `Image minimized to ${slider.value}% quality` : `Error minimizing image: ${error}`;
    M.toast({ html: response_text });
});
