import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './components/App';
import 'bootstrap/dist/css/bootstrap.min.css';

// Create and append root element
const rootElement = document.createElement('div');
rootElement.id = 'root';
document.body.appendChild(rootElement);

// Use the new createRoot API
const root = createRoot(document.getElementById('root'));
root.render(<App />);
