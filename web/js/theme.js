const CROP_COLORS = {
    apple: '#e63946',
    tomato: '#f4511e',
    corn: '#f2c14e',
    orange: '#f39c12',
};

const DEFAULT_ACCENT = '#e63946';

function applyCropAccent(crop) {
    const color = (crop && CROP_COLORS[crop]) || DEFAULT_ACCENT;
    document.documentElement.style.setProperty('--crop-accent', color);
}
