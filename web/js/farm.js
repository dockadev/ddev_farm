const farmContainer = document.getElementById('farm-container');

let farmData = null;
let farmPrefs = { levelUp: true, sounds: true };
let farmPrefsDirty = false;

function fmtNumber(value) {
    return String(Math.round(Number(value) || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

function renderFarmPrefs() {
    const levelBtn = document.getElementById('farm-pref-level');
    const soundsBtn = document.getElementById('farm-pref-sounds');
    const saveBtn = document.getElementById('farm-pref-save');

    if (levelBtn) {
        levelBtn.textContent = `${t('farmPrefLevel')}: ${farmPrefs.levelUp ? 'ON' : 'OFF'}`;
        levelBtn.classList.toggle('on', farmPrefs.levelUp);
    }

    if (soundsBtn) {
        soundsBtn.textContent = `${t('farmPrefSounds')}: ${farmPrefs.sounds ? 'ON' : 'OFF'}`;
        soundsBtn.classList.toggle('on', farmPrefs.sounds);
    }

    if (saveBtn) {
        saveBtn.textContent = t('farmSave');
        saveBtn.classList.toggle('dirty', farmPrefsDirty);
    }
}

function renderFarmSales() {
    const list = document.getElementById('farm-sales');
    if (!list) return;

    const groups = (farmData && farmData.sales) || [];

    if (!groups.length) {
        list.innerHTML = `<div class="farm-empty">${t('farmNoSales')}</div>`;
        return;
    }

    list.innerHTML = groups.map(function (group) {
        const rows = (group.entries || []).map(function (entry) {
            return (
                '<div class="farm-sale">' +
                `<span class="farm-sale-units">${entry.units}x</span>` +
                `<span class="farm-sale-total">$${fmtNumber(entry.total)}</span>` +
                `<span class="farm-sale-unit">$${fmtNumber(entry.unitPrice)}${t('farmUnitSuffix')}</span>` +
                '</div>'
            );
        }).join('');

        return (
            '<div class="farm-sale-group">' +
            '<div class="farm-sale-head">' +
            `<img src="images/${group.crop}.png" alt="">` +
            `<span class="farm-sale-name">${group.label}</span>` +
            '</div>' +
            rows +
            '</div>'
        );
    }).join('');
}

function renderFarmRoadmap(d) {
    const el = document.getElementById('farm-roadmap');
    if (!el) return;

    const levels = d.levels || [];
    const current = d.level || 1;

    if (!levels.length) {
        el.innerHTML = '';
        return;
    }

    el.innerHTML = levels.map(function (lvl) {
        const pct = (Math.round((lvl.bonus || 0) * 1000) / 10).toFixed(1);
        const state = lvl.level === current ? ' current' : (lvl.level < current ? ' done' : '');

        return '<div class="farm-roadmap-row' + state + '">' +
            `<span class="farm-roadmap-lv">Lv. ${lvl.level}</span>` +
            `<span class="farm-roadmap-at">${fmtNumber(lvl.at)} ${t('farmUnitSuffix')}</span>` +
            `<span class="farm-roadmap-bonus">+${pct}%</span>` +
            '</div>';
    }).join('');
}

function renderFarm() {
    if (!farmData) return;

    const d = farmData;
    const levelEl = document.getElementById('farm-level');
    const bonusEl = document.getElementById('farm-bonus');
    const barEl = document.getElementById('farm-bar-fill');
    const nextEl = document.getElementById('farm-next');

    if (levelEl) levelEl.textContent = `Lv. ${d.level || 1}`;

    if (bonusEl) {
        const pct = (Math.round((d.bonus || 0) * 1000) / 10).toFixed(1);
        bonusEl.textContent = `${t('marketBonusLabel')} +${pct}%`;
    }

    const isMax = !d.nextAt;
    let pct = 100;
    let nextText = t('marketMaxLevel');

    if (!isMax) {
        const span = Math.max(1, d.nextAt - (d.currentAt || 0));
        pct = Math.max(0, Math.min(100, ((d.units - (d.currentAt || 0)) / span) * 100));
        nextText = `${fmtNumber(d.units)} / ${fmtNumber(d.nextAt)}`;
    }

    if (barEl) barEl.style.width = `${pct}%`;

    if (nextEl) {
        if (isMax) {
            nextEl.textContent = nextText;
        } else {
            const remaining = Math.max(0, d.nextAt - d.units);
            nextEl.textContent = `${nextText} · ${t('farmToNext', fmtNumber(remaining))}`;
        }
    }

    renderFarmRoadmap(d);

    const totals = d.totals || {};

    const harvestedEl = document.getElementById('farm-stat-harvested');
    const soldEl = document.getElementById('farm-stat-sold');
    const earnedEl = document.getElementById('farm-stat-earned');

    if (harvestedEl) harvestedEl.textContent = fmtNumber(d.units);
    if (soldEl) soldEl.textContent = fmtNumber(totals.units);
    if (earnedEl) earnedEl.textContent = `$${fmtNumber(totals.earned)}`;

    renderFarmSales();
    renderFarmPrefs();
}

function openFarmPanel(data) {
    if (!farmContainer || !data) return;

    farmData = data;
    farmPrefs = {
        levelUp: !(data.prefs && data.prefs.levelUp === false),
        sounds: !(data.prefs && data.prefs.sounds === false),
    };
    farmPrefsDirty = false;

    renderFarm();
    farmContainer.classList.remove('hidden');
}

function closeFarmPanel() {
    if (!farmContainer) return;

    farmContainer.classList.add('hidden');

    fetch('https://ddev_farm/closeFarm', { method: 'POST' });
}

document.querySelectorAll('.farm-pref[data-pref]').forEach(function (btn) {
    btn.addEventListener('click', function () {
        const key = btn.dataset.pref;
        if (!key) return;

        farmPrefs[key] = !farmPrefs[key];
        farmPrefsDirty = true;
        renderFarmPrefs();
    });
});

const farmSaveBtn = document.getElementById('farm-pref-save');

if (farmSaveBtn) {
    farmSaveBtn.addEventListener('click', function () {
        farmPrefsDirty = false;
        renderFarmPrefs();

        fetch('https://ddev_farm/saveFarmPrefs', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ prefs: farmPrefs }),
        }).catch(function () {});
    });
}

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'farmOpen') {
        openFarmPanel(data.data);
    } else if (data.action === 'farmClose') {
        if (farmContainer) farmContainer.classList.add('hidden');
    }
});
