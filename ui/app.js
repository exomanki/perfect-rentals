/* ================================================================
   Perfect Rentals — UI v2
   ================================================================ */

const IMG_SOURCES = [
    'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/',
    'https://raw.githubusercontent.com/MericcaN41/gta5carimages/main/images/',
];

const ICONS = {
    success: 'fa-solid fa-circle-check',
    error:   'fa-solid fa-circle-xmark',
    warning: 'fa-solid fa-triangle-exclamation',
    info:    'fa-solid fa-circle-info',
};

const TAG_COLORS = {
    eco: 'eco', sport: 'sport', luxe: 'luxe', supercar: 'supercar',
    prestige: 'luxe', hypercar: 'supercar', performance: 'sport',
    jdm: 'sport', offroad: 'sport',
};

/* ---- State ---- */
let vehicles = [];
let currentVehicle = null;
let currentLocationId = null;
let rentalConfig = { duration: null, insurance: 'none', fuelPolicy: 'full_to_full', payment: 'bank', delivery: false };
let currentPrice = null;
let activeContract = null;
let scanResult = null;

let __PR_BOOT = null;
function boot() { return __PR_BOOT || {}; }
function __(k) {
    const v = boot().locale && boot().locale[k];
    return (v != null && v !== '') ? v : k;
}

function applyPlayerI18n() {
    const loc = boot().locale;
    if (!loc) return;
    document.querySelectorAll('[data-i18n]').forEach(el => {
        const kk = el.getAttribute('data-i18n');
        if (loc[kk] != null) el.textContent = loc[kk];
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
        const kk = el.getAttribute('data-i18n-placeholder');
        if (loc[kk] != null) el.placeholder = loc[kk];
    });
    document.querySelectorAll('#sort-select option[data-i18n]').forEach(o => {
        const kk = o.getAttribute('data-i18n');
        if (loc[kk] != null) o.textContent = loc[kk];
    });
}

function insLabel(key) {
    const i = (boot().insurance || []).find(x => x.key === key);
    return i ? i.label : key;
}
function fuelLabel(key) {
    const i = (boot().fuel || []).find(x => x.key === key);
    return i ? i.label : key;
}

/* ================================================================
   NUI Communication
   ================================================================ */
function nui(event, data = {}) {
    return fetch(`https://perfect_rentals/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => null);
}

/* ================================================================
   Toast
   ================================================================ */
function toast(msg, type = 'info', duration = 3500) {
    const c = document.getElementById('toast-container');
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.innerHTML = `<i class="${ICONS[type] || ICONS.info}"></i><span>${msg}</span>`;
    c.appendChild(el);
    setTimeout(() => {
        el.classList.add('leaving');
        setTimeout(() => el.remove(), 260);
    }, duration);
}

/* ================================================================
   Image helpers — multi-source fallback
   ================================================================ */
const imgCache = {};

function vehImgSrc(model, customUrl) {
    if (customUrl && customUrl.length > 4) return customUrl;
    if (imgCache[model]) return imgCache[model];
    return IMG_SOURCES[0] + model.toLowerCase() + '.png';
}

function imgFallback(el) {
    const model = el.dataset.model;
    const tried = parseInt(el.dataset.tried || '0');
    const next = tried + 1;

    if (model && next < IMG_SOURCES.length) {
        el.dataset.tried = next;
        el.src = IMG_SOURCES[next] + model.toLowerCase() + '.png';
        return;
    }

    el.onerror = null;
    el.style.display = 'none';
    const p = el.parentElement;
    if (p && !p.querySelector('.v-fallback')) {
        const label = el.alt || model || '';
        const fb = document.createElement('div');
        fb.className = 'v-fallback';
        fb.innerHTML = `<i class="fa-solid fa-car-side"></i>${label ? `<span>${label}</span>` : ''}`;
        p.appendChild(fb);
    }
}

function imgLoaded(el) {
    const model = el.dataset.model;
    if (model && el.src) imgCache[model] = el.src;
}

/* ================================================================
   Formatting
   ================================================================ */
function money(n) {
    const tag = boot().localeTag || 'fr-FR';
    return '$' + (n || 0).toLocaleString(tag);
}

function msToTime(ms) {
    if (ms <= 0) return __('expired');
    let totalSec = Math.floor(ms / 1000);
    const days = Math.floor(totalSec / 86400);
    totalSec %= 86400;
    const h = Math.floor(totalSec / 3600);
    const m = Math.floor((totalSec % 3600) / 60);
    const s = totalSec % 60;
    const dL = __('days_short');
    const hL = __('hours_short');
    const mL = __('minutes_short');
    const sU = __('timer_seconds_unit');
    if (days >= 1)
        return `${days} ${dL} · ${h} ${hL} ${String(m).padStart(2, '0')} ${mL}`;
    if (h >= 1)
        return `${h} ${hL} ${String(m).padStart(2, '0')} ${mL} ${String(s).padStart(2, '0')} ${sU}`;
    if (m >= 1)
        return `${m} ${mL} ${String(s).padStart(2, '0')} ${sU}`;
    return `${s} ${sU}`;
}

function dateStr(ts) {
    if (!ts) return '—';
    const tag = boot().localeTag || 'fr-FR';
    const d = new Date(ts);
    return d.toLocaleDateString(tag) + ' ' + d.toLocaleTimeString(tag, { hour: '2-digit', minute: '2-digit' });
}

function durationLabel(min) {
    if (min < 60) return min + ' ' + __('minutes_short');
    if (min < 1440) return (min / 60) + __('hours_short');
    return (min / 1440) + __('days_short');
}

function tagClass(tag) {
    return TAG_COLORS[tag.toLowerCase()] || '';
}

/* ================================================================
   Contract Paper — document shown as a paper sheet
   ================================================================ */
let _contractAutoClose = null;

function showContractPaper(d) {
    if (_contractAutoClose) { clearTimeout(_contractAutoClose); _contractAutoClose = null; }

    let overlay = document.getElementById('contract-overlay');
    if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'contract-overlay';
        document.body.appendChild(overlay);
    }

    const isMine = d.mine;
    const subtitle = isMine ? __('cp_sub_mine') : __('cp_sub_other').replace('%s', d.ownerName || '?');
    const insTxt = insLabel(d.insurance) || d.insurance || '—';

    overlay.innerHTML = `
        <div class="cp-backdrop"></div>
        <div class="cp-paper${isMine ? ' cp-mine' : ' cp-other'}">
            <div class="cp-watermark">PERFECT RENTALS</div>
            <div class="cp-top">
                <div class="cp-logo-area">
                    <div class="cp-logo-icon"><i class="fa-solid fa-car-side"></i></div>
                    <div>
                        <div class="cp-company">${__('cp_company')}</div>
                        <div class="cp-tagline">${__('cp_service')}</div>
                    </div>
                </div>
                <div class="cp-num">#${d.contractNum || '—'}</div>
            </div>
            <div class="cp-divider"></div>
            <div class="cp-title">${__('cp_title')}</div>
            <div class="cp-subtitle">${subtitle}</div>
            <div class="cp-fields">
                <div class="cp-field">
                    <div class="cp-field-label">${__('cp_licensee')}</div>
                    <div class="cp-field-value">${d.ownerName || '—'}</div>
                </div>
                <div class="cp-field">
                    <div class="cp-field-label">${__('cp_vehicle')}</div>
                    <div class="cp-field-value">${d.vehicle || '—'}</div>
                </div>
                <div class="cp-field">
                    <div class="cp-field-label">${__('cp_plate')}</div>
                    <div class="cp-field-value cp-field-plate">${d.plate || '—'}</div>
                </div>
                <div class="cp-field">
                    <div class="cp-field-label">${__('cp_valid_until')}</div>
                    <div class="cp-field-value">${d.endDate || '—'}</div>
                </div>
                <div class="cp-field">
                    <div class="cp-field-label">${__('cp_insurance')}</div>
                    <div class="cp-field-value">${insTxt}</div>
                </div>
            </div>
            <div class="cp-divider"></div>
            <div class="cp-legal">${__('cp_legal')}</div>
            <div class="cp-stamp">
                <i class="fa-solid fa-circle-check"></i>
                <span>${__('cp_stamp')}</span>
            </div>
            ${isMine ? `<button class="cp-close" onclick="closeContractPaper()"><i class="fa-solid fa-xmark"></i> ${__('cp_close')}</button>` : ''}
        </div>
    `;

    overlay.classList.add('cp-show');
    setTimeout(() => overlay.classList.add('cp-visible'), 10);

    if (!isMine) {
        _contractAutoClose = setTimeout(() => closeContractPaperAuto(), 10000);
    }
}

function closeContractPaper() {
    if (_contractAutoClose) { clearTimeout(_contractAutoClose); _contractAutoClose = null; }
    const ov = document.getElementById('contract-overlay');
    if (!ov) return;
    ov.classList.remove('cp-visible');
    setTimeout(() => ov.classList.remove('cp-show'), 400);
    nui('closeContract');
}

function closeContractPaperAuto() {
    _contractAutoClose = null;
    const ov = document.getElementById('contract-overlay');
    if (!ov) return;
    ov.classList.remove('cp-visible');
    setTimeout(() => ov.classList.remove('cp-show'), 400);
}

/* ================================================================
   Theme — applies Config.Theme colors from Lua to CSS variables
   ================================================================ */
function applyTheme(t) {
    if (!t || typeof t !== 'object') return;
    const r = document.documentElement.style;
    const hex2rgb = (h) => {
        h = h.replace('#', '');
        if (h.length === 3) h = h[0]+h[0]+h[1]+h[1]+h[2]+h[2];
        const n = parseInt(h, 16);
        return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    };

    if (t.accent) {
        r.setProperty('--accent', t.accent);
        const [ar, ag, ab] = hex2rgb(t.accent);
        r.setProperty('--accent-glow', `rgba(${ar}, ${ag}, ${ab}, 0.25)`);
    }
    if (t.accentLight) r.setProperty('--accent-light', t.accentLight);
    if (t.green) {
        r.setProperty('--green', t.green);
        const [gr, gg, gb] = hex2rgb(t.green);
        r.setProperty('--green-glow', `rgba(${gr}, ${gg}, ${gb}, 0.2)`);
    }
    if (t.red) {
        r.setProperty('--red', t.red);
        const [rr, rg, rb] = hex2rgb(t.red);
        r.setProperty('--red-glow', `rgba(${rr}, ${rg}, ${rb}, 0.2)`);
    }
    if (t.orange) {
        r.setProperty('--orange', t.orange);
        const [or2, og, ob] = hex2rgb(t.orange);
        r.setProperty('--orange-glow', `rgba(${or2}, ${og}, ${ob}, 0.2)`);
    }
    if (t.bgPrimary) {
        const [pr, pg, pb] = hex2rgb(t.bgPrimary);
        r.setProperty('--bg-primary', `rgba(${pr}, ${pg}, ${pb}, 0.92)`);
    }
    if (t.bgSecondary) {
        const [sr, sg, sb] = hex2rgb(t.bgSecondary);
        r.setProperty('--bg-secondary', `rgba(${sr}, ${sg}, ${sb}, 0.85)`);
    }
    if (t.bgCard) {
        const [cr, cg, cb] = hex2rgb(t.bgCard);
        r.setProperty('--bg-card', `rgba(${cr}, ${cg}, ${cb}, 0.7)`);
        r.setProperty('--bg-input', `rgba(${cr + 6}, ${cg + 6}, ${cb + 10}, 0.6)`);
        r.setProperty('--bg-hover', `rgba(${cr + 18}, ${cg + 18}, ${cb + 30}, 0.5)`);
    }
    if (t.textPrimary) r.setProperty('--text-primary', t.textPrimary);
    if (t.textSecondary) {
        const [tr, tg, tb] = hex2rgb(t.textSecondary);
        r.setProperty('--text-secondary', `rgba(${tr}, ${tg}, ${tb}, 0.7)`);
        r.setProperty('--text-muted', `rgba(${Math.max(0,tr-40)}, ${Math.max(0,tg-40)}, ${Math.max(0,tb-40)}, 0.5)`);
    }
}

/* ================================================================
   App
   ================================================================ */
const App = {
    /* ---- Open / Close ---- */
    open(page, extra) {
        applyPlayerI18n();
        const app = document.getElementById('app');
        app.classList.remove('hidden', 'closing');
        currentLocationId = extra?.locationId || currentLocationId;
        this.goTo(page || 'catalog');
    },

    close() {
        if (this._rentalTimerInterval) { clearInterval(this._rentalTimerInterval); this._rentalTimerInterval = null; }
        const app = document.getElementById('app');
        app.classList.add('closing');
        setTimeout(() => {
            app.classList.add('hidden');
            app.classList.remove('closing');
            nui('closeUI');
        }, 260);
    },

    /* ---- Navigation ---- */
    goTo(page) {
        if (page !== 'activeRental' && this._rentalTimerInterval) { clearInterval(this._rentalTimerInterval); this._rentalTimerInterval = null; }
        document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
        document.querySelectorAll('.nav-link').forEach(n => n.classList.remove('active'));
        const el = document.getElementById('page-' + page);
        if (el) {
            el.classList.add('active');
            el.style.animation = 'none';
            el.offsetHeight;
            el.style.animation = '';
        }
        const nav = document.querySelector(`.nav-link[data-page="${page}"]`);
        if (nav) nav.classList.add('active');

        if (page === 'catalog') this.loadCatalog();
        else if (page === 'activeRental') this.loadActiveRental();
        else if (page === 'history') this.loadHistory();
    },

    /* ================================================================
       CATALOG
       ================================================================ */
    async loadCatalog() {
        const grid = document.getElementById('vehicle-grid');
        grid.innerHTML = Array(6).fill('<div class="skeleton skeleton-card"></div>').join('');

        let data = await nui('getVehicles', { locationId: currentLocationId });
        vehicles = Array.isArray(data) ? data : [];

        if (!vehicles.length) {
            await new Promise(r => setTimeout(r, 1500));
            data = await nui('getVehicles', { locationId: currentLocationId });
            vehicles = Array.isArray(data) ? data : [];
        }

        this.buildFilters();
        this.renderCatalog(vehicles);
    },

    buildFilters() {
        const cats = [...new Set(vehicles.map(v => v.category))];
        const chips = document.getElementById('filter-chips');
        const labels = boot().categories || {};
        const allLab = labels.all || 'Tous';
        chips.innerHTML = `<span class="chip active" data-cat="all" onclick="App.toggleFilter(this)">${allLab}</span>`;
        cats.forEach(c => {
            const label = labels[c] || (c.charAt(0).toUpperCase() + c.slice(1));
            chips.innerHTML += `<span class="chip" data-cat="${c}" onclick="App.toggleFilter(this)">${label}</span>`;
        });
    },

    toggleFilter(el) {
        document.querySelectorAll('.filter-chips .chip').forEach(c => c.classList.remove('active'));
        el.classList.add('active');
        this.filterCatalog();
    },

    filterCatalog() {
        const search = (document.getElementById('search-input').value || '').toLowerCase();
        const cat = document.querySelector('.filter-chips .chip.active')?.dataset.cat || 'all';
        const sort = document.getElementById('sort-select').value;

        let list = vehicles.filter(v => {
            if (cat !== 'all' && v.category !== cat) return false;
            if (search && !v.label.toLowerCase().includes(search) && !v.model.toLowerCase().includes(search)) return false;
            return true;
        });

        if (sort === 'price-asc') list.sort((a,b) => a.price_per_day - b.price_per_day);
        else if (sort === 'price-desc') list.sort((a,b) => b.price_per_day - a.price_per_day);
        else if (sort === 'name') list.sort((a,b) => a.label.localeCompare(b.label));
        else if (sort === 'speed') list.sort((a,b) => (b.speed||0) - (a.speed||0));

        this.renderCatalog(list);
    },

    renderCatalog(list) {
        const grid = document.getElementById('vehicle-grid');
        if (!list || !list.length) {
            grid.innerHTML = `<div class="history-empty">
                <i class="fa-solid fa-car" style="font-size:32px;margin-bottom:12px;display:block;color:var(--text-muted)"></i>
                <p>${__('cat_empty_title')}</p>
                <p style="font-size:11px;color:var(--text-muted);margin-top:6px">${__('cat_empty_hint')}</p>
            </div>`;
            return;
        }
        grid.innerHTML = list.map(v => {
            const tags = (v.tags || '').split(',').filter(t => t.trim()).slice(0, 3);
            const tagHtml = tags.map(t => `<span class="v-tag ${tagClass(t.trim())}">${t.trim()}</span>`).join('');
            return `
            <div class="v-card" onclick="App.viewVehicle('${v.model}')">
                <div class="v-card-img">
                    <img src="${vehImgSrc(v.model, v.image_url)}" data-model="${v.model}" data-tried="0" loading="lazy" onerror="imgFallback(this)" onload="imgLoaded(this)" alt="${v.label}">
                    <div class="v-card-tags">${tagHtml}</div>
                </div>
                <div class="v-card-body">
                    <h3>${v.label}</h3>
                    <div class="v-category">${(boot().categories && boot().categories[v.category]) || v.category}</div>
                    <div class="v-mini-stats">
                        <div class="v-mini-stat">
                            <label>${__('stat_speed')}</label>
                            <div class="stat-bar"><div class="stat-fill speed" style="width:${v.speed||50}%"></div></div>
                        </div>
                        <div class="v-mini-stat">
                            <label>${__('stat_handling')}</label>
                            <div class="stat-bar"><div class="stat-fill handling" style="width:${v.handling||50}%"></div></div>
                        </div>
                        <div class="v-mini-stat">
                            <label>${__('stat_braking')}</label>
                            <div class="stat-bar"><div class="stat-fill braking" style="width:${v.braking||50}%"></div></div>
                        </div>
                    </div>
                </div>
                <div class="v-card-footer">
                    <span class="v-price">${money(v.price_per_day)} <small>${__('per_day')}</small></span>
                </div>
            </div>`;
        }).join('');
    },

    /* ================================================================
       VEHICLE DETAIL
       ================================================================ */
    viewVehicle(model) {
        currentVehicle = vehicles.find(v => v.model === model);
        if (!currentVehicle) return;
        const defPay = boot().defaultPayment === 'cash' ? 'cash' : 'bank';
        rentalConfig = { duration: null, insurance: 'none', fuelPolicy: 'full_to_full', payment: defPay, delivery: false };
        currentPrice = null;

        document.getElementById('detail-name').textContent = currentVehicle.label;
        document.getElementById('detail-base-price').innerHTML = `${money(currentVehicle.price_per_day)} <small>${__('per_day')}</small>`;

        const img = document.getElementById('detail-img');
        img.dataset.model = currentVehicle.model;
        img.dataset.tried = '0';
        img.src = vehImgSrc(currentVehicle.model, currentVehicle.image_url);
        img.onerror = function() { imgFallback(this); };
        img.onload = function() { imgLoaded(this); };

        const tags = (currentVehicle.tags || '').split(',').filter(t => t.trim());
        document.getElementById('detail-tags').innerHTML = tags.map(t =>
            `<span class="v-tag ${tagClass(t.trim())}">${t.trim()}</span>`
        ).join('');

        const stats = [
            { label: __('stat_speed'), value: currentVehicle.speed || 50, color: 'var(--accent)' },
            { label: __('stat_handling'), value: currentVehicle.handling || 50, color: 'var(--green)' },
            { label: __('stat_braking'), value: currentVehicle.braking || 50, color: 'var(--orange)' },
            { label: __('stat_seats'), value: currentVehicle.seats, color: null },
            { label: __('stat_trunk'), value: currentVehicle.trunk, color: null },
            { label: __('stat_deposit'), value: null, money: currentVehicle.deposit, color: null },
        ];

        document.getElementById('detail-stats').innerHTML = stats.map(s => {
            if (s.money !== undefined) {
                return `<div class="stat-box"><div class="stat-value">${money(s.money)}</div><div class="stat-label">${s.label}</div></div>`;
            }
            if (s.color) {
                return `<div class="stat-box"><div class="stat-value">${s.value}</div><div class="stat-label">${s.label}</div>
                    <div class="stat-bar-wrap"><div class="stat-bar-fill" style="width:${s.value}%;background:${s.color}"></div></div></div>`;
            }
            return `<div class="stat-box"><div class="stat-value">${s.value}</div><div class="stat-label">${s.label}</div></div>`;
        }).join('');

        const durations = boot().durations || [];
        document.getElementById('duration-options').innerHTML = durations.map(d =>
            `<button class="option-btn" onclick="App.setDuration(${d.minutes}, this)">${d.label}</button>`
        ).join('');

        const insChoices = boot().insurance || [];
        document.getElementById('insurance-options').innerHTML = insChoices.map(i =>
            `<button class="option-btn ${rentalConfig.insurance === i.key ? 'active' : ''}" onclick="App.setInsurance('${i.key}', this)">${i.label}</button>`
        ).join('');

        const fuelChoices = boot().fuel || [];
        document.getElementById('fuel-options').innerHTML = fuelChoices.map(f =>
            `<button class="option-btn ${rentalConfig.fuelPolicy === f.key ? 'active' : ''}" onclick="App.setFuel('${f.key}', this)">${f.label}</button>`
        ).join('');

        const pm = boot().payment || [];
        document.getElementById('payment-options').innerHTML = pm.map(p =>
            `<button class="option-btn ${rentalConfig.payment === p.key ? 'active' : ''}" onclick="App.setPayment('${p.key}', this)">${p.label}</button>`
        ).join('');

        document.getElementById('price-summary').innerHTML = `<div style="color:var(--text-muted);text-align:center;padding:12px;font-size:13px;">${__('select_duration')}</div>`;
        document.getElementById('btn-rent').disabled = true;

        this.goTo('detail');
    },

    selectOption(btn, containerId) {
        document.querySelectorAll(`#${containerId} .option-btn`).forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
    },

    setDuration(min, btn) {
        this.selectOption(btn, 'duration-options');
        rentalConfig.duration = min;
        this.recalcPrice();
    },

    setInsurance(key, btn) {
        this.selectOption(btn, 'insurance-options');
        rentalConfig.insurance = key;
        this.recalcPrice();
    },

    setFuel(key, btn) {
        this.selectOption(btn, 'fuel-options');
        rentalConfig.fuelPolicy = key;
        this.recalcPrice();
    },

    setPayment(key, btn) {
        this.selectOption(btn, 'payment-options');
        rentalConfig.payment = key;
    },

    async recalcPrice() {
        if (!rentalConfig.duration || !currentVehicle || !currentLocationId) return;
        const btn = document.getElementById('btn-rent');
        btn.disabled = true;

        currentPrice = await nui('calculatePrice', {
            model: currentVehicle.model,
            locationId: currentLocationId,
            duration: rentalConfig.duration,
            insurance: rentalConfig.insurance,
            fuelPolicy: rentalConfig.fuelPolicy,
            delivery: rentalConfig.delivery,
        });

        if (!currentPrice) {
            document.getElementById('price-summary').innerHTML = `<div style="color:var(--red);text-align:center;padding:12px">${__('price_err')}</div>`;
            return;
        }

        document.getElementById('price-summary').innerHTML = `
            <div class="price-row"><span>${__('price_base')}</span><span>${money(currentPrice.base)}</span></div>
            ${currentPrice.insurance > 0 ? `<div class="price-row"><span>${__('price_insurance')}</span><span>${money(currentPrice.insurance)}</span></div>` : ''}
            ${currentPrice.fuel > 0 ? `<div class="price-row"><span>${__('price_fuel_flat')}</span><span>${money(currentPrice.fuel)}</span></div>` : ''}
            ${currentPrice.delivery > 0 ? `<div class="price-row"><span>${__('price_delivery')}</span><span>${money(currentPrice.delivery)}</span></div>` : ''}
            <div class="price-row"><span>${__('price_deposit')}</span><span>${money(currentPrice.deposit)}</span></div>
            <div class="price-row total"><span>${__('price_total')}</span><span>${money(currentPrice.grandTotal)}</span></div>
        `;
        btn.disabled = false;
    },

    /* ================================================================
       SHOWROOM
       ================================================================ */
    async showroom() {
        if (!currentVehicle || !currentLocationId) return;
        toast(__('toast_loading_showroom'), 'info', 2000);
        const r = await nui('showroomPreview', { model: currentVehicle.model, locationId: currentLocationId });
        if (r && r.ok) {
            this.close();
            toast(__('toast_esc_showroom'), 'info', 5000);
        }
    },

    /* ================================================================
       CONTRACT PAGE
       ================================================================ */
    async goToContract() {
        if (!currentVehicle || !currentPrice || !rentalConfig.duration) return;

        document.getElementById('contract-stamp').classList.add('hidden');
        document.getElementById('ctr-accept').checked = false;
        document.getElementById('btn-sign').disabled = true;

        const info = await nui('getPlayerInfo') || {};
        const now = new Date();
        const contractNum = 'PR-' + String(now.getFullYear()).slice(2) + String(now.getMonth()+1).padStart(2,'0') + '-####';

        document.getElementById('contract-num-display').textContent = contractNum;
        document.getElementById('ctr-player').textContent = info.name || 'Joueur';
        document.getElementById('ctr-date').textContent = now.toLocaleDateString(boot().localeTag || 'fr-FR') + ' ' + now.toLocaleTimeString(boot().localeTag || 'fr-FR', { hour:'2-digit', minute:'2-digit' });
        document.getElementById('ctr-vehicle').textContent = currentVehicle.label;
        document.getElementById('ctr-duration').textContent = durationLabel(rentalConfig.duration);
        document.getElementById('ctr-price').textContent = money(currentPrice.total);

        document.getElementById('ctr-insurance').textContent = insLabel(rentalConfig.insurance);

        document.getElementById('ctr-fuel').textContent = fuelLabel(rentalConfig.fuelPolicy) || '—';

        document.getElementById('ctr-deposit').textContent = money(currentPrice.deposit);
        document.getElementById('ctr-total').textContent = money(currentPrice.grandTotal);

        document.getElementById('ctr-accept').onchange = function() {
            document.getElementById('btn-sign').disabled = !this.checked;
        };

        this.goTo('contract');
    },

    async signContract() {
        if (!document.getElementById('ctr-accept').checked) return;
        const btn = document.getElementById('btn-sign');
        btn.disabled = true;
        btn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> ${__('processing')}`;

        const result = await nui('rent', {
            model: currentVehicle.model,
            duration: rentalConfig.duration,
            insurance: rentalConfig.insurance,
            fuelPolicy: rentalConfig.fuelPolicy,
            payment: rentalConfig.payment,
            delivery: rentalConfig.delivery,
            locationId: currentLocationId,
        });

        if (result && result.ok) {
            document.getElementById('contract-stamp').classList.remove('hidden');
            toast(__('signed_ok'), 'success');
            setTimeout(() => App.close(), 2000);
        } else {
            toast(result?.msg || __('sign_err'), 'error');
            btn.disabled = false;
            btn.innerHTML = `<i class="fa-solid fa-signature"></i> ${__('sign_pay')}`;
        }
    },

    /* ================================================================
       ACTIVE RENTAL
       ================================================================ */
    _rentalTimerInterval: null,

    async loadActiveRental() {
        if (this._rentalTimerInterval) { clearInterval(this._rentalTimerInterval); this._rentalTimerInterval = null; }

        const contract = await nui('getActiveContract');
        const noMsg = document.getElementById('no-rental-msg');
        const card = document.getElementById('rental-card');

        if (!contract) {
            noMsg.classList.remove('hidden');
            card.classList.add('hidden');
            return;
        }
        noMsg.classList.add('hidden');
        card.classList.remove('hidden');
        activeContract = contract;

        const img = document.getElementById('rental-img');
        img.dataset.model = contract.vehicle_model;
        img.dataset.tried = '0';
        img.src = vehImgSrc(contract.vehicle_model, '');
        img.onerror = function() { imgFallback(this); };
        img.onload = function() { imgLoaded(this); };

        const veh = vehicles.find(v => v.model === contract.vehicle_model);
        document.getElementById('rental-model').textContent = veh ? veh.label : contract.vehicle_model;
        document.getElementById('rental-plate').textContent = contract.plate;

        const serverNow = contract.serverTime || Date.now();
        const offset = Date.now() - serverNow;
        const tv = document.getElementById('timer-value');

        const updateTimer = () => {
            const rem = contract.end_ts - (Date.now() - offset);
            tv.textContent = msToTime(rem);
            tv.classList.toggle('expired', rem <= 0);
        };
        updateTimer();
        this._rentalTimerInterval = setInterval(updateTimer, 1000);

        document.getElementById('rental-details-grid').innerHTML = `
            <div class="rental-detail-item"><span>${__('rental_contract')}</span><span>${contract.contract_num || '#' + contract.id}</span></div>
            <div class="rental-detail-item"><span>${__('rental_start')}</span><span>${dateStr(contract.start_ts)}</span></div>
            <div class="rental-detail-item"><span>${__('rental_end')}</span><span>${dateStr(contract.end_ts)}</span></div>
            <div class="rental-detail-item"><span>${__('rental_insurance')}</span><span>${insLabel(contract.insurance) || '—'}</span></div>
            <div class="rental-detail-item"><span>${__('rental_fuel')}</span><span>${fuelLabel(contract.fuel_policy) || '—'}</span></div>
            <div class="rental-detail-item"><span>${__('rental_deposit_lbl')}</span><span>${money(contract.deposit)}</span></div>
        `;

        document.getElementById('extend-panel').classList.add('hidden');
        // Reset page scan pour éviter états invalides entre plusieurs restitutions
        scanResult = null;
        document.getElementById('scan-result')?.classList.add('hidden');
        const confirmBtn = document.getElementById('btn-confirm-return');
        if (confirmBtn) {
            confirmBtn.classList.add('hidden');
            confirmBtn.onclick = () => App.confirmReturn();
            confirmBtn.disabled = false;
            confirmBtn.innerHTML = `<i class="fa-solid fa-check"></i> ${__('confirm_return')}`;
        }
    },

    gpsReturn() {
        nui('gpsReturn');
        toast(__('toast_gps'), 'success');
    },

    openExtend() {
        const panel = document.getElementById('extend-panel');
        panel.classList.toggle('hidden');
        if (!panel.classList.contains('hidden')) {
            const opts = boot().quickExtend || [];
            document.getElementById('extend-options').innerHTML = opts.map(o =>
                `<button class="extend-btn" onclick="App.doExtend(${o.minutes}, this)">${o.label}</button>`
            ).join('');
        }
    },

    async doExtend(minutes, btn) {
        btn.disabled = true;
        btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i>';
        const pm = (activeContract && activeContract.payment_method) || boot().defaultPayment || 'bank';
        const r = await nui('extend', { duration: minutes, payment: pm });
        if (r && r.ok) {
            toast(`${__('extend_done')} — ${durationLabel(minutes)} — ${money(r.cost)}`, 'success');
            this.loadActiveRental();
        } else {
            toast(r?.msg || __('toast_extend_err'), 'error');
            btn.disabled = false;
            btn.textContent = (boot().quickExtend || []).find(q => q.minutes === minutes)?.label || ('+' + durationLabel(minutes));
        }
    },

    /* ================================================================
       SCAN / RETURN
       ================================================================ */
    async startReturn() {
        scanResult = null;
        document.getElementById('scan-result').classList.add('hidden');
        document.getElementById('btn-confirm-return').classList.add('hidden');
        document.getElementById('btn-scan').classList.add('hidden');
        ['body', 'engine', 'fuel', 'wheels'].forEach(k => {
            const fill = document.getElementById('scan-' + k);
            if (fill) { fill.style.width = '0%'; fill.className = 'scan-fill'; }
            const val = document.getElementById('scan-' + k + '-val');
            if (val) val.textContent = '—';
            const item = fill?.closest('.scan-item');
            if (item) item.className = 'scan-item';
        });
        this.goTo('scan');

        await new Promise(r => setTimeout(r, 300));

        const data = await nui('scanVehicle');

        if (!data) {
            toast(__('toast_scan_fail'), 'error');
            return;
        }

        const checks = ['body', 'engine', 'fuel', 'wheels'];
        for (let i = 0; i < checks.length; i++) {
            const k = checks[i];
            const item = document.querySelector(`.scan-item[data-check="${k}"]`);
            const fill = document.getElementById('scan-' + k);
            const val = document.getElementById('scan-' + k + '-val');

            if (item) item.classList.add('scanning');
            await new Promise(r => setTimeout(r, 600));

            const v = data[k] ?? 0;
            const cls = v >= 70 ? 'good' : (v >= 40 ? 'medium' : 'bad');
            if (fill) { fill.style.width = v + '%'; fill.className = 'scan-fill ' + cls; }
            if (val) {
                val.textContent = v + '%';
                val.style.color = v >= 70 ? 'var(--green)' : (v >= 40 ? 'var(--orange)' : 'var(--red)');
            }
            if (item) {
                item.classList.remove('scanning');
                item.classList.add(v >= 70 ? 'done' : (v >= 40 ? 'warn' : 'bad'));
            }
        }

        scanResult = data;
        const confirmBtn = document.getElementById('btn-confirm-return');
        confirmBtn.classList.remove('hidden');
        confirmBtn.onclick = () => App.confirmReturn();
        confirmBtn.disabled = false;
        confirmBtn.innerHTML = `<i class="fa-solid fa-check"></i> ${__('confirm_return')}`;

        if (data.destroyed) {
            toast(__('toast_destroyed'), 'warning');
        } else {
            toast(__('toast_scan_done'), 'info');
        }
    },

    async confirmReturn() {
        const btn = document.getElementById('btn-confirm-return');
        btn.disabled = true;
        btn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> ${__('returning')}`;

        const result = await nui('returnVehicle', {});

        if (result && result.ok) {
            const penDiv = document.getElementById('scan-penalties');
            const sumDiv = document.getElementById('scan-summary');
            const p = result.penalties || {};

            let penHtml = '';
            if (p.late > 0) penHtml += `<div class="scan-penalty-row"><span>${__('pen_late')}</span><span>-${money(p.late)}</span></div>`;
            if (p.damage > 0) penHtml += `<div class="scan-penalty-row"><span>${__('pen_damage')}</span><span>-${money(p.damage)}</span></div>`;
            if (p.fuel > 0) penHtml += `<div class="scan-penalty-row"><span>${__('pen_fuel')}</span><span>-${money(p.fuel)}</span></div>`;
            if (p.wheels > 0) penHtml += `<div class="scan-penalty-row"><span>${__('pen_wheels')}</span><span>-${money(p.wheels)}</span></div>`;
            if (p.destroyed > 0) penHtml += `<div class="scan-penalty-row"><span>${__('pen_destroyed')}</span><span>-${money(p.destroyed)}</span></div>`;
            if (!penHtml) penHtml = `<div class="scan-penalty-row"><span>${__('pen_none')}</span><span class="none">$0</span></div>`;
            penDiv.innerHTML = penHtml;

            let sumHtml = '';
            sumHtml += `<div class="scan-summary-row"><span>${__('sum_pen_total')}</span><span>-${money(result.totalPen)}</span></div>`;
            sumHtml += `<div class="scan-summary-row"><span>${__('sum_deposit_init')}</span><span>${money(result.deposit)}</span></div>`;
            if (result.refund > 0)
                sumHtml += `<div class="scan-summary-row refund"><span>${__('sum_refund')}</span><span>+${money(result.refund)}</span></div>`;
            if (result.extraCharge > 0)
                sumHtml += `<div class="scan-summary-row charge"><span>${__('sum_extra')}</span><span>-${money(result.extraCharge)}</span></div>`;
            sumDiv.innerHTML = sumHtml;

            document.getElementById('scan-result').classList.remove('hidden');
            btn.disabled = false;
            btn.innerHTML = `<i class="fa-solid fa-check"></i> ${__('btn_done')}`;
            btn.onclick = () => App.close();

            toast(__('toast_return_ok'), 'success');
        } else {
            toast(__('toast_return_fail'), 'error');
            btn.disabled = false;
            btn.innerHTML = `<i class="fa-solid fa-check"></i> ${__('confirm_return')}`;
        }
    },

    /* ================================================================
       HISTORY
       ================================================================ */
    async loadHistory() {
        const list = document.getElementById('history-list');
        list.innerHTML = '<div class="skeleton skeleton-card" style="height:60px"></div>'.repeat(3);

        const data = await nui('getHistory') || [];
        if (!data.length) {
            list.innerHTML = `<div class="history-empty"><i class="fa-solid fa-clock-rotate-left" style="font-size:32px;margin-bottom:8px;display:block"></i>${__('hist_empty')}</div>`;
            return;
        }

        list.innerHTML = data.map(h => {
            const pen = h.total_penalties || 0;
            const ref = h.refunded_deposit || 0;
            return `
            <div class="history-item">
                <img src="${vehImgSrc(h.vehicle_model, '')}" data-model="${h.vehicle_model}" onerror="imgFallback(this)" onload="imgLoaded(this)" alt="">
                <div class="history-info">
                    <h4>${h.vehicle_model} — ${h.plate}</h4>
                    <div class="history-meta">${h.contract_num || '#'+h.contract_id} • ${dateStr(h.start_ts)} → ${h.returned_at || '—'}</div>
                </div>
                <div class="history-amounts">
                    ${pen > 0 ? `<div class="h-penalties">-${money(pen)}</div>` : ''}
                    <div class="h-refund">+${money(ref)}</div>
                </div>
            </div>`;
        }).join('');
    },

    closeModal() {
        document.getElementById('modal-overlay').classList.add('hidden');
    },
};

/* ================================================================
   ADMIN PANEL — Separate interface (Admin object)
   Opened via /rentaladmin command, restricted to admins
   ================================================================ */
let admData = null;

const Admin = {
    _savedForm: null,

    open() {
        document.getElementById('admin-app').classList.remove('hidden');
        this.goTo('adm-dashboard');
        this.loadData();
    },

    close() {
        const el = document.getElementById('admin-app');
        el.classList.add('closing');
        setTimeout(() => { el.classList.add('hidden'); el.classList.remove('closing'); nui('closeUI'); }, 260);
    },

    async loadData() {
        admData = await nui('adminGetAll') || {};
        const sec = document.querySelector('.adm-link.active')?.dataset.section;
        if (sec) this.renderSection(sec);
    },

    goTo(section) {
        document.querySelectorAll('.adm-page').forEach(p => p.classList.remove('active'));
        document.querySelectorAll('.adm-link').forEach(n => n.classList.remove('active'));
        const el = document.getElementById(section);
        if (el) { el.classList.add('active'); el.style.animation = 'none'; el.offsetHeight; el.style.animation = ''; }
        const nav = document.querySelector(`.adm-link[data-section="${section}"]`);
        if (nav) nav.classList.add('active');
        this.renderSection(section);
    },

    renderSection(id) {
        if (id === 'adm-dashboard')  this.renderDashboard();
        if (id === 'adm-vehicles')   this.renderVehicles();
        if (id === 'adm-locations')  this.renderLocations();
        if (id === 'adm-contracts')  this.renderContracts();
    },

    /* ---- Dashboard ---- */
    renderDashboard() {
        const v = admData?.vehicles || [];
        const l = admData?.locations || [];
        const c = admData?.contracts || [];
        document.getElementById('adm-dashboard').innerHTML = `
            <div class="adm-header"><h1><i class="fa-solid fa-chart-line"></i> Dashboard</h1></div>
            <div class="adm-stats-row">
                <div class="adm-stat-card"><div class="adm-stat-num">${v.length}</div><div class="adm-stat-label">Véhicules</div><i class="fa-solid fa-car"></i></div>
                <div class="adm-stat-card"><div class="adm-stat-num">${l.length}</div><div class="adm-stat-label">Points de location</div><i class="fa-solid fa-location-dot"></i></div>
                <div class="adm-stat-card"><div class="adm-stat-num">${c.length}</div><div class="adm-stat-label">Contrats actifs</div><i class="fa-solid fa-file-contract"></i></div>
                <div class="adm-stat-card"><div class="adm-stat-num">${v.filter(x => x.enabled).length}</div><div class="adm-stat-label">Véhicules actifs</div><i class="fa-solid fa-circle-check"></i></div>
            </div>
            ${c.length ? `<div class="adm-section-title">Derniers contrats actifs</div>
            <table class="admin-table"><thead><tr><th>#</th><th>Joueur</th><th>Véhicule</th><th>Plaque</th><th>Fin</th></tr></thead>
            <tbody>${c.slice(0, 5).map(ct => `<tr><td>${ct.contract_num || ct.id}</td><td>${ct.player_name || ct.identifier}</td><td>${ct.vehicle_model}</td><td><code>${ct.plate}</code></td><td>${dateStr(ct.end_ts)}</td></tr>`).join('')}</tbody></table>` : ''}
        `;
    },

    /* ---- Vehicles ---- */
    renderVehicles() {
        const list = admData?.vehicles || [];
        document.getElementById('adm-vehicles').innerHTML = `
            <div class="adm-header"><h1><i class="fa-solid fa-car"></i> Véhicules</h1>
                <button class="admin-btn add" onclick="Admin.newVehicle()"><i class="fa-solid fa-plus"></i> Ajouter</button></div>
            <table class="admin-table">
                <thead><tr><th>Image</th><th>Modèle</th><th>Label</th><th>Cat.</th><th>Prix/j</th><th>Caution</th><th>Actif</th><th>Actions</th></tr></thead>
                <tbody>${list.map(v => `<tr>
                    <td><img src="${vehImgSrc(v.model, v.image_url)}" onerror="this.style.display='none'" style="width:48px;height:30px;object-fit:contain;border-radius:4px"></td>
                    <td><code>${v.model}</code></td><td>${v.label}</td><td>${v.category}</td>
                    <td>${money(v.price_per_day)}</td><td>${money(v.deposit)}</td>
                    <td><span class="admin-loc-status ${v.enabled ? 'active' : ''}">${v.enabled ? 'Oui' : 'Non'}</span></td>
                    <td><button class="admin-btn" onclick="Admin.editVehicle(${v.id})"><i class="fa-solid fa-pen"></i></button>
                        <button class="admin-btn danger" onclick="Admin.deleteVehicle(${v.id})"><i class="fa-solid fa-trash"></i></button></td>
                </tr>`).join('')}</tbody>
            </table>`;
    },

    newVehicle() { this.openVehicleModal({}); },
    editVehicle(id) { const v = (admData?.vehicles || []).find(x => x.id === id); if (v) this.openVehicleModal(v); },

    openVehicleModal(v) {
        const box = document.getElementById('modal-box');
        const isEdit = !!v.id;
        box.innerHTML = `
            <div class="modal-title">${isEdit ? 'Modifier' : 'Nouveau'} véhicule</div>
            <div class="modal-field"><label>Modèle (spawn name)</label><input id="mv-model" value="${v.model||''}" ${isEdit ? 'disabled' : ''}></div>
            <div class="modal-field"><label>Label</label><input id="mv-label" value="${v.label||''}"></div>
            <div class="modal-row-4">
                <div class="modal-field"><label>Catégorie</label><input id="mv-cat" value="${v.category||'sedan'}"></div>
                <div class="modal-field"><label>Tags</label><input id="mv-tags" value="${v.tags||''}" placeholder="sport,jdm"></div>
                <div class="modal-field"><label>Prix/jour</label><input type="number" id="mv-price" value="${v.price_per_day||500}"></div>
                <div class="modal-field"><label>Caution</label><input type="number" id="mv-deposit" value="${v.deposit||1000}"></div>
            </div>
            <div class="modal-row-4">
                <div class="modal-field"><label>Places</label><input type="number" id="mv-seats" value="${v.seats||4}"></div>
                <div class="modal-field"><label>Coffre</label><input type="number" id="mv-trunk" value="${v.trunk||40}"></div>
                <div class="modal-field"><label>Vitesse</label><input type="number" id="mv-speed" value="${v.speed||50}"></div>
                <div class="modal-field"><label>Maniabilité</label><input type="number" id="mv-handling" value="${v.handling||50}"></div>
            </div>
            <div class="modal-row-4">
                <div class="modal-field"><label>Freinage</label><input type="number" id="mv-braking" value="${v.braking||50}"></div>
                <div class="modal-field"><label>Stock (-1=∞)</label><input type="number" id="mv-stock" value="${v.stock ?? -1}"></div>
                <div class="modal-field" style="grid-column:span 2"><label>Image URL</label><input id="mv-img" value="${v.image_url||''}"></div>
            </div>
            <div class="modal-field"><label><input type="checkbox" id="mv-enabled" ${v.enabled !== 0 ? 'checked' : ''}> Activé</label></div>
            <div class="modal-actions">
                <button class="modal-btn" onclick="Admin.closeModal()">Annuler</button>
                <button class="modal-btn primary" onclick="Admin.saveVehicle(${v.id || 'null'})">Enregistrer</button>
            </div>`;
        document.getElementById('modal-overlay').classList.remove('hidden');
    },

    closeModal() { document.getElementById('modal-overlay').classList.add('hidden'); },

    async saveVehicle(id) {
        const data = {
            id, model: document.getElementById('mv-model').value.trim(),
            label: document.getElementById('mv-label').value.trim(),
            category: document.getElementById('mv-cat').value.trim(),
            tags: document.getElementById('mv-tags').value.trim(),
            price_per_day: parseInt(document.getElementById('mv-price').value) || 500,
            deposit: parseInt(document.getElementById('mv-deposit').value) || 1000,
            seats: parseInt(document.getElementById('mv-seats').value) || 4,
            trunk: parseInt(document.getElementById('mv-trunk').value) || 40,
            speed: parseInt(document.getElementById('mv-speed').value) || 50,
            handling: parseInt(document.getElementById('mv-handling').value) || 50,
            braking: parseInt(document.getElementById('mv-braking').value) || 50,
            stock: parseInt(document.getElementById('mv-stock').value),
            image_url: document.getElementById('mv-img').value.trim(),
            enabled: document.getElementById('mv-enabled').checked,
        };
        if (!data.model || !data.label) { toast('Modèle et label requis', 'error'); return; }
        const r = await nui('adminSaveVehicle', data);
        if (r?.ok) { toast('Véhicule sauvegardé', 'success'); this.closeModal(); this.loadData(); }
        else toast('Erreur', 'error');
    },

    async deleteVehicle(id) {
        const { confirmed } = await nui('requestConfirm', { title: 'Supprimer', message: 'Supprimer ce véhicule ?' });
        if (!confirmed) return;
        const r = await nui('adminDeleteVehicle', { id });
        if (r?.ok) { toast('Véhicule supprimé', 'success'); this.loadData(); }
    },

    /* ---- Contracts ---- */
    renderContracts() {
        const list = admData?.contracts || [];
        document.getElementById('adm-contracts').innerHTML = `
            <div class="adm-header"><h1><i class="fa-solid fa-file-contract"></i> Contrats actifs</h1>
                <button class="admin-btn" onclick="Admin.loadData()"><i class="fa-solid fa-rotate"></i> Rafraîchir</button></div>
            ${!list.length ? '<div class="adm-empty"><i class="fa-solid fa-inbox"></i><p>Aucun contrat actif</p></div>' : `
            <table class="admin-table">
                <thead><tr><th>#</th><th>Joueur</th><th>Véhicule</th><th>Plaque</th><th>Début</th><th>Fin</th><th>Caution</th><th>Actions</th></tr></thead>
                <tbody>${list.map(c => `<tr>
                    <td>${c.contract_num || c.id}</td>
                    <td>${c.player_name || c.identifier}</td>
                    <td>${c.vehicle_model}</td>
                    <td><code>${c.plate}</code></td>
                    <td>${dateStr(c.start_ts)}</td>
                    <td>${dateStr(c.end_ts)}</td>
                    <td>${money(c.deposit)}</td>
                    <td><button class="admin-btn danger" onclick="Admin.forceReturn(${c.id})"><i class="fa-solid fa-rotate-left"></i> Forcer</button>
                        <button class="admin-btn" onclick="Admin.refund(${c.id})"><i class="fa-solid fa-money-bill"></i> Remb.</button></td>
                </tr>`).join('')}</tbody>
            </table>`}`;
    },

    async forceReturn(id) {
        const { confirmed } = await nui('requestConfirm', { title: 'Forcer restitution', message: 'Forcer la restitution de ce contrat ?' });
        if (!confirmed) return;
        const r = await nui('adminForceReturn', { id });
        if (r?.ok) { toast('Restitution forcée', 'success'); this.loadData(); }
    },

    async refund(contractId) {
        const { value } = await nui('requestInput', { title: 'Remboursement', label: 'Montant', default: '' });
        if (!value) return;
        const amount = parseInt(value);
        if (isNaN(amount) || amount <= 0) { toast('Montant invalide', 'error'); return; }
        const r = await nui('adminRefund', { id: contractId, amount });
        if (r?.ok) toast(`Remboursement de ${money(amount)} effectué`, 'success');
        else toast('Erreur', 'error');
    },

    /* ---- Locations ---- */
    renderLocations() {
        const list = admData?.locations || [];
        document.getElementById('adm-locations').innerHTML = `
            <div class="adm-header"><h1><i class="fa-solid fa-location-dot"></i> Points de location</h1>
                <button class="admin-btn add" onclick="Admin.newLocation()"><i class="fa-solid fa-plus"></i> Nouveau point</button></div>
            ${!list.length ? '<div class="adm-empty"><i class="fa-solid fa-map-pin"></i><p>Aucun point de location</p></div>' : `
            <div class="admin-loc-grid">${list.map(loc => {
                const coords = typeof loc.coords_json === 'string' ? JSON.parse(loc.coords_json) : loc.coords_json;
                return `<div class="admin-loc-card ${loc.enabled ? '' : 'disabled'}">
                    <div class="admin-loc-header">
                        <div class="admin-loc-title"><i class="fa-solid fa-location-dot" style="color:var(--accent)"></i><span>${loc.name}</span><small>#${loc.id}</small></div>
                        <span class="admin-loc-status ${loc.enabled ? 'active' : ''}">${loc.enabled ? 'Actif' : 'Inactif'}</span>
                    </div>
                    <div class="admin-loc-info">
                        <div class="admin-loc-detail"><i class="fa-solid fa-crosshairs"></i> ${coords?.x?.toFixed(1) || '?'}, ${coords?.y?.toFixed(1) || '?'}, ${coords?.z?.toFixed(1) || '?'}</div>
                        <div class="admin-loc-detail"><i class="fa-solid fa-person"></i> ${loc.ped_model || '—'}</div>
                        <div class="admin-loc-detail"><i class="fa-solid fa-map"></i> Blip: ${loc.blip_sprite || 226} / Couleur: ${loc.blip_color || 3}</div>
                    </div>
                    <div class="admin-loc-actions">
                        <button class="admin-btn" onclick="Admin.editLocation(${loc.id})"><i class="fa-solid fa-pen"></i> Modifier</button>
                        <button class="admin-btn" onclick="Admin.editLocVehicles(${loc.id})"><i class="fa-solid fa-car"></i> Véhicules</button>
                        <button class="admin-btn danger" onclick="Admin.deleteLocation(${loc.id})"><i class="fa-solid fa-trash"></i></button>
                    </div>
                </div>`;
            }).join('')}</div>`}`;
    },

    newLocation() { this.openLocationModal({}); },

    editLocation(id) {
        const loc = (admData?.locations || []).find(l => l.id === id);
        if (!loc) return;
        this.openLocationModal({
            ...loc,
            coords: typeof loc.coords_json === 'string' ? JSON.parse(loc.coords_json) : loc.coords_json,
            spawnpoints: typeof loc.spawnpoints_json === 'string' ? JSON.parse(loc.spawnpoints_json) : loc.spawnpoints_json,
            return_point: loc.return_point_json ? (typeof loc.return_point_json === 'string' ? JSON.parse(loc.return_point_json) : loc.return_point_json) : null,
            showroom: loc.showroom_json ? (typeof loc.showroom_json === 'string' ? JSON.parse(loc.showroom_json) : loc.showroom_json) : null,
        });
    },

    openLocationModal(loc) {
        this._currentLocId = loc.id || null;
        const box = document.getElementById('modal-box');
        const isEdit = !!loc.id;
        const c = loc.coords || {}, sp = loc.spawnpoints || [], rp = loc.return_point || {}, sh = loc.showroom || {};
        const spawnRows = (arr) => arr.length ? arr.map((s,i) => this._spawnRow(s,i)).join('') : this._spawnRow({},0);
        const placeBtn = (type, label) => `<button class="admin-btn accent" onclick="Admin.placePoint('${type}')"><i class="fa-solid fa-person-walking"></i> ${label}</button>`;
        box.innerHTML = `
            <div class="modal-title"><i class="fa-solid fa-location-dot"></i> ${isEdit ? 'Modifier' : 'Nouveau'} point de location</div>
            <div class="modal-field"><label>Nom du point</label><input id="ml-name" value="${loc.name||''}" placeholder="Ex: Location Aéroport"></div>

            <div class="modal-section-title"><i class="fa-solid fa-crosshairs"></i> Coordonnées PNJ</div>
            <div class="modal-row-4">
                <div class="modal-field"><label>X</label><input type="number" step="0.01" id="ml-cx" value="${c.x||0}"></div>
                <div class="modal-field"><label>Y</label><input type="number" step="0.01" id="ml-cy" value="${c.y||0}"></div>
                <div class="modal-field"><label>Z</label><input type="number" step="0.01" id="ml-cz" value="${c.z||0}"></div>
                <div class="modal-field"><label>H</label><input type="number" step="0.01" id="ml-ch" value="${c.h||0}"></div>
            </div>
            <div class="placement-btns">${placeBtn('pnj', 'Se déplacer pour placer le PNJ')}</div>

            <div class="modal-section-title"><i class="fa-solid fa-car-on"></i> Point(s) de spawn véhicule</div>
            <div id="ml-spawns-container">${spawnRows(sp)}</div>
            <div class="placement-btns">
                <button class="admin-btn" onclick="Admin.addSpawnRow()"><i class="fa-solid fa-plus"></i> Ajouter manuellement</button>
                ${placeBtn('spawn', 'Placer les spawns en jeu')}
            </div>

            <div class="modal-section-title"><i class="fa-solid fa-flag-checkered"></i> Point de retour <small style="color:var(--text-muted)">(optionnel)</small></div>
            <div class="modal-row-4">
                <div class="modal-field"><label>X</label><input type="number" step="0.01" id="ml-rpx" value="${rp.x||''}"></div>
                <div class="modal-field"><label>Y</label><input type="number" step="0.01" id="ml-rpy" value="${rp.y||''}"></div>
                <div class="modal-field"><label>Z</label><input type="number" step="0.01" id="ml-rpz" value="${rp.z||''}"></div>
                <div class="modal-field"><label>H</label><input type="number" step="0.01" id="ml-rph" value="${rp.h||''}"></div>
            </div>
            <div class="placement-btns">${placeBtn('return', 'Se déplacer pour placer le retour')}</div>

            <div class="modal-section-title"><i class="fa-solid fa-camera"></i> Showroom <small style="color:var(--text-muted)">(optionnel)</small></div>
            <div class="modal-row-4">
                <div class="modal-field"><label>X</label><input type="number" step="0.01" id="ml-shx" value="${sh.x||''}"></div>
                <div class="modal-field"><label>Y</label><input type="number" step="0.01" id="ml-shy" value="${sh.y||''}"></div>
                <div class="modal-field"><label>Z</label><input type="number" step="0.01" id="ml-shz" value="${sh.z||''}"></div>
                <div class="modal-field"><label>H</label><input type="number" step="0.01" id="ml-shh" value="${sh.h||''}"></div>
            </div>
            <div class="placement-btns">${placeBtn('showroom', 'Se déplacer pour placer le showroom')}</div>

            <div class="modal-section-title"><i class="fa-solid fa-palette"></i> Apparence</div>
            <div class="modal-row-4">
                <div class="modal-field"><label>Blip sprite</label><input type="number" id="ml-bsprite" value="${loc.blip_sprite||226}"></div>
                <div class="modal-field"><label>Blip couleur</label><input type="number" id="ml-bcolor" value="${loc.blip_color||3}"></div>
                <div class="modal-field"><label>Blip scale</label><input type="number" step="0.1" id="ml-bscale" value="${loc.blip_scale||0.7}"></div>
                <div class="modal-field"><label>Modèle PNJ</label><input id="ml-ped" value="${loc.ped_model||'s_m_m_autoshop_02'}"></div>
            </div>
            <div class="modal-field"><label><input type="checkbox" id="ml-enabled" ${loc.enabled !== 0 ? 'checked' : ''}> Actif</label></div>
            <div class="modal-actions">
                <button class="modal-btn" onclick="Admin.closeModal()">Annuler</button>
                <button class="modal-btn primary" onclick="Admin.saveLocation(${loc.id||'null'})"><i class="fa-solid fa-floppy-disk"></i> Enregistrer</button>
            </div>`;
        document.getElementById('modal-overlay').classList.remove('hidden');
    },

    _spawnRow(s, i) {
        return `<div class="modal-row-4 spawn-row" data-idx="${i}">
            <div class="modal-field"><label>X</label><input type="number" step="0.01" class="sp-x" value="${s.x||0}"></div>
            <div class="modal-field"><label>Y</label><input type="number" step="0.01" class="sp-y" value="${s.y||0}"></div>
            <div class="modal-field"><label>Z</label><input type="number" step="0.01" class="sp-z" value="${s.z||0}"></div>
            <div class="modal-field" style="display:flex;align-items:end;gap:4px">
                <div style="flex:1"><label>H</label><input type="number" step="0.01" class="sp-h" value="${s.h||0}"></div>
                <button class="admin-btn danger" onclick="this.closest('.spawn-row').remove()" style="margin-bottom:0;height:32px"><i class="fa-solid fa-xmark"></i></button>
            </div></div>`;
    },

    addSpawnRow() {
        const c = document.getElementById('ml-spawns-container');
        const d = document.createElement('div'); d.innerHTML = this._spawnRow({}, c.children.length);
        c.appendChild(d.firstElementChild);
    },

    /* ---- Placement interactif en jeu ---- */
    _collectFormData() {
        const el = id => document.getElementById(id);
        if (!el('ml-name')) return {};
        const coords = { x: parseFloat(el('ml-cx')?.value)||0, y: parseFloat(el('ml-cy')?.value)||0,
            z: parseFloat(el('ml-cz')?.value)||0, h: parseFloat(el('ml-ch')?.value)||0 };
        const spawnpoints = [];
        document.querySelectorAll('#ml-spawns-container .spawn-row').forEach(row => {
            spawnpoints.push({ x: parseFloat(row.querySelector('.sp-x')?.value)||0, y: parseFloat(row.querySelector('.sp-y')?.value)||0,
                z: parseFloat(row.querySelector('.sp-z')?.value)||0, h: parseFloat(row.querySelector('.sp-h')?.value)||0 });
        });
        const rpx = el('ml-rpx')?.value;
        const return_point = rpx ? { x: parseFloat(rpx)||0, y: parseFloat(el('ml-rpy')?.value)||0,
            z: parseFloat(el('ml-rpz')?.value)||0, h: parseFloat(el('ml-rph')?.value)||0 } : null;
        const shx = el('ml-shx')?.value;
        const showroom = shx ? { x: parseFloat(shx)||0, y: parseFloat(el('ml-shy')?.value)||0,
            z: parseFloat(el('ml-shz')?.value)||0, h: parseFloat(el('ml-shh')?.value)||0 } : null;
        return {
            id: this._currentLocId || null,
            name: el('ml-name')?.value || '', coords, spawnpoints, return_point, showroom,
            blip_sprite: parseInt(el('ml-bsprite')?.value)||226,
            blip_color: parseInt(el('ml-bcolor')?.value)||3,
            blip_scale: parseFloat(el('ml-bscale')?.value)||0.7,
            ped_model: el('ml-ped')?.value||'s_m_m_autoshop_02',
            enabled: el('ml-enabled')?.checked !== false,
        };
    },

    placePoint(type) {
        this._savedForm = this._collectFormData();
        this.closeModal();
        document.getElementById('admin-app').classList.add('hidden');
        nui('adminStartPlacement', { type });
    },

    async handlePlacement(data) {
        document.getElementById('admin-app').classList.remove('hidden');
        await this.loadData();
        this.goTo('adm-locations');

        const form = this._savedForm || {};
        if (data.type === 'cancelled') {
            this.openLocationModal(form);
            return;
        }
        if (data.type === 'pnj') form.coords = data.coords;
        else if (data.type === 'return') form.return_point = data.coords;
        else if (data.type === 'showroom') form.showroom = data.coords;
        else if (data.type === 'spawn') form.spawnpoints = data.points || [];

        this.openLocationModal(form);
        this._savedForm = null;
    },

    async fillMyCoords(xId, yId, zId, hId) {
        const pos = await nui('adminGetPlayerCoords');
        if (!pos) { toast('Impossible de récupérer la position', 'error'); return; }
        document.getElementById(xId).value = pos.x; document.getElementById(yId).value = pos.y;
        document.getElementById(zId).value = pos.z; document.getElementById(hId).value = pos.h;
        toast('Position remplie', 'success');
    },

    async saveLocation(id) {
        const name = document.getElementById('ml-name').value.trim();
        if (!name) { toast('Le nom est requis', 'error'); return; }
        const coords = { x: parseFloat(document.getElementById('ml-cx').value)||0, y: parseFloat(document.getElementById('ml-cy').value)||0,
            z: parseFloat(document.getElementById('ml-cz').value)||0, h: parseFloat(document.getElementById('ml-ch').value)||0 };
        const spawnpoints = [];
        document.querySelectorAll('#ml-spawns-container .spawn-row').forEach(row => {
            spawnpoints.push({ x: parseFloat(row.querySelector('.sp-x').value)||0, y: parseFloat(row.querySelector('.sp-y').value)||0,
                z: parseFloat(row.querySelector('.sp-z').value)||0, h: parseFloat(row.querySelector('.sp-h').value)||0 });
        });
        if (!spawnpoints.length) { toast('Au moins un point de spawn requis', 'error'); return; }
        const rpx = document.getElementById('ml-rpx').value;
        const return_point = rpx ? { x: parseFloat(rpx)||0, y: parseFloat(document.getElementById('ml-rpy').value)||0,
            z: parseFloat(document.getElementById('ml-rpz').value)||0, h: parseFloat(document.getElementById('ml-rph').value)||0 } : null;
        const shx = document.getElementById('ml-shx').value;
        const showroom = shx ? { x: parseFloat(shx)||0, y: parseFloat(document.getElementById('ml-shy').value)||0,
            z: parseFloat(document.getElementById('ml-shz').value)||0, h: parseFloat(document.getElementById('ml-shh').value)||0 } : null;
        const data = { id, name, coords, spawnpoints, return_point, showroom,
            blip_sprite: parseInt(document.getElementById('ml-bsprite').value)||226,
            blip_color: parseInt(document.getElementById('ml-bcolor').value)||3,
            blip_scale: parseFloat(document.getElementById('ml-bscale').value)||0.7,
            ped_model: document.getElementById('ml-ped').value.trim()||'s_m_m_autoshop_02',
            enabled: document.getElementById('ml-enabled').checked };
        const r = await nui('adminSaveLocation', data);
        if (r?.ok) { toast('Point sauvegardé', 'success'); this.closeModal(); this.loadData(); }
        else toast(r?.msg || 'Erreur', 'error');
    },

    async deleteLocation(id) {
        const { action } = await nui('requestLocationDeleteChoice', {});
        if (action === 'cancel') return;
        const r = await nui('adminDeleteLocation', { id, action });
        if (r?.ok) {
            toast(action === 'delete' ? 'Point supprimé de la BDD' : 'Point désactivé', 'success');
            this.loadData();
        }
    },

    /* ---- Location vehicles ---- */
    async editLocVehicles(locationId) {
        const data = await nui('adminGetLocationVehicles', { locationId });
        if (!data) return;
        const loc = (admData?.locations || []).find(l => l.id === locationId);
        const locName = loc?.name || `Point #${locationId}`;
        const assigned = data.assigned || [], allVeh = data.allVehicles || [];
        const assignedIds = new Set(assigned.map(a => a.vehicle_id));
        const box = document.getElementById('modal-box');
        box.innerHTML = `
            <div class="modal-title"><i class="fa-solid fa-car"></i> Véhicules — ${locName}</div>
            <div class="admin-loc-veh-panel">
                <div class="admin-loc-list">
                    <div class="admin-loc-list-header"><h4><i class="fa-solid fa-check-circle" style="color:var(--green)"></i> Activés</h4><span class="badge">${assigned.length}</span></div>
                    <div class="admin-loc-list-body">${assigned.length ? assigned.map(a => `
                        <div class="admin-loc-veh-item">
                            <div class="admin-loc-veh-info"><img src="${vehImgSrc(a.model, a.image_url)}" onerror="this.style.display='none'" class="admin-loc-veh-thumb"><div><div class="admin-loc-veh-name">${a.label}</div><div class="admin-loc-veh-meta">${a.model} • ${a.category}</div></div></div>
                            <div class="admin-loc-veh-overrides">
                                <div class="admin-loc-veh-override"><label>Prix</label><input type="number" class="loc-override-price" data-vid="${a.vehicle_id}" value="${a.override_price??''}" placeholder="${a.global_price}"></div>
                                <div class="admin-loc-veh-override"><label>Caution</label><input type="number" class="loc-override-deposit" data-vid="${a.vehicle_id}" value="${a.override_deposit??''}" placeholder="${a.global_deposit}"></div>
                                <div class="admin-loc-veh-override"><label>Ordre</label><input type="number" class="loc-override-sort" data-vid="${a.vehicle_id}" value="${a.sort_order||0}" style="width:50px"></div>
                            </div>
                            <div class="admin-loc-veh-actions">
                                <button class="admin-btn" onclick="Admin.saveLocVehOverride(${locationId},${a.vehicle_id})"><i class="fa-solid fa-floppy-disk"></i></button>
                                <button class="admin-btn danger" onclick="Admin.removeLocVeh(${locationId},${a.vehicle_id})"><i class="fa-solid fa-xmark"></i></button>
                            </div>
                        </div>`).join('') : '<div class="admin-loc-empty"><i class="fa-solid fa-inbox"></i> Aucun véhicule assigné</div>'}</div>
                </div>
                <div class="admin-loc-list">
                    <div class="admin-loc-list-header"><h4><i class="fa-solid fa-warehouse" style="color:var(--text-muted)"></i> Bibliothèque</h4><span class="badge">${allVeh.filter(v=>!assignedIds.has(v.id)).length}</span></div>
                    <input type="text" id="loc-veh-search" class="admin-search" placeholder="Rechercher..." oninput="Admin.filterLocVeh()">
                    <div class="admin-loc-list-body" id="loc-veh-available">${allVeh.filter(v=>!assignedIds.has(v.id)).map(v => `
                        <div class="admin-loc-veh-item compact" data-search="${v.label.toLowerCase()} ${v.model.toLowerCase()} ${v.category.toLowerCase()}">
                            <div class="admin-loc-veh-info"><img src="${vehImgSrc(v.model,v.image_url)}" onerror="this.style.display='none'" class="admin-loc-veh-thumb"><div><div class="admin-loc-veh-name">${v.label}</div><div class="admin-loc-veh-meta">${v.model} • ${money(v.price_per_day)}/j</div></div></div>
                            <button class="admin-btn add-sm" onclick="Admin.addLocVeh(${locationId},${v.id})"><i class="fa-solid fa-plus"></i></button>
                        </div>`).join('')}</div>
                </div>
            </div>
            <div class="modal-actions"><button class="modal-btn" onclick="Admin.closeModal()">Fermer</button></div>`;
        document.getElementById('modal-overlay').classList.remove('hidden');
    },

    filterLocVeh() {
        const q = (document.getElementById('loc-veh-search')?.value || '').toLowerCase();
        document.querySelectorAll('#loc-veh-available .admin-loc-veh-item').forEach(el => {
            el.style.display = (!q || el.dataset.search.includes(q)) ? '' : 'none';
        });
    },

    async addLocVeh(locId, vehId) {
        const r = await nui('adminSetLocationVehicle', { locationId: locId, vehicleId: vehId, enabled: true });
        if (r?.ok) { toast('Véhicule ajouté', 'success'); this.editLocVehicles(locId); }
    },

    async removeLocVeh(locId, vehId) {
        const r = await nui('adminRemoveLocationVehicle', { locationId: locId, vehicleId: vehId });
        if (r?.ok) { toast('Véhicule retiré', 'success'); this.editLocVehicles(locId); }
    },

    async saveLocVehOverride(locId, vehId) {
        const p = document.querySelector(`.loc-override-price[data-vid="${vehId}"]`);
        const d = document.querySelector(`.loc-override-deposit[data-vid="${vehId}"]`);
        const s = document.querySelector(`.loc-override-sort[data-vid="${vehId}"]`);
        const r = await nui('adminSetLocationVehicle', {
            locationId: locId, vehicleId: vehId, enabled: true,
            overridePrice: p?.value ? parseInt(p.value) : null,
            overrideDeposit: d?.value ? parseInt(d.value) : null,
            sortOrder: parseInt(s?.value) || 0,
        });
        if (r?.ok) toast('Overrides sauvegardés', 'success');
        else toast('Erreur', 'error');
    },
};

/* ================================================================
   HUD temps location — position (KVP Lua) / mode placement /uiloc
   ================================================================ */
const RentalHud = (function () {
    /** @type {{ cx: number; cy: number }} centre du widget (% viewport), ancrage translate(-50%,-50%) */
    let pos = { cx: 93, cy: 94 };
    let placementActive = false;
    let posSnapshotOnPlacementEnter = null;
    let lastGameHudPayload = null;
    /** @type {null | { offX:number;offY:number; w:number; h:number }} */
    let dragState = null;
    let hudDragHooked = false;

    function clampPct(v) {
        return Math.min(98, Math.max(2, v));
    }

    function applyPos(data) {
        if (!data || typeof data.cx !== 'number' || typeof data.cy !== 'number') return;
        pos = { cx: clampPct(data.cx), cy: clampPct(data.cy) };
        const root = document.getElementById('rental-timer-hud');
        if (!root) return;
        root.style.bottom = 'auto';
        root.style.right = 'auto';
        root.style.left = `${pos.cx}%`;
        root.style.top = `${pos.cy}%`;
        root.style.transform = 'translate(-50%, -50%)';
    }

    function resetCornerLayoutCss() {
        const root = document.getElementById('rental-timer-hud');
        if (!root) return;
        root.style.bottom = '';
        root.style.right = '';
        root.style.left = '';
        root.style.top = '';
        root.style.transform = '';
        pos = { cx: 93, cy: 94 };
    }

    function applyHudFromPayload(data, forceShow) {
        const root = document.getElementById('rental-timer-hud');
        const labEl = document.getElementById('rental-timer-hud-label');
        const valEl = document.getElementById('rental-timer-hud-value');
        if (!root || !labEl || !valEl || !data) return;
        const vis = forceShow === true ? true : !!data.visible;
        if (!vis) {
            root.classList.add('hidden');
            root.setAttribute('aria-hidden', 'true');
            root.classList.remove('rental-timer-hud-expired');
            return;
        }
        labEl.textContent = data.label || '';
        valEl.textContent = data.value || '';
        root.classList.remove('hidden');
        root.setAttribute('aria-hidden', 'false');
        root.classList.toggle('rental-timer-hud-expired', !!data.expired);
    }

    function showPlacementBanner(hintHtml) {
        const layer = document.getElementById('rental-timer-hud-place-layer');
        const hintEl = document.getElementById('rental-timer-hud-place-hint');
        if (!layer || !hintEl) return;
        hintEl.textContent = hintHtml || '';
        layer.classList.remove('hidden');
        layer.setAttribute('aria-hidden', 'false');
        document.body.classList.add('timer-hud-placing');
    }

    function hidePlacementBanner() {
        const layer = document.getElementById('rental-timer-hud-place-layer');
        if (layer) {
            layer.classList.add('hidden');
            layer.setAttribute('aria-hidden', 'true');
        }
        document.body.classList.remove('timer-hud-placing');
    }

    async function teardownPlacement(saveCoords) {
        placementActive = false;
        dragState = null;
        hidePlacementBanner();
        window.removeEventListener('mousemove', onDragMove);
        window.removeEventListener('mouseup', onDragEnd);

        if (!saveCoords && posSnapshotOnPlacementEnter) {
            applyPos(posSnapshotOnPlacementEnter);
        }
        posSnapshotOnPlacementEnter = null;

        if (lastGameHudPayload) {
            applyHudFromPayload(lastGameHudPayload, lastGameHudPayload.visible);
        } else {
            applyHudFromPayload({ visible: false });
        }

        await nui('finishTimerHudPlacement').catch(() => null);
    }

    function pxToPct(centerXpx, centerYpx) {
        const iw = window.innerWidth || 1920;
        const ih = window.innerHeight || 1080;
        return {
            cx: clampPct((centerXpx / iw) * 100),
            cy: clampPct((centerYpx / ih) * 100),
        };
    }

    function clientCenterFromTopLeft(left, top, w, h) {
        const pad = 4;
        const iw = window.innerWidth;
        const ih = window.innerHeight;
        let L = Math.max(pad, Math.min(left, iw - w - pad));
        let T = Math.max(pad, Math.min(top, ih - h - pad));
        return pxToPct(L + w / 2, T + h / 2);
    }

    function onDragMove(e) {
        if (!dragState || !placementActive) return;
        const nw = dragState.w;
        const nh = dragState.h;
        const nx = e.clientX - dragState.offX;
        const ny = e.clientY - dragState.offY;
        applyPos(clientCenterFromTopLeft(nx, ny, nw, nh));
        e.preventDefault();
    }

    function onDragEnd() {
        dragState = null;
        window.removeEventListener('mousemove', onDragMove);
        window.removeEventListener('mouseup', onDragEnd);
    }

    function bindHudDragOnce() {
        const root = document.getElementById('rental-timer-hud');
        if (!root || hudDragHooked) return;
        hudDragHooked = true;
        root.addEventListener('mousedown', onHudMouseDown);
    }

    function onHudMouseDown(e) {
        if (!placementActive) return;
        const root = document.getElementById('rental-timer-hud');
        if (!root || !root.contains(e.target)) return;
        const r = root.getBoundingClientRect();
        dragState = {
            offX: e.clientX - r.left,
            offY: e.clientY - r.top,
            w: r.width,
            h: r.height,
        };
        window.addEventListener('mousemove', onDragMove);
        window.addEventListener('mouseup', onDragEnd);
        e.preventDefault();
        e.stopPropagation();
    }

    async function placementConfirm(e) {
        if (e) e.preventDefault();
        await nui('saveTimerHudPos', pos).catch(() => null);
        await teardownPlacement(true);
    }

    async function placementCancel(e) {
        if (e) e.preventDefault();
        await teardownPlacement(false);
    }

    return {
        isPlacing() {
            return placementActive;
        },
        onTimerHudPos(data) {
            if (!data || typeof data.cx !== 'number' || typeof data.cy !== 'number') {
                resetCornerLayoutCss();
                return;
            }
            applyPos(data);
        },
        /** message rentalTimerHud */
        handleGameTimer(data) {
            lastGameHudPayload = data ? { ...data } : null;
            if (placementActive) return;
            applyHudFromPayload(data);
        },
        /** message rentalTimerHudPlacement */
        startPlacement(data) {
            if (!data || !data.active) {
                placementActive = false;
                hidePlacementBanner();
                return;
            }
            posSnapshotOnPlacementEnter = { ...pos };
            placementActive = true;
            showPlacementBanner(data.hint || '');

            const root = document.getElementById('rental-timer-hud');
            if (!root) return;
            bindHudDragOnce();
            applyHudFromPayload(
                {
                    visible: true,
                    label: data.demoLabel || __('ui_timer_label'),
                    value: data.demoValue || '—',
                    expired: false,
                },
                true
            );
            applyPos(pos);
        },

        placementConfirm,
        placementCancel,

        hydrateFromLuaOnLoad(posData) {
            if (posData && typeof posData.cx === 'number') applyPos(posData);
            else resetCornerLayoutCss();
        },
    };
})();

/* ================================================================
   NUI Listeners
   ================================================================ */
window.addEventListener('message', (e) => {
    const { action, data } = e.data;
    if (!action) return;

    switch (action) {
        case 'bootstrap':
            if (data) __PR_BOOT = data;
            break;
        case 'applyTheme':
            applyTheme(data);
            break;
        case 'open':
            if (data.bootstrap) __PR_BOOT = data.bootstrap;
            App.open(data.page, data.extra);
            break;
        case 'openAdmin':
            Admin.open();
            break;
        case 'placementResult':
            Admin.handlePlacement(data);
            break;
        case 'showContractPaper':
            showContractPaper(data);
            break;
        case 'close':
            document.getElementById('app').classList.add('hidden');
            document.getElementById('admin-app').classList.add('hidden');
            break;
        case 'rentalTimerHud':
            RentalHud.handleGameTimer(data);
            break;
        case 'rentalTimerHudPos':
            RentalHud.onTimerHudPos(data);
            break;
        case 'rentalTimerHudPlacement':
            RentalHud.startPlacement(data);
            break;
    }
});

window.addEventListener('keydown', (e) => {
    if (RentalHud.isPlacing()) {
        if (e.key === 'Escape') {
            e.preventDefault();
            RentalHud.placementCancel(e);
            return;
        }
        if (e.key === 'Enter') {
            e.preventDefault();
            RentalHud.placementConfirm(e);
            return;
        }
    }

    if (e.key === 'Escape') {
        const co = document.getElementById('contract-overlay');
        if (co && co.classList.contains('cp-show')) {
            closeContractPaper();
            return;
        }
        const modal = document.getElementById('modal-overlay');
        if (!modal.classList.contains('hidden')) {
            modal.classList.add('hidden');
            return;
        }
        nui('showroomClose');
        if (!document.getElementById('admin-app').classList.contains('hidden')) {
            Admin.close();
        } else if (!document.getElementById('app').classList.contains('hidden')) {
            App.close();
        }
    }
});

/* Nav clicks — Rental UI */
document.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', () => { const page = link.dataset.page; if (page) App.goTo(page); });
});

/* Nav clicks — Admin UI */
document.querySelectorAll('.adm-link').forEach(link => {
    link.addEventListener('click', () => { const sec = link.dataset.section; if (sec) Admin.goTo(sec); });
});
