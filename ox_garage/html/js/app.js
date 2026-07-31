(() => {
  const app = document.getElementById('app');
  const listEl = document.getElementById('vehicleList');
  const emptyEl = document.getElementById('emptyState');
  const searchInput = document.getElementById('searchInput');

  const state = {
    garageId: null,
    garageLabel: '',
    garageType: 'car',
    location: '',
    vehicles: [],
    selected: null,
    privateOwned: false,
    kind: 'public',
    mode: 'personal', // personal | job
    job: null,
    locales: {},
  };

  function nui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
  }

  function GetParentResourceName() {
    if (window.GetParentResourceName) return window.GetParentResourceName();
    return 'ox_garage';
  }

  function applyTheme(theme = {}) {
    const root = document.documentElement;
    const map = {
      bg: '--bg',
      panel: '--panel',
      panelBorder: '--panel-border',
      accent: '--accent',
      accentSoft: '--accent-soft',
      text: '--text',
      muted: '--muted',
      success: '--success',
      danger: '--danger',
      warning: '--warning',
      blur: '--blur',
      radius: '--radius',
      fontDisplay: '--font-display',
      fontBody: '--font-body',
    };
    Object.entries(map).forEach(([k, css]) => {
      if (theme[k]) root.style.setProperty(css, theme[k]);
    });
  }

  function pct(n) {
    n = Math.max(0, Math.min(100, Number(n) || 0));
    return Math.round(n);
  }

  function artForType(type, modelClass) {
    const t = (type || '').toLowerCase();
    if (t === 'aircraft' || t === 'heli' || modelClass === 15 || modelClass === 16) return 'heli';
    if (t === 'boat' || modelClass === 14) return 'boat';
    return 'car';
  }

  function setArt(kind) {
    document.getElementById('artCar').classList.toggle('hidden', kind !== 'car');
    document.getElementById('artHeli').classList.toggle('hidden', kind !== 'heli');
    document.getElementById('artBoat').classList.toggle('hidden', kind !== 'boat');
  }

  function setBar(id, value) {
    const v = pct(value);
    document.getElementById(id).style.width = `${v}%`;
    document.getElementById(`${id}Val`).textContent = `${v}%`;
  }

  function filtered() {
    const q = (searchInput.value || '').trim().toLowerCase();
    if (!q) return state.vehicles;
    return state.vehicles.filter((v) => {
      const blob = `${v.name || ''} ${v.modelName || ''} ${v.plate || ''}`.toLowerCase();
      return blob.includes(q);
    });
  }

  function renderList() {
    const items = filtered();
    listEl.innerHTML = '';
    emptyEl.classList.toggle('hidden', items.length > 0);
    document.getElementById('vehicleCount').textContent = `${state.vehicles.length}`;

    items.forEach((v, i) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = `v-card${state.selected && state.selected.plate === v.plate ? ' active' : ''}`;
      btn.style.animationDelay = `${Math.min(i, 10) * 30}ms`;
      btn.innerHTML = `
        <span class="v-card__name">${v.name || 'Véhicule'}</span>
        <span class="v-card__status ${v.stored ? 'is-stored' : 'is-out'}">${v.stored ? 'Rangé' : 'Sorti'}</span>
        <span class="v-card__meta">${v.plate || '—'} · ${v.modelName || '—'} · ⛽ ${pct(v.fuel)}%</span>
      `;
      btn.addEventListener('click', () => selectVehicle(v));
      listEl.appendChild(btn);
    });
  }

  function selectVehicle(v) {
    state.selected = v;
    renderList();

    const stored = !!v.stored;
    document.getElementById('infoName').textContent = v.name || '—';
    document.getElementById('infoModel').textContent = v.modelName || String(v.model || '—');
    document.getElementById('infoPlate').textContent = v.plate || '—';
    document.getElementById('infoLocation').textContent = state.location || state.garageLabel || '—';
    document.getElementById('previewPlate').textContent = (v.plate || '————').toUpperCase();

    const st = document.getElementById('infoStatus');
    st.textContent = stored ? 'Rangé' : 'Sorti';
    st.className = `status ${stored ? 'is-stored' : 'is-out'}`;

    setBar('infoEngine', v.engine);
    setBar('infoBody', v.body);
    setBar('infoFuel', v.fuel);
    setArt(artForType(state.garageType, v.class));

    const take = document.getElementById('btnTakeOut');
    take.disabled = !stored;
    take.querySelector('span').textContent = stored ? 'Sortir' : 'Déjà sorti';

    nui('garageSelect', { plate: v.plate, model: v.model, props: v.props || null });
  }

  function openUI(payload) {
    state.garageId = payload.garageId;
    state.garageLabel = payload.label || 'Garage';
    state.garageType = payload.type || 'car';
    state.location = payload.location || payload.label || '';
    state.vehicles = payload.vehicles || [];
    state.kind = payload.kind || 'public';
    state.privateOwned = !!payload.privateOwned;
    state.mode = payload.mode || 'personal';
    state.job = payload.job || null;
    state.locales = payload.locales || {};
    state.selected = null;

    applyTheme(payload.theme || {});
    if (payload.logo) document.getElementById('logo').src = payload.logo;
    document.getElementById('brandName').textContent = payload.brand || 'OX GARAGE';
    document.getElementById('garageTitle').textContent = state.garageLabel;
    document.getElementById('garageType').textContent =
      state.garageType === 'aircraft' ? 'Hélicos / avions' :
      state.garageType === 'boat' ? 'Bateaux' : 'Véhicules';

    const manage = document.getElementById('btnManage');
    manage.classList.toggle('hidden', state.kind !== 'private');

    searchInput.value = '';
    app.classList.remove('hidden');
    app.setAttribute('aria-hidden', 'false');
    renderList();

    const first = state.vehicles.find((v) => v.stored) || state.vehicles[0];
    if (first) selectVehicle(first);
    else {
      document.getElementById('infoName').textContent = '—';
      document.getElementById('btnTakeOut').disabled = true;
      setArt(artForType(state.garageType));
    }
  }

  function closeUI() {
    app.classList.add('hidden');
    app.setAttribute('aria-hidden', 'true');
    nui('garageClose', {});
  }

  document.getElementById('btnClose').addEventListener('click', closeUI);
  document.getElementById('btnTakeOut').addEventListener('click', () => {
    if (!state.selected || !state.selected.stored) return;
    nui('garageTakeOut', {
      garageId: state.garageId,
      plate: state.selected.plate,
      isPersonal: !!state.selected.isPersonal,
      mode: state.mode,
      job: state.job,
    });
  });
  document.getElementById('btnManage').addEventListener('click', () => {
    nui('garageManage', { garageId: state.garageId });
  });
  searchInput.addEventListener('input', renderList);

  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !app.classList.contains('hidden')) closeUI();
  });

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') openUI(data);
    if (data.action === 'close') {
      app.classList.add('hidden');
      app.setAttribute('aria-hidden', 'true');
    }
    if (data.action === 'theme') applyTheme(data.theme || {});
  });
})();
