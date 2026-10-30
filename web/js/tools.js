const toolsContainer = document.getElementById('tools-container');

let toolsMode = 'place';
let toolsCrop = 'apple';
let toolsHeading = 0;

function toolsInput(id) {
    return document.getElementById(id);
}

function toolsHexToRgba(hex, alpha) {
    const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex || '');

    if (!m) return `rgba(255, 255, 255, ${alpha})`;

    return `rgba(${parseInt(m[1], 16)}, ${parseInt(m[2], 16)}, ${parseInt(m[3], 16)}, ${alpha})`;
}

function applyToolsAccent(crop) {
    const panel = document.querySelector('.tools-panel');
    const color = (typeof CROP_COLORS !== 'undefined' && CROP_COLORS[crop]) || '';

    if (panel) {
        panel.style.setProperty('--tools-accent', color);
        panel.style.setProperty('--tools-accent-soft', toolsHexToRgba(color, 0.1));
    }

    const icon = document.getElementById('tools-crop-icon');
    if (icon) icon.src = `images/${crop}.png`;
}

function renderToolsCrops(crops) {
    const list = document.getElementById('tools-crops');
    if (!list) return;

    list.innerHTML = (crops || []).map(function (crop) {
        const active = crop.key === toolsCrop ? ' active' : '';

        return `<button class="tools-chip${active}" data-crop="${crop.key}">${crop.label}</button>`;
    }).join('');
}

function renderToolsMode() {
    document.querySelectorAll('#tools-mode .tools-chip').forEach(function (chip) {
        chip.classList.toggle('active', chip.dataset.mode === toolsMode);
    });

    const spacingRow = document.getElementById('tools-spacing-row');
    if (spacingRow) spacingRow.classList.toggle('dimmed', toolsMode !== 'line');
}

function openToolsPanel(data) {
    if (!toolsContainer) return;

    const info = data || {};

    toolsCrop = (info.crops && info.crops[0] && info.crops[0].key) || 'apple';
    toolsMode = 'place';
    toolsHeading = Number(info.heading) || 0;

    renderToolsCrops(info.crops);
    renderToolsMode();
    applyToolsAccent(toolsCrop);

    const spacing = toolsInput('tools-spacing');
    const height = toolsInput('tools-height');
    const heading = toolsInput('tools-heading');

    if (spacing) spacing.value = String(info.defaultSpacing || 4.0);
    if (height) height.value = '0';
    if (heading) heading.value = String(Math.round(toolsHeading));

    toolsContainer.classList.remove('hidden');
}

function closeToolsPanel() {
    if (!toolsContainer) return;

    toolsContainer.classList.add('hidden');

    fetch('https://ddev_farm/closeTools', { method: 'POST' });
}

function startToolsPlacement() {
    const spacing = toolsInput('tools-spacing');
    const height = toolsInput('tools-height');
    const heading = toolsInput('tools-heading');

    const payload = {
        crop: toolsCrop,
        mode: toolsMode,
        spacing: Number(spacing && spacing.value) || 4.0,
        height: Number(height && height.value) || 0.0,
        heading: Number(heading && heading.value) || 0.0,
    };

    if (toolsContainer) toolsContainer.classList.add('hidden');

    fetch('https://ddev_farm/toolsStart', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
    }).catch(function () {});
}

function setNpcFromTools() {
    const status = document.getElementById('tools-npc-status');

    if (status) status.textContent = 'Saving...';

    fetch('https://ddev_farm/adminAction', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'setNpcPos', data: null }),
    }).then(function () {
        if (status) status.textContent = 'Saved. Restart ddev_farm to apply.';
    }).catch(function () {
        if (status) status.textContent = 'Failed.';
    });
}

if (toolsContainer) {
    toolsContainer.addEventListener('click', function (e) {
        const modeChip = e.target.closest('#tools-mode .tools-chip');
        if (modeChip) {
            toolsMode = modeChip.dataset.mode;
            renderToolsMode();
            return;
        }

        const cropChip = e.target.closest('#tools-crops .tools-chip');
        if (cropChip) {
            toolsCrop = cropChip.dataset.crop;

            document.querySelectorAll('#tools-crops .tools-chip').forEach(function (chip) {
                chip.classList.toggle('active', chip === cropChip);
            });

            applyToolsAccent(toolsCrop);

            return;
        }

        const stepBtn = e.target.closest('.tools-stepper button[data-step]');
        if (stepBtn) {
            const input = toolsInput(`tools-${stepBtn.dataset.step}`);
            const dir = Number(stepBtn.dataset.dir) || 0;

            if (input) {
                const step = Number(input.step) || 1;
                let value = (Number(input.value) || 0) + dir * step;

                if (input.min !== '') value = Math.max(Number(input.min), value);
                if (input.max !== '') value = Math.min(Number(input.max), value);

                input.value = String(Math.round(value * 100) / 100);
            }
        }
    });
}

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'toolsOpen') {
        openToolsPanel(data.data);
    } else if (data.action === 'toolsClose') {
        if (toolsContainer) toolsContainer.classList.add('hidden');
    }
});
