const adminContainer = document.getElementById('admin-container');
const adminTabsEl = document.getElementById('admin-tabs');
const adminContentEl = document.getElementById('admin-content');
const adminHintEl = document.getElementById('admin-hint');
const adminSaveBtn = document.getElementById('admin-save');
const adminResetBtn = document.getElementById('admin-reset');
const adminCloseBtn = document.getElementById('admin-close');

const adminDiscordLink = document.getElementById('admin-discord-link');
const adminDiscordNote = document.getElementById('admin-discord-note');

let adminDiscordNoteTimer = null;

const ADMIN_GROUPS = ['market', 'harvest', 'minigame', 'world', 'progression', 'tools', 'setup', 'settings'];
const ADMIN_LANGS = ['en', 'tr', 'de', 'fr', 'it', 'es'];

const LANG_NAMES = {
    en: 'English',
    tr: 'Türkçe',
    de: 'Deutsch',
    fr: 'Français',
    it: 'Italiano',
    es: 'Español',
};

const PROGRESSION_KEY = /^progression\.(threshold|bonus)\.(\d+)$/;

const CROP_PRICE_KEY = /^crop\.(\w+)\.basePrice$/;

const SECTION_ORDER = ['general', 'threshold', 'bonus'];

const CROP_NAMES = {
    apple: 'Apple',
    tomato: 'Tomato',
    corn: 'Corn',
    orange: 'Orange',
};

let adminSettings = [];
let adminDirty = {};
let adminTab = 'market';
let adminLang = 'en';
let adminOpenTips = {};
let adminAdvancedOpen = {};
let adminResetArmed = false;
let adminResetTimer = null;
let adminStatusData = null;
let adminNodeStats = null;
let adminNodeRequestAt = 0;
let armedNodeCrop = null;
let armedNodeTimer = null;
let armedTool = null;

const EXT_FEATURES = ['buyers', 'crops', 'season', 'skills', 'automation', 'analytics'];

function renderExtendedTab() {
    if (!adminContentEl) return;

    const ext = text().extended || {};
    const features = ext.features || {};

    const blocks = EXT_FEATURES.map(function (key) {
        const f = features[key] || {};

        const body = [f.desc || '']
            .concat((f.items || []).map(function (line) { return '• ' + line; }))
            .join('\n');

        return '<div class="admin-setup-block">' +
            `<div class="admin-section">${f.title || key}</div>` +
            `<div class="admin-setup-text">${body}</div>` +
            '</div>';
    }).join('');

    adminContentEl.innerHTML =
        '<div class="admin-extended-tab">' +
        '<div class="admin-setup-block">' +
        `<div class="admin-section">Farm Extended · ${ext.soon || ''}</div>` +
        `<div class="admin-setup-text admin-ext-support-top">${ext.support || ''}</div>` +
        `<div class="admin-setup-text admin-ext-note">${ext.intro || ''}</div>` +
        '</div>' +
        blocks +
        '</div>';
}

function text() {
    return ADMIN_I18N[adminLang] || ADMIN_I18N.en;
}

function settingLabel(def) {
    const map = text().labels || {};

    if (map[def.key]) return map[def.key];

    const match = PROGRESSION_KEY.exec(def.key);

    if (match) {
        return `Lv. ${match[2]}`;
    }

    const cropMatch = CROP_PRICE_KEY.exec(def.key);

    if (cropMatch) {
        return fmtTemplate(text().cropPriceLabel, cropDisplayName(cropMatch[1]));
    }

    return def.label;
}

function cropDisplayName(key) {
    return CROP_NAMES[key] || key;
}

function settingTip(def) {
    const map = text().tips || {};

    if (map[def.key]) return map[def.key];

    const match = PROGRESSION_KEY.exec(def.key);

    if (match) {
        if (match[1] === 'threshold') {
            const units = Math.round(Number(currentValue(def)) || 0);

            return fmtTemplate(text().progressionThresholdTip, fmtNumber(units));
        }

        return fmtTemplate(text().progressionBonusTip, match[2]);
    }

    const cropMatch = CROP_PRICE_KEY.exec(def.key);

    if (cropMatch) {
        return fmtTemplate(text().cropPriceTip, cropDisplayName(cropMatch[1]));
    }

    return ADMIN_I18N.en.tips[def.key] || '';
}

function fmtTemplate(template, value) {
    return String(template).replace('{0}', value);
}

function divisorOf(def) {
    return def.divisor || 1;
}

function toDisplay(def, raw) {
    const d = divisorOf(def);

    return typeof raw === 'number' ? raw / d : raw;
}

function toRaw(def, display) {
    const d = divisorOf(def);
    const raw = Number(display) * d;

    if (!Number.isFinite(raw)) return null;

    let next = raw;

    if (def.min !== undefined && next < def.min) next = def.min;
    if (def.max !== undefined && next > def.max) next = def.max;

    return def.int ? Math.round(next) : next;
}

function fmtNumber(n) {
    if (!Number.isFinite(n)) return '0';

    return String(Math.round(n * 1000) / 1000);
}

function formatUnit(def, raw) {
    if (def.type !== 'number') return '';

    const value = toDisplay(def, raw);

    if (!def.unit) return fmtNumber(value);

    return def.unit === '%' ? `${fmtNumber(value)}%` : `${fmtNumber(value)} ${def.unit}`;
}

function findSetting(key) {
    return adminSettings.find(function (item) { return item.key === key; });
}

function currentValue(def) {
    return Object.prototype.hasOwnProperty.call(adminDirty, def.key)
        ? adminDirty[def.key]
        : def.value;
}

function renderTabs() {
    if (!adminTabsEl) return;

    adminTabsEl.innerHTML = ADMIN_GROUPS.map(function (group) {
        const active = group === adminTab ? ' active' : '';
        const label = text().tabs[group] || group;

        return `<button class="admin-tab${active}" data-tab="${group}">${label}</button>`;
    }).join('');

    const extActive = adminTab === 'extended' ? ' active' : '';
    adminTabsEl.innerHTML +=
        `<button class="admin-tab admin-tab-ext${extActive}" data-tab="extended">` +
        '<span class="ext-farm">Farm</span><span class="ext-white">Extended</span>' +
        '</button>';
}

function renderSettings() {
    if (!adminContentEl) return;

    const buttons = ADMIN_LANGS.map(function (lang) {
        const active = lang === adminLang ? ' active' : '';

        return `<button class="admin-lang-option${active}" data-lang="${lang}">` +
            `${(LANG_NAMES[lang] || lang).toUpperCase()}</button>`;
    }).join('');

    adminContentEl.innerHTML =
        '<div class="admin-settings">' +
        `<div class="admin-section">${text().language}</div>` +
        `<div class="admin-lang-grid">${buttons}</div>` +
        '</div>';
}

function renderDropdown(key, options, current) {
    const items = options.map(function (option) {
        const active = option.value === current ? ' active' : '';

        return `<button type="button" class="admin-dropdown-item${active}" ` +
            `data-value="${option.value}">${option.label}</button>`;
    }).join('');

    const selected = options.find(function (option) {
        return option.value === current;
    }) || options[0];

    return (
        `<div class="admin-dropdown" data-key="${key}" data-value="${current}">` +
        '<button type="button" class="admin-dropdown-btn">' +
        `<span class="admin-dropdown-value">${selected ? selected.label : ''}</span>` +
        '<i class="admin-dropdown-caret"></i>' +
        '</button>' +
        `<div class="admin-dropdown-menu hidden">${items}</div>` +
        '</div>'
    );
}

function closeAllDropdowns() {
    document.querySelectorAll('.admin-dropdown-menu').forEach(function (menu) {
        menu.classList.add('hidden');
    });
}

function renderSetup() {
    if (!adminContentEl) return;

    const s = text().setup || {};

    const blocks = [
        { title: s.nodesTitle, body: s.nodesBody },
        { title: s.marketTitle, body: s.marketBody },
        { title: s.restartTitle, body: s.restartBody },
    ].filter(function (block) {
        return block.title;
    });

    adminContentEl.innerHTML =
        '<div class="admin-page">' +
        '<div class="admin-block">' +
        `<div class="admin-section">${s.manageTitle || ''}</div>` +
        `<div class="admin-node-hint">${s.nodeHint || ''}</div>` +
        '<div id="admin-node-stats" class="admin-node-stats"></div>' +
        '<div class="admin-link-row">' +
        `<button class="admin-tool" data-action="applyNodes">${s.manageApply || ''}</button>` +
        `<button class="admin-tool" data-action="nodeStats">${s.manageRefresh || ''}</button>` +
        `<button class="admin-tool" data-action="clearNodes">${s.manageClear || ''}</button>` +
        '</div>' +
        '</div>' +
        '<div class="admin-block">' +
        `<div class="admin-section">${s.toolsTitle || ''}</div>` +
        `<div class="admin-setup-text">${s.toolsBody || ''}</div>` +
        '<div class="admin-link-row">' +
        `<button class="admin-tool" data-action="openTools">${s.toolsButton || ''}</button>` +
        '</div>' +
        '</div>' +
        '<div class="admin-block">' +
        `<div class="admin-section">${blocks[0] ? blocks[0].title : ''}</div>` +
        blocks.map(function (block) {
            return '<div class="admin-info-row">' +
                `<span class="admin-info-name">${block.title}</span>` +
                `<span class="admin-info-value">${block.body || ''}</span>` +
                '</div>';
        }).join('') +
        '</div>' +
        '</div>';

    renderNodeStats();

    if (!adminNodeStats) {
        requestNodeStats();
    }
}

function renderNodeStats() {
    const el = document.getElementById('admin-node-stats');
    if (!el) return;

    const stats = adminNodeStats;

    if (!stats) {
        el.textContent = '...';
        return;
    }

    const setupText = text().setup || {};

    el.innerHTML =
        `<div class="admin-node-row admin-node-head">` +
        `<span>${setupText.nodeCrop || 'Crop'}</span>` +
        `<span>${setupText.nodeSaved || 'Saved Props'}</span>` +
        `<span>${setupText.nodeActive || 'Active Plants'}</span>` +
        '<span></span>' +
        '</div>' +
        Object.keys(stats).map(function (crop) {
        const row = stats[crop] || {};

        return '<div class="admin-node-row">' +
            `<span class="admin-node-name">${row.label || crop}</span>` +
            `<span class="admin-node-num">${row.file || 0}</span>` +
            `<span class="admin-node-num dim">${row.active || 0}</span>` +
            `<button class="admin-node-clear" data-crop="${crop}" data-label="${setupText.manageRowClear || 'Clear'}">${setupText.manageRowClear || 'Clear'}</button>` +
            '</div>';
        }).join('');
}

function armNodeClear(element, crop) {
    disarmNodeClear();

    armedNodeCrop = crop;
    element.textContent = (text().setup || {}).manageConfirm || 'Sure?';
    element.classList.add('armed');

    armedNodeTimer = setTimeout(function () {
        element.textContent = element.dataset.label || 'Clear';
        element.classList.remove('armed');
        armedNodeCrop = null;
        armedNodeTimer = null;
    }, 3000);
}

function disarmNodeClear() {
    if (armedNodeTimer) {
        clearTimeout(armedNodeTimer);
        armedNodeTimer = null;
    }

    const el = document.querySelector('.admin-node-clear.armed');

    if (el) {
        el.textContent = el.dataset.label || 'Clear';
        el.classList.remove('armed');
    }

    armedNodeCrop = null;
}

function clearNodeCrop(crop) {
    fetch('https://ddev_farm/adminAction', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'clearNodes', data: { crop: crop } }),
    }).then(function () {
        setTimeout(function () { requestNodeStats(true); }, 500);
    }).catch(function () {});
}

function requestNodeStats(force) {
    const now = Date.now();

    if (!force && now - adminNodeRequestAt < 800) return;

    adminNodeRequestAt = now;

    fetch('https://ddev_farm/adminAction', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'nodeStats', data: null }),
    }).catch(function () {});
}

function renderRow(def) {
    const raw = currentValue(def);
    const dirty = Object.prototype.hasOwnProperty.call(adminDirty, def.key) ? ' dirty' : '';
    const badge = def.restart ? `<span class="admin-badge">${text().restart}</span>` : '';
    const caution = def.caution ? `<span class="admin-caution">${text().caution}</span>` : '';
    const globalBadge = def.global
        ? `<span class="admin-caution admin-global">${text().globalBadge || 'ALL PLAYERS'}</span>`
        : '';

    const defaultRaw = def.default !== undefined ? def.default : def.value;
    const defaultText = def.type === 'number' ? formatUnit(def, defaultRaw) : '';

    const tip = settingTip(def);
    const infoBtn = tip ? `<button class="admin-info" data-info="${def.key}">i</button>` : '';
    const tipLine = (tip && adminOpenTips[def.key])
        ? `<span class="admin-row-tip">${tip}</span>`
        : '';

    let control;

    if (def.type === 'bool') {
        control =
            `<button class="admin-toggle${raw ? ' on' : ''}" data-key="${def.key}" ` +
            `role="switch" aria-checked="${raw ? 'true' : 'false'}">` +
            `${raw ? 'ON' : 'OFF'}` +
            '</button>';
    } else if (def.type === 'enum') {
        const options = (def.options || []).map(function (option) {
            return { value: option, label: String(option).toUpperCase() };
        });

        control = renderDropdown(def.key, options, String(raw));
    } else {
        control =
            `<input class="admin-input" type="number" data-key="${def.key}" ` +
            `value="${fmtNumber(toDisplay(def, raw))}" ` +
            `min="${fmtNumber(toDisplay(def, def.min))}" ` +
            `max="${fmtNumber(toDisplay(def, def.max))}" ` +
            `step="${fmtNumber(toDisplay(def, def.step || 1))}">` +
            `<span class="admin-unit">${def.unit || ''}</span>`;
    }

    const meta = defaultText
        ? `${def.key} · ${text().defaultPrefix} ${defaultText}`
        : def.key;

    return (
        `<div class="admin-row${dirty}" data-key="${def.key}">` +
        '<div class="admin-row-info">' +
        `<span class="admin-row-label">${settingLabel(def)}${badge}${caution}${globalBadge}${infoBtn}</span>` +
        `<span class="admin-row-key">${meta}</span>` +
        tipLine +
        '</div>' +
        `<div class="admin-control">${control}</div>` +
        '</div>'
    );
}

function renderContent() {
    if (!adminContentEl) return;

    if (adminTab === 'tools') {
        renderTools();
        return;
    }

    if (adminTab === 'settings') {
        renderSettings();
        return;
    }

    if (adminTab === 'setup') {
        renderSetup();
        return;
    }

    if (adminTab === 'extended') {
        renderExtendedTab();
        return;
    }

    const rows = adminSettings.filter(function (def) {
        return def.group === adminTab && !def.advanced;
    });

    const advanced = adminSettings.filter(function (def) {
        return def.group === adminTab && def.advanced;
    });

    let html = renderSectioned(rows);

    if (advanced.length) {
        const openAttr = adminAdvancedOpen[adminTab] ? ' open' : '';

        html +=
            `<details class="admin-advanced"${openAttr}>` +
            `<summary>${fmtTemplate(text().advanced, advanced.length)}</summary>` +
            renderSectioned(advanced) +
            '</details>';
    }

    adminContentEl.innerHTML = html || `<div class="admin-empty">${text().empty}</div>`;
}

function renderSectioned(rows) {
    const buckets = [];
    const index = {};

    rows.forEach(function (def) {
        const key = def.section || '';

        if (index[key] === undefined) {
            index[key] = buckets.length;
            buckets.push({ key: key, defs: [] });
        }

        buckets[index[key]].defs.push(def);
    });

    buckets.sort(function (a, b) {
        const ai = SECTION_ORDER.indexOf(a.key);
        const bi = SECTION_ORDER.indexOf(b.key);

        return (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi);
    });

    return buckets.map(function (bucket) {
        const defs = bucket.key ? bucket.defs.slice().sort(byLevel) : bucket.defs;
        const header = bucket.key
            ? `<div class="admin-section">${sectionLabel(bucket.key)}</div>`
            : '';

        return header + defs.map(renderRow).join('');
    }).join('');
}

function byLevel(a, b) {
    const ma = PROGRESSION_KEY.exec(a.key);
    const mb = PROGRESSION_KEY.exec(b.key);

    return (ma ? Number(ma[2]) : 0) - (mb ? Number(mb[2]) : 0);
}

function sectionLabel(key) {
    if (key === 'threshold') return text().progressionRequired;
    if (key === 'bonus') return text().progressionBonus;
    if (key === 'general') return text().progressionGeneral;

    return key;
}

function renderTools() {
    const t = text().tools;
    const qualities = text().qualities;

    const cropOptions = Object.keys(CROP_NAMES).map(function (key) {
        return { value: key, label: CROP_NAMES[key] };
    });

    const qualityOptions = qualities.map(function (name, index) {
        return { value: String(index), label: name };
    });

    adminContentEl.innerHTML =
        '<div class="admin-page">' +
        '<div class="admin-block">' +
        `<div class="admin-section">${text().tabs.tools}</div>` +
        '<div class="admin-link-row">' +
        `<button class="admin-tool" data-action="resetPrices">${t.resetPrices}</button>` +
        `<button class="admin-tool" data-action="tickNow">${t.tickNow}</button>` +
        `<button class="admin-tool" data-action="readyAll">${t.readyAll}</button>` +
        `<button class="admin-tool" data-action="resync">${t.resync}</button>` +
        `<button class="admin-tool" data-action="status">${t.status}</button>` +
        '</div>' +
        '</div>' +
        '<div class="admin-block">' +
        `<div class="admin-section">${t.pruneLabel}</div>` +
        '<div class="admin-form-row">' +
        '<input id="admin-prune-days" class="admin-input" type="number" value="30" min="1" step="1">' +
        `<span class="admin-unit">${t.days}</span>` +
        `<button class="admin-tool" data-action="pruneLog">${t.prune}</button>` +
        '</div>' +
        '</div>' +
        '<div class="admin-block">' +
        `<div class="admin-section">${t.giveLabel}</div>` +
        '<div class="admin-form-grid">' +
        `<label class="admin-field"><span class="admin-field-label">${t.playerId}</span>` +
        '<input id="admin-give-target" class="admin-input" type="number" min="1"></label>' +
        `<label class="admin-field"><span class="admin-field-label">${t.giveLabel}</span>` +
        `${renderDropdown('giveCrop', cropOptions, 'apple')}</label>` +
        '<label class="admin-field"><span class="admin-field-label">#</span>' +
        '<input id="admin-give-count" class="admin-input" type="number" value="1" min="1"></label>' +
        `<label class="admin-field"><span class="admin-field-label">${qualities[1] || ''}</span>` +
        `${renderDropdown('giveQuality', qualityOptions, '1')}</label>` +
        '</div>' +
        '<div class="admin-link-row">' +
        `<button class="admin-tool" data-action="giveItem">${t.give}</button>` +
        '</div>' +
        '</div>' +
        '<div class="admin-block">' +
        `<div class="admin-section">${t.status}</div>` +
        '<div id="admin-status" class="admin-status"></div>' +
        '</div>' +
        '</div>';

    renderStatus();
}

function renderStatus() {
    const el = document.getElementById('admin-status');
    if (!el) return;

    if (!adminStatusData) {
        el.innerHTML = '';
        return;
    }

    const rows = Object.keys(adminStatusData).map(function (key) {
        const data = adminStatusData[key] || {};

        return (
            '<div class="admin-status-row">' +
            `<span class="admin-status-name">${data.label || key}</span>` +
            `<span>$${data.price || 0}</span>` +
            `<span class="admin-status-dim">base $${data.basePrice || 0}</span>` +
            `<span class="admin-status-dim">x${(data.index || 1).toFixed(2)}</span>` +
            `<span class="admin-status-dim">stock ${Math.round(data.marketStock || 0)}</span>` +
            '</div>'
        );
    });

    el.innerHTML = rows.join('');
}

function renderFooter() {
    const count = Object.keys(adminDirty).length;

    if (adminHintEl) {
        adminHintEl.textContent = count ? fmtTemplate(text().unsaved, count) : '';
    }

    if (adminSaveBtn) adminSaveBtn.textContent = text().save;
    if (adminCloseBtn) adminCloseBtn.textContent = text().close;
    if (adminResetBtn && !adminResetArmed) adminResetBtn.textContent = text().reset;
}

function renderTitle() {
    const rest = document.getElementById('admin-title-rest');

    if (rest) rest.textContent = text().titleRest;
}

function renderAll() {
    renderTitle();
    renderTabs();
    renderContent();
    renderFooter();
}

function sameValue(a, b) {
    if (typeof a === 'number' && typeof b === 'number') {
        return Math.abs(a - b) <= 1e-6 * Math.max(1, Math.abs(a), Math.abs(b));
    }

    return a === b;
}

function setDirty(key, displayValue) {
    const def = findSetting(key);
    if (!def) return;

    let value;

    if (def.type === 'bool') {
        value = displayValue === true;
    } else if (def.type === 'enum') {
        value = String(displayValue);
    } else {
        value = toRaw(def, displayValue);

        if (value === null) return;
    }

    const row = adminContentEl && adminContentEl.querySelector(`.admin-row[data-key="${key}"]`);

    if (sameValue(value, def.value)) {
        delete adminDirty[key];
        if (row) row.classList.remove('dirty');
    } else {
        adminDirty[key] = value;
        if (row) row.classList.add('dirty');
    }

    renderFooter();
}

function openAdminPanel(settings) {
    if (!adminContainer) return;

    adminSettings = settings || [];
    adminDirty = {};
    adminOpenTips = {};
    adminResetArmed = false;

    renderAll();
    adminContainer.classList.remove('hidden');
}

function updateAdminPanel(settings) {
    adminSettings = settings || [];
    adminDirty = {};

    renderAll();
}

function closeAdminPanel() {
    if (adminContainer) adminContainer.classList.add('hidden');

    adminDirty = {};

    fetch('https://ddev_farm/closeAdmin', { method: 'POST' });
}

if (adminTabsEl) {
    adminTabsEl.addEventListener('click', function (e) {
        const tab = e.target.closest('.admin-tab');
        if (!tab) return;

        if (!tab.dataset.tab) return;

        adminTab = tab.dataset.tab;
        disarmTool();
        renderAll();
    });
}

if (adminCloseBtn) {
    adminCloseBtn.addEventListener('click', closeAdminPanel);
}

function selectDiscordInvite() {
    const url = 'https://discord.gg/Gep3cg64q4';
    const area = document.createElement('textarea');

    area.value = url;
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.appendChild(area);
    area.select();

    let copied = false;

    try {
        copied = document.execCommand('copy');
    } catch (e) {
        copied = false;
    }

    area.remove();
    window.getSelection().removeAllRanges();

    if (adminDiscordNote && copied) {
        adminDiscordNote.textContent = text().copied || 'Copied';

        clearTimeout(adminDiscordNoteTimer);
        adminDiscordNoteTimer = setTimeout(function () {
            adminDiscordNote.textContent = '';
        }, 2000);
    }
}

if (adminDiscordLink) {
    adminDiscordLink.addEventListener('click', selectDiscordInvite);
}

document.addEventListener('click', function (e) {
    if (!e.target.closest('.admin-dropdown')) {
        closeAllDropdowns();
    }
});

if (adminContentEl) {
    adminContentEl.addEventListener('click', function (e) {
        const langBtn = e.target.closest('.admin-lang-option');

        if (langBtn) {
            if (langBtn.dataset.lang !== adminLang) {
                adminLang = langBtn.dataset.lang;
                renderAll();
            }

            return;
        }

        const summary = e.target.closest('.admin-advanced > summary');

        if (summary) {
            const details = summary.parentElement;

            setTimeout(function () {
                adminAdvancedOpen[adminTab] = details.open;
            }, 0);

            return;
        }

        const info = e.target.closest('.admin-info');
        if (info) {
            const key = info.dataset.info;

            adminOpenTips[key] = !adminOpenTips[key];
            renderAll();
            return;
        }

        const dropBtn = e.target.closest('.admin-dropdown-btn');

        if (dropBtn) {
            const menu = dropBtn.parentElement.querySelector('.admin-dropdown-menu');
            const wasHidden = menu.classList.contains('hidden');

            closeAllDropdowns();

            if (wasHidden) menu.classList.remove('hidden');

            return;
        }

        const dropItem = e.target.closest('.admin-dropdown-item');

        if (dropItem) {
            const dropdown = dropItem.closest('.admin-dropdown');
            const key = dropdown.dataset.key;
            const value = dropItem.dataset.value;

            dropdown.dataset.value = value;

            const valueEl = dropdown.querySelector('.admin-dropdown-value');
            if (valueEl) valueEl.textContent = dropItem.textContent;

            dropdown.querySelectorAll('.admin-dropdown-item').forEach(function (item) {
                item.classList.toggle('active', item === dropItem);
            });

            closeAllDropdowns();

            if (findSetting(key)) {
                setDirty(key, value);
            }

            return;
        }

        const toggle = e.target.closest('.admin-toggle');
        if (toggle) {
            const def = findSetting(toggle.dataset.key);
            if (!def) return;

            const next = !currentValue(def);
            const row = toggle.closest('.admin-row');

            if (next === def.value) {
                delete adminDirty[def.key];
                if (row) row.classList.remove('dirty');
            } else {
                adminDirty[def.key] = next;
                if (row) row.classList.add('dirty');
            }

            toggle.classList.toggle('on', next);
            toggle.textContent = next ? 'ON' : 'OFF';
            toggle.setAttribute('aria-checked', next ? 'true' : 'false');

            renderFooter();

            return;
        }

        const nodeClear = e.target.closest('.admin-node-clear');

        if (nodeClear) {
            const crop = nodeClear.dataset.crop;

            if (armedNodeCrop !== crop) {
                armNodeClear(nodeClear, crop);
                return;
            }

            disarmNodeClear();
            clearNodeCrop(crop);

            return;
        }

        const tool = e.target.closest('[data-action]');

        if (tool) {
            const action = tool.dataset.action;

            const needsConfirm = adminTab === 'tools' || action === 'clearNodes';

            if (needsConfirm && (!armedTool || armedTool.action !== action)) {
                armTool(tool, action);
                return;
            }

            disarmTool();
            runTool(action);
        }
    });

    adminContentEl.addEventListener('change', function (e) {
        const input = e.target.closest('.admin-input[data-key]');
        if (!input) return;

        setDirty(input.dataset.key, input.value);
    });
}

function armTool(element, action) {
    disarmTool();

    armedTool = {
        action: action,
        element: element,
        original: element.textContent,
        timer: setTimeout(disarmTool, 3000),
    };

    element.textContent = text().confirmTool;
    element.classList.add('armed');
}

function disarmTool() {
    if (!armedTool) return;

    clearTimeout(armedTool.timer);

    if (armedTool.element) {
        armedTool.element.textContent = armedTool.original;
        armedTool.element.classList.remove('armed');
    }

    armedTool = null;
}

function runTool(action) {
    let data = null;

    if (action === 'pruneLog') {
        const days = document.getElementById('admin-prune-days');
        data = { days: Number(days && days.value) || 30 };
    } else if (action === 'giveItem') {
        const target = document.getElementById('admin-give-target');
        const count = document.getElementById('admin-give-count');

        const cropEl = document.querySelector('.admin-dropdown[data-key="giveCrop"]');
        const qualityEl = document.querySelector('.admin-dropdown[data-key="giveQuality"]');

        data = {
            target: Number(target && target.value),
            crop: cropEl && cropEl.dataset.value,
            count: Number(count && count.value) || 1,
            quality: Number(qualityEl && qualityEl.dataset.value) || 1,
        };
    }

    fetch('https://ddev_farm/adminAction', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: action, data: data }),
    }).then(function () {
        if (action === 'applyNodes' || action === 'clearNodes') {
            setTimeout(function () { requestNodeStats(true); }, 500);
        }
    }).catch(function () {});
}

if (adminSaveBtn) {
    adminSaveBtn.addEventListener('click', function () {
        if (!Object.keys(adminDirty).length) return;

        fetch('https://ddev_farm/adminSave', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ values: adminDirty }),
        });
    });
}

if (adminResetBtn) {
    adminResetBtn.addEventListener('click', function () {
        if (!adminResetArmed) {
            adminResetArmed = true;
            adminResetBtn.textContent = text().confirmReset;

            clearTimeout(adminResetTimer);
            adminResetTimer = setTimeout(function () {
                adminResetArmed = false;
                adminResetBtn.textContent = text().reset;
            }, 3000);

            return;
        }

        adminResetArmed = false;
        adminResetBtn.textContent = text().reset;

        fetch('https://ddev_farm/adminReset', { method: 'POST' });
    });
}

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'adminOpen') {
        openAdminPanel(data.settings);
    } else if (data.action === 'adminUpdate') {
        updateAdminPanel(data.settings);
    } else if (data.action === 'adminStatus') {
        adminStatusData = data.status || null;
        renderStatus();
    } else if (data.action === 'nodeStats') {
        adminNodeStats = data.data || null;
        renderNodeStats();
    } else if (data.action === 'adminClose') {
        if (adminContainer) adminContainer.classList.add('hidden');
    }
});
