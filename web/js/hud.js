const hintContainer = document.getElementById('hint-container');
const hintHeader = document.getElementById('hint-header');
const hintFooter = document.getElementById('hint-footer');
const hintIcon = document.getElementById('hint-icon');
const hintKey = document.getElementById('hint-key');
const hintLabel = document.getElementById('hint-label');
const hintExtra = document.getElementById('hint-extra');

const HINT_HIDE_MS = 150;

let hintHideTimer = null;

function showHint(data) {
    if (!hintContainer) return;

    const key = data && data.key;
    const extra = data && data.extra;
    const crop = data && data.crop;

    clearTimeout(hintHideTimer);
    hintContainer.classList.remove('hidden', 'leaving');

    if (hintHeader) {
        const header = data && data.header;

        hintHeader.textContent = header || '';
        hintHeader.classList.toggle('hidden', !header);
        hintContainer.classList.toggle('has-header', !!header);
    }

    if (hintFooter) {
        const items = data && data.footerItems;
        const footer = data && data.footer;

        if (Array.isArray(items) && items.length) {
            hintFooter.innerHTML = items.map(function (item, index) {
                const separator = index > 0 ? '<span class="hint-ctrl-sep"></span>' : '';

                return separator +
                    '<span class="hint-ctrl">' +
                    `<span class="hint-ctrl-key">${item.key}</span>` +
                    `<span class="hint-ctrl-label">${item.label}</span>` +
                    '</span>';
            }).join('');

            hintFooter.classList.remove('hidden');
        } else {
            hintFooter.textContent = footer || '';
            hintFooter.classList.toggle('hidden', !footer);
        }
    }

    if (hintIcon) {
        if (crop) {
            hintIcon.src = `images/${crop}.png`;
            hintIcon.classList.remove('hidden');
        } else {
            hintIcon.classList.add('hidden');
        }
    }

    if (crop && typeof CROP_COLORS !== 'undefined' && CROP_COLORS[crop]) {
        hintContainer.style.setProperty('--hint-accent', CROP_COLORS[crop]);
        hintContainer.classList.add('colored');
    } else {
        hintContainer.style.setProperty('--hint-accent', '#ffffff');
        hintContainer.classList.remove('colored');
    }

    if (hintKey) {
        hintKey.textContent = key || '';
        hintKey.style.display = key ? '' : 'none';
    }

    if (hintLabel) hintLabel.textContent = (data && data.label) || '';

    if (hintExtra) {
        hintExtra.textContent = extra || '';
        hintExtra.style.display = extra ? '' : 'none';
    }
}

function hideHint(instant) {
    if (!hintContainer) return;

    clearTimeout(hintHideTimer);

    if (instant) {
        hintContainer.classList.add('hidden');
        hintContainer.classList.remove('leaving');
        return;
    }

    if (hintContainer.classList.contains('hidden')) return;

    hintContainer.classList.add('leaving');

    hintHideTimer = setTimeout(function () {
        hintContainer.classList.add('hidden');
        hintContainer.classList.remove('leaving');
    }, HINT_HIDE_MS);
}

function copyToClipboard(text) {
    const area = document.createElement('textarea');

    area.value = text;
    area.style.position = 'fixed';
    area.style.top = '-1000px';
    area.style.opacity = '0';

    document.body.appendChild(area);
    area.focus();
    area.select();

    try {
        document.execCommand('copy');
    } catch (e) {
    }

    document.body.removeChild(area);
}

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'showHint') {
        showHint(data);
    } else if (data.action === 'hideHint') {
        hideHint(data.instant === true);
    } else if (data.action === 'copy') {
        copyToClipboard(data.text || '');
    }
});
