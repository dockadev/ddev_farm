(function () {
    const layer = document.getElementById('marker-layer');
    if (!layer) return;

    const elements = new Map();
    let menuEl = null;
    let menuAnchor = { x: 0, y: 0 };

    function createMarker(id) {
        const el = document.createElement('div');
        el.className = 'marker';
        el.dataset.id = id;
        el.innerHTML =
            '<span class="marker-card">' +
            '<span class="marker-diamond"><span class="marker-key">E</span></span>' +
            '<span class="marker-label"></span>' +
            '</span>';

        layer.appendChild(el);
        elements.set(id, el);

        return el;
    }

    function renderMarkers(list) {
        const seen = new Set();
        const width = window.innerWidth;
        const height = window.innerHeight;

        (list || []).forEach(function (item) {
            seen.add(item.id);

            const el = elements.get(item.id) || createMarker(item.id);
            const near = item.state === 'key';

            el.style.transform =
                `translate3d(${item.x * width}px, ${item.y * height}px, 0) ` +
                'translate(-50%, -50%)';
            el.classList.toggle('near', near);

            if (item.crop && typeof CROP_COLORS !== 'undefined' && CROP_COLORS[item.crop]) {
                el.style.setProperty('--marker-accent', CROP_COLORS[item.crop]);
            } else {
                el.style.removeProperty('--marker-accent');
            }

            const keyEl = el.querySelector('.marker-key');
            if (keyEl) keyEl.textContent = item.key || 'E';

            const labelEl = el.querySelector('.marker-label');
            if (labelEl) labelEl.textContent = item.label || '';
        });

        elements.forEach(function (el, id) {
            if (!seen.has(id)) {
                el.remove();
                elements.delete(id);
            }
        });
    }

    function closeMenu() {
        elements.forEach(function (el) { el.classList.remove('menu-active'); });

        clearTimeout(sideHideTimer);
        hideSide();

        if (!menuEl) return;

        menuEl.remove();
        menuEl = null;
    }

    function positionMenu() {
        if (!menuEl) return;

        const width = menuEl.offsetWidth || 288;
        const height = menuEl.offsetHeight || 200;
        const left = Math.min(
            Math.max(menuAnchor.x + 46, 12),
            window.innerWidth - width - 12
        );
        const top = Math.min(
            Math.max(menuAnchor.y - height / 2, 12),
            window.innerHeight - height - 12
        );

        menuEl.style.left = `${left}px`;
        menuEl.style.top = `${top}px`;
    }

    let previewData = null;
    let sideEl = null;
    let sideHideTimer = null;
    let lastHoverOption = null;

    function hideSide() {
        if (!sideEl) return;

        const el = sideEl;
        sideEl = null;

        el.classList.add('closing');
        setTimeout(function () { el.remove(); }, 160);
    }

    function scheduleHideSide() {
        lastHoverOption = null;

        clearTimeout(sideHideTimer);
        sideHideTimer = setTimeout(hideSide, 180);
    }

    function positionSide() {
        if (!menuEl || !sideEl) return;

        const rect = menuEl.getBoundingClientRect();
        const width = sideEl.offsetWidth || 288;
        const height = sideEl.offsetHeight || 260;
        const left = Math.min(rect.right + 8, window.innerWidth - width - 12);
        const top = Math.min(Math.max(rect.top, 12), window.innerHeight - height - 12);

        sideEl.style.left = `${left}px`;
        sideEl.style.top = `${top}px`;
    }

    function showSide(option) {
        if (!previewData || !option || !option.crop) return;

        const crop = option.crop;
        const price = (previewData.prices || {})[crop];
        const rawStock = (previewData.stock || {})[crop];

        if (!price) return;

        const stock = typeof normalizeStock === 'function' ? normalizeStock(rawStock) : rawStock;
        if (!stock) return;

        if (!sideEl) {
            sideEl = document.createElement('div');
            sideEl.className = 'marker-menu marker-side';
            layer.appendChild(sideEl);

            sideEl.addEventListener('mouseenter', function () {
                clearTimeout(sideHideTimer);
            });

            sideEl.addEventListener('mouseleave', scheduleHideSide);
        }

        buildSellCard({
            crop: crop,
            title: price.label,
            color: typeof CROP_COLORS !== 'undefined' ? (CROP_COLORS[crop] || '#ff9f1c') : '#ff9f1c',
            price: price,
            stock: stock,
        }, sideEl);

        positionSide();
    }

    function renderMenuProgress() {
        if (!menuEl) return;

        const progress = previewData && previewData.progress;
        let block = menuEl.querySelector('.marker-menu-level');

        if (!progress || !progress.enabled) {
            if (block) block.remove();
            return;
        }

        if (!block) {
            block = document.createElement('div');
            block.className = 'marker-menu-level';

            const anchor = menuEl.querySelector('.marker-menu-head')
                || menuEl.querySelector('.marker-menu-title');

            if (anchor && anchor.nextSibling) {
                menuEl.insertBefore(block, anchor.nextSibling);
            } else {
                menuEl.appendChild(block);
            }
        }

        const bonusPct = (Math.round((progress.bonus || 0) * 1000) / 10).toFixed(1);
        const isMax = !progress.nextAt;

        let pct = 100;
        let nextText = t('marketMaxLevel');

        if (!isMax) {
            const span = Math.max(1, progress.nextAt - (progress.currentAt || 0));
            pct = Math.max(0, Math.min(100, ((progress.units - (progress.currentAt || 0)) / span) * 100));
            nextText = `${progress.units} / ${progress.nextAt}`;
        }

        block.innerHTML =
            `<div class="mml-row"><span class="mml-level">Lv. ${progress.level}</span>` +
            `<span class="mml-bonus">${t('marketBonusLabel')} +${bonusPct}%</span></div>` +
            `<div class="mml-bar"><i style="width:${pct}%"></i></div>` +
            `<div class="mml-next">${nextText}</div>`;
    }

    function openMenu(data) {
        closeMenu();

        menuAnchor = {
            x: data.x * window.innerWidth,
            y: data.y * window.innerHeight,
        };

        menuEl = document.createElement('div');
        menuEl.className = 'marker-menu';

        const title = data.title
            ? `<div class="marker-menu-title">${data.title}</div>`
            : '';

        const options = (data.options || []).map(function (option) {
            const crop = option.crop;
            const color = crop && typeof CROP_COLORS !== 'undefined' ? (CROP_COLORS[crop] || '') : '';
            const icon = crop ? `<img src="images/${crop}.png" alt="">` : '';

            return `<button class="marker-option" data-option="${option.key}" ` +
                `style="--opt-accent:${color};--opt-soft:${hexToRgba(color || '#ff9f1c', 0.18)}">` +
                `${icon}<span>${option.label}</span></button>`;
        }).join('');

        menuEl.innerHTML = title + options;

        renderMenuProgress();

        const optionMap = {};

        (data.options || []).forEach(function (option) {
            optionMap[option.key] = option;
        });

        menuEl.querySelectorAll('.marker-option').forEach(function (el) {
            el.__data = optionMap[el.dataset.option];
        });

        menuEl.addEventListener('mouseover', function (event) {
            const button = event.target.closest('.marker-option');
            if (!button) return;

            clearTimeout(sideHideTimer);

            const option = optionMap[button.dataset.option];
            if (option) {
                lastHoverOption = option;
                showSide(option);
            }
        });

        menuEl.addEventListener('mouseleave', scheduleHideSide);

        layer.appendChild(menuEl);
        elements.forEach(function (el) { el.classList.add('menu-active'); });

        requestAnimationFrame(positionMenu);
    }

    function hexToRgba(hex, alpha) {
        const value = (hex || '').replace('#', '');

        if (value.length !== 6) return `rgba(255, 159, 28, ${alpha})`;

        const r = parseInt(value.slice(0, 2), 16);
        const g = parseInt(value.slice(2, 4), 16);
        const b = parseInt(value.slice(4, 6), 16);

        return `rgba(${r}, ${g}, ${b}, ${alpha})`;
    }

    function shadeColor(hex, percent) {
        const value = (hex || '').replace('#', '');

        if (value.length !== 6) return '#a35f00';

        const number = parseInt(value, 16);
        const clamp = (channel) => Math.max(0, Math.min(255, Math.round(channel * (1 + percent))));
        const r = clamp((number >> 16) & 0xff);
        const g = clamp((number >> 8) & 0xff);
        const b = clamp(number & 0xff);

        return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
    }

    let sellState = null;
    let sellStateCard = null;

    function buildSellCard(data, card) {
        if (!card) return;

        sellState = data;
        sellStateCard = card;

        const stock = data.stock || { total: 0, broken: 0, normal: 0, good: 0 };
        const picked = { 0: 0, 1: 0, 2: 0 };
        const color = data.color || '#ff9f1c';

        card.classList.remove('loading');
        card.classList.add('sell');
        card.style.setProperty('--menu-accent', color);
        card.style.setProperty('--menu-accent-dark', shadeColor(color, -0.35));
        card.innerHTML = '';

        const header = document.createElement('div');
        header.className = 'marker-menu-head';
        header.innerHTML = `<span class="marker-menu-title">${data.title || ''}</span>`;

        const head = document.createElement('div');
        head.className = 'sell-head';

        const prev = data.price.previousPrice !== undefined
            ? data.price.previousPrice
            : data.price.price;
        const change = Math.round((data.price.change || 0) * 10) / 10;

        const priceClass = data.price.price > data.price.basePrice ? ' up'
            : data.price.price < data.price.basePrice ? ' down' : '';

        const deltaIcon = change > 0.05 ? '▲' : change < -0.05 ? '▼' : '—';
        const deltaCls = change > 0.05 ? 'up' : change < -0.05 ? 'down' : 'flat';

        head.innerHTML =
            `<span class="sell-price${priceClass}">$${data.price.price}</span>` +
            `<span class="sell-delta ${deltaCls}">${deltaIcon} ${Math.abs(change).toFixed(1)}%</span>` +
            `<span class="sell-prev">${t('marketPrevious')} $${prev}</span>`;

        const list = document.createElement('div');
        list.className = 'sell-list';
        list.style.setProperty('--sep-color', hexToRgba(color, 0.38));

        [0, 1, 2].forEach(function (q) {
            const max = q === 0 ? stock.broken : q === 1 ? stock.normal : stock.good;
            if (!max) return;

            const unit = data.price.qualityPrices ? data.price.qualityPrices[String(q)] : null;
            const suffix = ['_spoiled', '', '_prime'][q];

            const row = document.createElement('div');
            row.className = 'sell-row';
            row.innerHTML =
                `<img src="images/${data.crop}${suffix}.png" alt="">` +
                `<span class="sell-qname q${q}">${typeof qualityLabel === 'function' ? qualityLabel(q) : q}</span>` +
                `<span class="sell-have">${max}×</span>` +
                `<span class="sell-unit">${unit !== null && unit !== undefined ? '$' + unit : ''}</span>` +
                `<span class="sell-picked">0</span>`;

            const valueEl = row.querySelector('.sell-picked');

            row.addEventListener('wheel', function (event) {
                event.preventDefault();

                const step = event.deltaY < 0 ? 1 : -1;
                picked[q] = Math.max(0, Math.min(max, picked[q] + step));
                valueEl.textContent = picked[q];
                refreshFoot();
            }, { passive: false });

            list.appendChild(row);
        });

        const foot = document.createElement('div');
        foot.className = 'sell-foot';
        foot.innerHTML =
            `<span class="sell-total">${t('marketTotal')} <b>$0</b></span>` +
            '<div class="sell-actions">' +
            `<button class="sell-btn sell-all">${t('marketSellAll')}</button>` +
            `<button class="sell-btn sell-x" disabled>${t('marketSellCount', 0)}</button>` +
            '</div>';

        card.appendChild(header);
        card.appendChild(head);
        card.appendChild(list);
        card.appendChild(foot);

        function pickedTotal() {
            return picked[0] + picked[1] + picked[2];
        }

        function pickedAmount() {
            let sum = 0;

            [0, 1, 2].forEach(function (q) {
                if (picked[q] < 1) return;

                const unit = data.price.qualityPrices
                    ? Number(data.price.qualityPrices[String(q)]) || 0
                    : 0;

                sum += picked[q] * unit;
            });

            return sum;
        }

        function refreshFoot() {
            const total = pickedTotal();
            const btn = foot.querySelector('.sell-x');
            const totalEl = foot.querySelector('.sell-total b');

            btn.disabled = total < 1;
            btn.textContent = t('marketSellCount', total);

            if (totalEl) totalEl.textContent = `$${pickedAmount()}`;
        }

        function submit(items) {
            if (!items.length) return;

            fetch('https://ddev_farm/sell', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ crop: data.crop, items: items }),
            }).catch(function () {});
        }

        foot.querySelector('.sell-all').addEventListener('click', function () {
            const items = [];

            if (stock.broken > 0) items.push({ quality: 0, units: stock.broken });
            if (stock.normal > 0) items.push({ quality: 1, units: stock.normal });
            if (stock.good > 0) items.push({ quality: 2, units: stock.good });

            submit(items);
        });

        foot.querySelector('.sell-x').addEventListener('click', function () {
            const items = [];

            [0, 1, 2].forEach(function (q) {
                if (picked[q] > 0) items.push({ quality: q, units: picked[q] });
            });

            submit(items);
        });

        refreshFoot();
    }

    window.MarkerMenu = {
        isSelling: function () {
            return !!(sideEl || (menuEl && menuEl.classList.contains('sell')));
        },
        openSell: function (data) {
            if (!menuEl) return;

            buildSellCard(data, menuEl);
        },
        refresh: function (prices, stocks) {
            if (!sellState) return;

            const crop = sellState.crop;
            const price = (prices || {})[crop];

            if (!price) return;

            const stock = typeof normalizeStock === 'function'
                ? normalizeStock((stocks || {})[crop])
                : sellState.stock;

            buildSellCard({
                crop: crop,
                title: sellState.title,
                color: sellState.color,
                price: price,
                stock: stock,
            }, sellStateCard || menuEl);
        },
    };

    window.addEventListener('message', function (event) {
        const data = event.data || {};

        if (data.action === 'marker') {
            renderMarkers([{
                id: 'active',
                x: data.x,
                y: data.y,
                state: data.state,
                key: data.key,
                label: data.label,
            }]);
        } else if (data.action === 'markers') {
            renderMarkers(data.list);
        } else if (data.action === 'markerActivate') {
            const el = elements.get('active') || elements.get(data.id);

            if (el) {
                el.classList.add('activating');
                setTimeout(function () { el.classList.remove('activating'); }, 240);
            }
        } else if (data.action === 'marketPreview') {
            previewData = {
                prices: data.prices,
                stock: data.stock,
                progress: data.progress,
            };

            if (sideEl && window.MarkerMenu && window.MarkerMenu.isSelling()) {
                window.MarkerMenu.refresh(previewData.prices, previewData.stock);
            } else if (menuEl && lastHoverOption) {
                showSide(lastHoverOption);
            }

            renderMenuProgress();
        } else if (data.action === 'markerMenuLoading') {
            if (menuEl) menuEl.classList.add('loading');
        } else if (data.action === 'markerMenu') {
            openMenu(data);
        } else if (data.action === 'markerMenuClose') {
            closeMenu();
        }
    });

    window.addEventListener('keydown', function (event) {
        if (event.key !== 'Escape' || !menuEl) return;

        closeMenu();

        fetch('https://ddev_farm/markerClose', { method: 'POST' }).catch(function () {});
    });
})();
