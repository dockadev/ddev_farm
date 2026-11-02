let currentPrices = {};

let currentProgress = null;

let playerStock = {};

let currentFocus = null;

let detailTimer = null;

function qualityLabel(quality) {
    const key = ['qualitySpoiled', 'qualityNormal', 'qualityPrime'][quality];
    return t(key);
}

const QUALITY_ICON_SUFFIX = ['_spoiled', '', '_prime'];

const SELL_DONE_MS = 450;

function btnInner(label) {
    return `<span class="btn-label">${label}</span>` +
        `<span class="btn-sold">${t('marketSold')}</span>`;
}

function qualityIcon(key, quality) {
    const suffix = QUALITY_ICON_SUFFIX[quality] !== undefined ? QUALITY_ICON_SUFFIX[quality] : '';
    return suffix ? `${key}${suffix}.png` : `${key}.png`;
}

function normalizeStock(entry) {
    if (typeof entry === 'number') {
        return { total: entry, broken: 0, normal: entry, good: 0 };
    }
    if (entry && typeof entry === 'object') {
        return {
            total: entry.total || 0,
            broken: entry.broken || 0,
            normal: entry.normal || 0,
            good: entry.good || 0,
        };
    }
    return { total: 0, broken: 0, normal: 0, good: 0 };
}

function priceTrend(index, change) {
    const cap = (text) => (text ? text.charAt(0).toUpperCase() + text.slice(1) : text);
    const pct = typeof change === 'number' ? change : null;

    if (pct !== null) {
        if (pct > 0.05) {
            return { icon: '▲', cls: 'trend-up', text: `${pct.toFixed(1)}% ${cap(t('priceRising'))}` };
        }

        if (pct < -0.05) {
            return { icon: '▼', cls: 'trend-down', text: `${Math.abs(pct).toFixed(1)}% ${cap(t('priceFalling'))}` };
        }

        return { icon: '—', cls: 'trend-flat', text: '' };
    }

    const value = typeof index === 'number' ? index : 1.0;

    if (value > 1.03) {
        const fallbackPct = Math.round((value - 1) * 100);
        return { icon: '▲', cls: 'trend-up', text: `${fallbackPct}% ${cap(t('priceRising'))}` };
    }

    if (value < 0.97) {
        const fallbackPct = Math.round((1 - value) * 100);
        return { icon: '▼', cls: 'trend-down', text: `${fallbackPct}% ${cap(t('priceFalling'))}` };
    }

    return { icon: '—', cls: 'trend-flat', text: '' };
}

function openMarket(prices, stock, progress, focus) {
    currentPrices = prices || {};
    playerStock = stock || {};
    currentFocus = focus || null;

    if (progress) currentProgress = progress;

    renderMarket();
    renderProgress();
    document.getElementById('market-container').classList.remove('hidden');
}

function renderProgress() {
    const el = document.getElementById('market-progress');
    if (!el) return;

    const p = currentProgress;

    if (!p || !p.enabled) {
        el.classList.add('hidden');
        el.innerHTML = '';
        return;
    }

    const bonusPct = (Math.round((p.bonus || 0) * 1000) / 10).toFixed(1);
    const isMax = !p.nextAt;

    let pct = 100;
    let nextText = t('marketMaxLevel');

    if (!isMax) {
        const span = Math.max(1, p.nextAt - (p.currentAt || 0));
        pct = Math.max(0, Math.min(100, ((p.units - (p.currentAt || 0)) / span) * 100));
        nextText = `${p.units} / ${p.nextAt}`;
    }

    el.innerHTML =
        '<span class="mp-level">Lv. ' + p.level + '</span>' +
        `<span class="mp-bonus">${t('marketBonusLabel')} +${bonusPct}%</span>` +
        `<div class="mp-bar"><i style="width:${pct}%"></i></div>` +
        `<span class="mp-next">${nextText}</span>`;

    el.classList.remove('hidden');
}

function closeMarket() {
    hideDetail();
    currentFocus = null;
    document.getElementById('market-container').classList.add('hidden');
    fetch('https://ddev_farm/closeMarket', { method: 'POST' });
}

function updatePrices(prices, stock, progress) {
    currentPrices = prices || currentPrices;
    if (stock) playerStock = stock;
    if (progress) currentProgress = progress;

    if (window.MarkerMenu && window.MarkerMenu.isSelling && window.MarkerMenu.isSelling()) {
        window.MarkerMenu.refresh(currentPrices, playerStock);
    }

    if (!document.getElementById('market-container').classList.contains('hidden')) {
        renderMarket();
        renderProgress();
    }
}

function hideDetail() {
    const detail = document.getElementById('market-detail');

    if (detail) {
        detail.classList.remove('visible');
        detail.innerHTML = '';
    }

    const panel = document.querySelector('.market-panel');
    if (panel) panel.style.borderColor = '';
}

function buildDetail(key, price, stock, detail) {
    if (!detail) return;

    const parts = [];
    if (stock.broken > 0) parts.push({ q: 0, n: stock.broken });
    if (stock.normal > 0) parts.push({ q: 1, n: stock.normal });
    if (stock.good > 0) parts.push({ q: 2, n: stock.good });

    const qtyHtml = parts.length
        ? `<div class="qty-list">${parts.map((p) => {
            const unit = price.qualityPrices ? price.qualityPrices[String(p.q)] : null;
            const unitText = unit !== null && unit !== undefined ? `$${unit}` : '';

            return `<div class="qty-row" data-quality="${p.q}" data-max="${p.n}">` +
                `<img src="images/${qualityIcon(key, p.q)}" alt="">` +
                `<span class="qty-name q${p.q}">${qualityLabel(p.q)}</span>` +
                `<span class="qty-have">${p.n}&times;</span>` +
                `<span class="qty-price">${unitText}</span>` +
                `<span class="qty-value">0</span>` +
                `</div>`;
        }).join('')}</div>`
        : '';

    detail.className = `mc-detail crop-${key}`;
    detail.innerHTML = `
        <div class="mc-meta">
            <span>${t('marketColumnStock')} <b>${stock.total}</b></span>
            <span>${t('marketColumnBase')} <b>$${price.basePrice}</b></span>
        </div>
        ${qtyHtml}
        <div class="mc-foot">
            <span class="mc-total">${t('marketTotal')} <b class="qty-total">$0</b></span>
            <div class="detail-actions">
                ${stock.total > 0
                    ? `<button class="sell-btn sell-all" data-units="${stock.total}">${btnInner(t('marketSellAll'))}</button>
                       <button class="sell-btn sell-picked" disabled>${btnInner(t('marketSellCount', 0))}</button>`
                    : `<span class="no-stock">${t('marketNoStock')}</span>`}
            </div>
        </div>
    `;

    const picked = { 0: 0, 1: 0, 2: 0 };
    const sellPickedBtn = detail.querySelector('.sell-picked');
    const totalEl = detail.querySelector('.qty-total');

    function pickedTotal() {
        return picked[0] + picked[1] + picked[2];
    }

    function pickedAmount() {
        let sum = 0;

        for (const q of [0, 1, 2]) {
            if (picked[q] < 1) continue;

            const unit = price.qualityPrices
                ? Number(price.qualityPrices[String(q)]) || 0
                : 0;

            sum += picked[q] * unit;
        }

        return sum;
    }

    function refreshPicked() {
        const total = pickedTotal();

        if (sellPickedBtn) {
            const labelEl = sellPickedBtn.querySelector('.btn-label');
            if (labelEl) labelEl.textContent = t('marketSellCount', total);
            sellPickedBtn.disabled = total < 1;
        }

        if (totalEl) {
            totalEl.textContent = `$${pickedAmount()}`;
        }
    }

    detail.querySelectorAll('.qty-row').forEach((row) => {
        const quality = parseInt(row.dataset.quality, 10);
        const max = parseInt(row.dataset.max, 10) || 0;
        const valueEl = row.querySelector('.qty-value');

        row.addEventListener('wheel', function (e) {
            e.preventDefault();

            const step = e.deltaY < 0 ? 1 : -1;
            picked[quality] = Math.max(0, Math.min(max, picked[quality] + step));

            if (valueEl) valueEl.textContent = picked[quality];
            refreshPicked();
        }, { passive: false });
    });

    const sellAllBtn = detail.querySelector('.sell-all');

    if (sellAllBtn) {
        sellAllBtn.addEventListener('click', function () {
            const items = [];

            if (stock.broken > 0) items.push({ quality: 0, units: stock.broken });
            if (stock.normal > 0) items.push({ quality: 1, units: stock.normal });
            if (stock.good > 0) items.push({ quality: 2, units: stock.good });

            if (items.length > 0) sellItems(key, items, sellAllBtn);
        });
    }

    if (sellPickedBtn) {
        sellPickedBtn.addEventListener('click', function () {
            const items = [];

            for (const q of [0, 1, 2]) {
                if (picked[q] > 0) items.push({ quality: q, units: picked[q] });
            }

            if (items.length > 0) sellItems(key, items, sellPickedBtn);
        });
    }

    refreshPicked();
}

function postSell(payload) {
    return fetch('https://ddev_farm/sell', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
    }).catch(() => ({}));
}

function animateSell(btn, request) {
    if (!btn) {
        request.then(renderMarket);
        return;
    }

    const started = performance.now();

    btn.disabled = true;
    btn.classList.add('done');

    request.then(() => {
        const wait = Math.max(0, SELL_DONE_MS - (performance.now() - started));

        setTimeout(() => {
            btn.classList.remove('done');
            btn.disabled = false;
            renderMarket();
        }, wait);
    });
}

function sellItems(crop, items, btn) {
    animateSell(btn, postSell({ crop: crop, items: items }));
}

function sell(crop, units, btn, quality) {
    const payload = { crop: crop, units: units };

    if (typeof quality === 'number') {
        payload.quality = quality;
    }

    animateSell(btn, postSell(payload));
}

function renderMarket() {
    const list = document.getElementById('market-rows');
    if (!list) return;

    hideDetail();
    list.innerHTML = '';

    const wrapper = document.createElement('div');
    wrapper.className = 'market-products-card';

    const order = currentFocus ? [currentFocus] : ['apple', 'tomato', 'corn', 'orange'];

    for (const key of order) {
        const price = currentPrices[key];
        if (!price) continue;

        const stock = normalizeStock(playerStock[key]);
        const trend = priceTrend(price.index, price.change);

        const priceClass = price.price > price.basePrice ? 'price-up'
            : price.price < price.basePrice ? 'price-down' : '';

        const changePct = Math.round((price.change || 0) * 10) / 10;
        const prevPrice = price.previousPrice !== undefined ? price.previousPrice : price.price;
        const changeCls = changePct > 0 ? 'up' : changePct < 0 ? 'down' : '';
        const changeText = (changePct > 0 ? '+' : '') + changePct.toFixed(1) + '%';

        const card = document.createElement('div');
        card.className = `market-product crop-${key}`;

        card.innerHTML = `
            <div class="mc-head">
                <img class="mc-icon" src="images/${price.icon || key + '.png'}" alt="">
                <div class="mc-title">
                    <span class="mc-name">${price.label}</span>
                    ${trend.text ? `<span class="mc-trend ${trend.cls}">${trend.icon} ${trend.text}</span>` : ''}
                </div>
                <div class="mc-price">
                    <span class="mc-now ${priceClass}">$${price.price}</span>
                    <span class="mc-prev ${changeCls}">$${prevPrice} · ${changeText}</span>
                </div>
            </div>
            <div class="mc-body"></div>
        `;

        buildDetail(key, price, stock, card.querySelector('.mc-body'));

        wrapper.appendChild(card);
    }

    list.appendChild(wrapper);
}

const marketDetailEl = document.getElementById('market-detail');

if (marketDetailEl) {
    marketDetailEl.addEventListener('mouseenter', function () {
        clearTimeout(detailTimer);
    });

    marketDetailEl.addEventListener('mouseleave', function () {
        detailTimer = setTimeout(hideDetail, 160);
    });
}

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'openMarket') {
        openMarket(data.prices, data.stock, data.progress, data.focus);
    } else if (data.action === 'sellCard') {
        const focus = data.focus;
        const price = (data.prices || {})[focus];
        const stock = normalizeStock((data.stock || {})[focus]);

        if (price && window.MarkerMenu) {
            window.MarkerMenu.openSell({
                crop: focus,
                title: price.label,
                price: price,
                stock: stock,
                color: typeof CROP_COLORS !== 'undefined' ? (CROP_COLORS[focus] || '') : '',
            });
        }
    } else if (data.action === 'updatePrices') {
        updatePrices(data.prices, data.stock, data.progress);
    } else if (data.action === 'closeMarket') {
        hideDetail();
        document.getElementById('market-container').classList.add('hidden');
    }
});
