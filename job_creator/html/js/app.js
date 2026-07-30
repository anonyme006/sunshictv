(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'job_creator';

  const state = {
    jobs: {},
    markers: {},
    vehicles: {},
    outfits: {},
    shops: {},
    crafts: {},
    markerTypes: [],
    permissions: [],
    defaultActions: [],
    oxGarages: [],
    useOxGarage: false,
    selectedJob: null,
    playerCoords: null,
    playerMenu: null,
  };

  const $ = (sel, el = document) => el.querySelector(sel);
  const $$ = (sel, el = document) => [...el.querySelectorAll(sel)];

  function post(name, data) {
    return fetch(`https://${res}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({}));
  }

  function jobsArray() {
    return Object.values(state.jobs || {}).sort((a, b) => (a.label || '').localeCompare(b.label || ''));
  }

  function fillJobSelects() {
    const opts = jobsArray().map((j) => `<option value="${j.name}">${j.label} (${j.name})</option>`).join('');
    ['jobFilter', 'gradeJobSelect', 'markerJobSelect', 'vehJobSelect', 'shopJobSelect', 'craftJobSelect', 'toolsJobSelect'].forEach((id) => {
      const el = document.getElementById(id);
      if (!el) return;
      const cur = el.value;
      if (id === 'jobFilter') {
        el.innerHTML = `<option value="">Tous les jobs</option>` + opts;
      } else {
        el.innerHTML = opts;
      }
      if (cur) el.value = cur;
    });
  }

  function currentFilter() {
    return $('#jobFilter')?.value || '';
  }

  /* ---------- TABS ---------- */
  $$('.nav__btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      $$('.nav__btn').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      const tab = btn.dataset.tab;
      $$('.tab').forEach((t) => t.classList.remove('active'));
      $(`#tab-${tab}`)?.classList.add('active');
      $('#tabTitle').textContent = btn.textContent;
      renderAll();
    });
  });

  $('#btnAdminClose')?.addEventListener('click', () => post('adminClose'));
  $('#btnReload')?.addEventListener('click', () => post('adminReload'));
  $('#jobFilter')?.addEventListener('change', () => renderAll());

  /* ---------- ACTIONS / PERMS CHECKS ---------- */
  function buildActionChecks(selected = {}) {
    const box = $('#actionsChecks');
    if (!box) return;
    box.innerHTML = (state.defaultActions || []).map((a) => `
      <label><input type="checkbox" name="action_${a.id}" ${selected[a.id] ? 'checked' : ''}/> ${a.label}</label>
    `).join('');
  }

  function buildPermChecks(selected = {}) {
    const box = $('#permChecks');
    if (!box) return;
    const all = selected['*'] === true;
    box.innerHTML = `
      <label><input type="checkbox" name="perm_*" ${all ? 'checked' : ''}/> Toutes (*)</label>
      ${(state.permissions || []).map((p) => `
        <label><input type="checkbox" name="perm_${p.id}" ${selected[p.id] || all ? 'checked' : ''}/> ${p.label}</label>
      `).join('')}
    `;
  }

  function readActions() {
    const out = {};
    (state.defaultActions || []).forEach((a) => {
      const el = $(`input[name="action_${a.id}"]`);
      if (el?.checked) out[a.id] = true;
    });
    return out;
  }

  function readPerms() {
    const out = {};
    if ($('input[name="perm_*"]')?.checked) {
      out['*'] = true;
      return out;
    }
    (state.permissions || []).forEach((p) => {
      if ($(`input[name="perm_${p.id}"]`)?.checked) out[p.id] = true;
    });
    return out;
  }

  /* ---------- RENDER LISTS ---------- */
  function renderJobs() {
    const list = $('#jobsList');
    if (!list) return;
    const filter = currentFilter();
    list.innerHTML = jobsArray()
      .filter((j) => !filter || j.name === filter)
      .map((j) => `
        <div class="list-item" data-job="${j.name}">
          <div>
            <div class="list-item__title">${j.label}</div>
            <div class="list-item__meta">${j.name} · ${j.type || 'civil'} · ${(j.grades || []).length} grades</div>
          </div>
          <div class="list-item__actions">
            <button class="btn btn--soft btn--sm" data-edit-job="${j.name}">Éditer</button>
            <button class="btn btn--danger btn--sm" data-del-job="${j.name}">Suppr.</button>
          </div>
        </div>
      `).join('') || '<p class="muted">Aucun job</p>';

    list.querySelectorAll('[data-edit-job]').forEach((b) => b.addEventListener('click', (e) => {
      e.stopPropagation();
      loadJobForm(b.dataset.editJob);
    }));
    list.querySelectorAll('[data-del-job]').forEach((b) => b.addEventListener('click', (e) => {
      e.stopPropagation();
      if (confirm('Supprimer ce job et tous ses markers ?')) {
        post('adminDeleteJob', { name: b.dataset.delJob });
      }
    }));
  }

  function loadJobForm(name) {
    const j = state.jobs[name];
    if (!j) return;
    const f = $('#jobForm');
    f.editing.value = '1';
    f.name.value = j.name;
    f.name.readOnly = true;
    f.label.value = j.label;
    f.type.value = j.type || 'civil';
    f.whitelisted.checked = j.whitelisted !== false;
    f.blip_sprite.value = j.blip?.sprite || 0;
    f.blip_color.value = j.blip?.color || 0;
    f.blip_scale.value = j.blip?.scale || 0.8;
    if (j.blip?.coords) {
      f.blip_coords.value = `${j.blip.coords.x},${j.blip.coords.y},${j.blip.coords.z}`;
    } else {
      f.blip_coords.value = '';
    }
    $('#jobFormTitle').textContent = 'Éditer : ' + j.label;
    buildActionChecks(j.actions || {});
  }

  $('#btnNewJob')?.addEventListener('click', () => {
    const f = $('#jobForm');
    f.reset();
    f.editing.value = '0';
    f.name.readOnly = false;
    f.whitelisted.checked = true;
    $('#jobFormTitle').textContent = 'Créer un job';
    buildActionChecks({});
  });

  $('#btnJobCoords')?.addEventListener('click', async () => {
    const c = await post('adminGetCoords');
    if (c?.x != null) {
      $('#jobForm').blip_coords.value = `${c.x},${c.y},${c.z}`;
    }
  });

  $('#jobForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const f = e.target;
    const coordsStr = f.blip_coords.value.trim();
    let blipCoords = null;
    if (coordsStr) {
      const [x, y, z] = coordsStr.split(',').map(Number);
      blipCoords = { x, y, z };
    }
    const payload = {
      name: f.name.value,
      label: f.label.value,
      type: f.type.value,
      whitelisted: f.whitelisted.checked,
      enabled: true,
      actions: readActions(),
      blip: {
        sprite: Number(f.blip_sprite.value) || 0,
        color: Number(f.blip_color.value) || 0,
        scale: Number(f.blip_scale.value) || 0.8,
        coords: blipCoords,
      },
    };
    // Keep existing grades on update
    if (state.jobs[payload.name]) {
      payload.grades = state.jobs[payload.name].grades;
    }
    post('adminSaveJob', payload);
  });

  function renderGrades() {
    const list = $('#gradesList');
    if (!list) return;
    const filter = currentFilter();
    const rows = [];
    jobsArray().forEach((j) => {
      if (filter && j.name !== filter) return;
      (j.grades || []).forEach((g) => {
        rows.push({ ...g, job_name: j.name, job_label: j.label });
      });
    });
    list.innerHTML = rows.map((g) => `
      <div class="list-item">
        <div>
          <div class="list-item__title">${g.label} <span class="muted">#${g.grade}</span></div>
          <div class="list-item__meta">${g.job_label} · ${g.name} · ${g.salary}$</div>
        </div>
        <div class="list-item__actions">
          <button class="btn btn--soft btn--sm" data-edit-grade='${JSON.stringify(g).replace(/'/g, '&#39;')}'>Éditer</button>
          <button class="btn btn--danger btn--sm" data-del-grade="${g.id}">Suppr.</button>
        </div>
      </div>
    `).join('') || '<p class="muted">Aucun grade</p>';

    list.querySelectorAll('[data-edit-grade]').forEach((b) => {
      b.addEventListener('click', () => {
        const g = JSON.parse(b.getAttribute('data-edit-grade'));
        const f = $('#gradeForm');
        f.id.value = g.id || '';
        f.job_name.value = g.job_name;
        f.grade.value = g.grade;
        f.name.value = g.name;
        f.label.value = g.label;
        f.salary.value = g.salary || 0;
        buildPermChecks(g.permissions || {});
      });
    });
    list.querySelectorAll('[data-del-grade]').forEach((b) => {
      b.addEventListener('click', () => post('adminDeleteGrade', { id: Number(b.dataset.delGrade) }));
    });
  }

  $('#btnNewGrade')?.addEventListener('click', () => {
    const f = $('#gradeForm');
    f.reset();
    f.id.value = '';
    if (currentFilter()) f.job_name.value = currentFilter();
    buildPermChecks({ stash: true, garage: true, cloakroom: true });
  });

  $('#gradeForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const f = e.target;
    post('adminSaveGrade', {
      id: f.id.value ? Number(f.id.value) : null,
      job_name: f.job_name.value,
      grade: Number(f.grade.value),
      name: f.name.value,
      label: f.label.value,
      salary: Number(f.salary.value) || 0,
      permissions: readPerms(),
    });
  });

  /* ---------- MARKERS ---------- */
  const MARKER_DATA_FIELDS = {
    harvest: [
      { name: 'item', label: 'Item récolté', placeholder: 'wood' },
      { name: 'count', label: 'Quantité', placeholder: '1' },
      { name: 'label', label: 'Label item', placeholder: 'Bois' },
    ],
    process: [
      { name: 'need_item', label: 'Item requis', placeholder: 'wood' },
      { name: 'need_count', label: 'Qté requise', placeholder: '2' },
      { name: 'give_item', label: 'Item obtenu', placeholder: 'plank' },
      { name: 'give_count', label: 'Qté obtenue', placeholder: '1' },
    ],
    sell: [
      { name: 'item', label: 'Item à vendre', placeholder: 'plank' },
      { name: 'count', label: 'Quantité', placeholder: '1' },
      { name: 'price', label: 'Prix', placeholder: '100' },
      { name: 'society_percent', label: '% société', placeholder: '10' },
      { name: 'black_money', label: 'Argent sale (true/false)', placeholder: 'false' },
    ],
    teleport: [
      { name: 'destination', label: 'Destination x,y,z,w', placeholder: '0,0,0,0' },
    ],
    wash: [
      { name: 'fee_percent', label: 'Frais %', placeholder: '30' },
    ],
    garage: [
      {
        name: 'ox_mode',
        label: 'Mode ox_garage',
        type: 'select',
        options: [
          { value: 'job_fleet', label: 'Flotte entreprise (ox_garage)' },
          { value: 'ox_garage', label: 'Garage ox_garage perso / public / privé' },
        ],
      },
      { name: 'ox_garage_id', label: 'Garage ox_garage', type: 'ox_garage_select' },
      { name: 'register_job_garage', label: 'Créer emplacement ox_garage job ici', type: 'select', options: [
        { value: 'false', label: 'Non' },
        { value: 'true', label: 'Oui (AddJobGarage à la position)' },
      ]},
      { name: 'spawn', label: 'Spawn véhicule x,y,z,w', placeholder: 'utiliser bouton coords' },
      { name: 'radius', label: 'Rayon rangement', placeholder: '8' },
    ],
    garage_store: [
      {
        name: 'ox_mode',
        label: 'Mode ox_garage',
        type: 'select',
        options: [
          { value: 'job_fleet', label: 'Flotte entreprise (ox_garage)' },
          { value: 'ox_garage', label: 'Garage ox_garage perso / public / privé' },
        ],
      },
      { name: 'ox_garage_id', label: 'Garage ox_garage', type: 'ox_garage_select' },
      { name: 'radius', label: 'Rayon rangement', placeholder: '8' },
    ],
  };

  function oxGarageOptionsHtml(selected) {
    const list = state.oxGarages || [];
    const opts = [`<option value="">— Aucun / marker ID —</option>`]
      .concat(list.map((g) => {
        const kind = g.kind || 'public';
        const job = g.job ? ` · ${g.job}` : '';
        const src = g.source === 'dynamic' ? 'dyn' : 'cfg';
        const label = `${g.label} (${g.id}) [${kind}/${src}${job}]`;
        const sel = String(selected || '') === String(g.id) ? ' selected' : '';
        return `<option value="${g.id}"${sel}>${label}</option>`;
      }));
    return opts.join('');
  }

  function renderMarkerDataFields(type, data = {}) {
    const box = $('#markerDataInputs');
    const fields = MARKER_DATA_FIELDS[type] || [];
    if (!fields.length) {
      box.innerHTML = '<p class="muted">Pas de données spécifiques pour ce type.</p>';
      return;
    }
    box.innerHTML = fields.map((f) => {
      let val = data[f.name];
      if (f.name === 'destination' || f.name === 'spawn') {
        if (val && typeof val === 'object') {
          val = [val.x, val.y, val.z, val.w || 0].join(',');
        }
      }
      if (f.name === 'black_money') val = val === true ? 'true' : (val === false ? 'false' : (val || 'false'));
      if (f.name === 'register_job_garage') val = (val === true || val === 'true') ? 'true' : 'false';
      if (f.name === 'ox_mode') val = val || 'job_fleet';

      if (f.type === 'ox_garage_select') {
        return `<label>${f.label}
          <select class="input" name="data_${f.name}">${oxGarageOptionsHtml(val)}</select>
          <button type="button" class="btn btn--soft btn--sm" id="btnRefreshOxGarages" style="margin-top:6px">Rafraîchir liste ox_garage</button>
        </label>`;
      }
      if (f.type === 'select') {
        const options = (f.options || []).map((o) => {
          const sel = String(val ?? '') === String(o.value) ? ' selected' : '';
          return `<option value="${o.value}"${sel}>${o.label}</option>`;
        }).join('');
        return `<label>${f.label}<select class="input" name="data_${f.name}">${options}</select></label>`;
      }
      return `<label>${f.label}<input class="input" name="data_${f.name}" value="${val ?? ''}" placeholder="${f.placeholder || ''}" /></label>`;
    }).join('');

    $('#btnRefreshOxGarages')?.addEventListener('click', () => {
      post('adminGetOxGarages', {});
    });
  }

  function parseMarkerData(type, form) {
    const fields = MARKER_DATA_FIELDS[type] || [];
    const data = {};
    fields.forEach((f) => {
      const el = form[`data_${f.name}`];
      const raw = el?.value?.trim?.() ?? el?.value;
      if (raw === undefined || raw === null || raw === '') return;
      if (f.name === 'destination' || f.name === 'spawn') {
        const p = String(raw).split(',').map(Number);
        data[f.name] = { x: p[0], y: p[1], z: p[2], w: p[3] || 0 };
      } else if (f.name === 'black_money' || f.name === 'register_job_garage') {
        data[f.name] = String(raw) === 'true';
      } else if (['count', 'need_count', 'give_count', 'price', 'society_percent', 'fee_percent', 'radius'].includes(f.name)) {
        data[f.name] = Number(raw);
      } else {
        data[f.name] = raw;
      }
    });
    return data;
  }

  function initMarkerTypes() {
    const sel = $('#markerTypeSelect');
    if (!sel) return;
    sel.innerHTML = (state.markerTypes || []).map((t) => `<option value="${t.id}">${t.label}</option>`).join('');
    sel.onchange = () => renderMarkerDataFields(sel.value, {});
  }

  function renderMarkers() {
    const list = $('#markersList');
    if (!list) return;
    const filter = currentFilter();
    const rows = Object.values(state.markers || {}).filter((m) => !filter || m.job_name === filter);
    list.innerHTML = rows.map((m) => `
      <div class="list-item">
        <div>
          <div class="list-item__title">${m.label}</div>
          <div class="list-item__meta">${m.job_name} · ${m.type} · grade≥${m.min_grade || 0} · #${m.id}</div>
        </div>
        <div class="list-item__actions">
          <button class="btn btn--soft btn--sm" data-edit-marker="${m.id}">Éditer</button>
          <button class="btn btn--danger btn--sm" data-del-marker="${m.id}">Suppr.</button>
        </div>
      </div>
    `).join('') || '<p class="muted">Aucun marker</p>';

    list.querySelectorAll('[data-edit-marker]').forEach((b) => {
      b.addEventListener('click', () => {
        const m = state.markers[b.dataset.editMarker] || state.markers[String(b.dataset.editMarker)];
        if (!m) return;
        const f = $('#markerForm');
        f.id.value = m.id;
        f.job_name.value = m.job_name;
        f.type.value = m.type;
        f.label.value = m.label;
        f.min_grade.value = m.min_grade || 0;
        f.public.checked = !!m.public;
        f.blip_enabled.checked = !!m.blip_enabled;
        f.coords.value = `${m.coords.x},${m.coords.y},${m.coords.z}`;
        f.marker_type.value = m.marker_type || 1;
        f.blip_sprite.value = m.blip_sprite || 1;
        f.blip_color.value = m.blip_color || 0;
        renderMarkerDataFields(m.type, m.data || {});
      });
    });
    list.querySelectorAll('[data-del-marker]').forEach((b) => {
      b.addEventListener('click', () => post('adminDeleteMarker', { id: Number(b.dataset.delMarker) }));
    });
  }

  $('#btnNewMarker')?.addEventListener('click', async () => {
    const f = $('#markerForm');
    f.reset();
    f.id.value = '';
    if (currentFilter()) f.job_name.value = currentFilter();
    f.type.value = 'boss';
    f.label.value = 'Menu Patron';
    const c = await post('adminGetCoords');
    if (c?.x != null) f.coords.value = `${c.x},${c.y},${c.z}`;
    renderMarkerDataFields('boss', {});
  });

  $('#btnMarkerCoords')?.addEventListener('click', async () => {
    const c = await post('adminGetCoords');
    if (c?.x != null) {
      $('#markerForm').coords.value = `${c.x},${c.y},${c.z}`;
      const spawnInput = $('input[name="data_spawn"]');
      if (spawnInput) spawnInput.value = `${c.x},${c.y},${c.z},${c.w || 0}`;
      const destInput = $('input[name="data_destination"]');
      if (destInput) destInput.value = `${c.x},${c.y},${c.z},${c.w || 0}`;
    }
  });

  $('#markerForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const f = e.target;
    const [x, y, z] = f.coords.value.split(',').map(Number);
    post('adminSaveMarker', {
      id: f.id.value ? Number(f.id.value) : null,
      job_name: f.job_name.value,
      type: f.type.value,
      label: f.label.value,
      min_grade: Number(f.min_grade.value) || 0,
      public: f.public.checked,
      blip_enabled: f.blip_enabled.checked,
      coords: { x, y, z },
      marker_type: Number(f.marker_type.value) || 1,
      blip_sprite: Number(f.blip_sprite.value) || 1,
      blip_color: Number(f.blip_color.value) || 0,
      data: parseMarkerData(f.type.value, f),
    });
  });

  /* ---------- VEHICLES / SHOPS / CRAFTS ---------- */
  function renderVehicles() {
    const list = $('#vehiclesList');
    if (!list) return;
    const filter = currentFilter();
    const rows = Object.values(state.vehicles || {}).filter((v) => !filter || v.job_name === filter);
    list.innerHTML = rows.map((v) => `
      <div class="list-item">
        <div>
          <div class="list-item__title">${v.label}</div>
          <div class="list-item__meta">${v.job_name} · ${v.model} · grade≥${v.min_grade || 0}</div>
        </div>
        <div class="list-item__actions">
          <button class="btn btn--soft btn--sm" data-edit-veh="${v.id}">Éditer</button>
          <button class="btn btn--danger btn--sm" data-del-veh="${v.id}">Suppr.</button>
        </div>
      </div>
    `).join('') || '<p class="muted">Aucun véhicule</p>';

    list.querySelectorAll('[data-edit-veh]').forEach((b) => {
      b.addEventListener('click', () => {
        const v = state.vehicles[b.dataset.editVeh] || state.vehicles[String(b.dataset.editVeh)];
        const f = $('#vehicleForm');
        f.id.value = v.id; f.job_name.value = v.job_name; f.marker_id.value = v.marker_id || '';
        f.model.value = v.model; f.label.value = v.label; f.min_grade.value = v.min_grade || 0; f.livery.value = v.livery || 0;
      });
    });
    list.querySelectorAll('[data-del-veh]').forEach((b) => {
      b.addEventListener('click', () => post('adminDeleteVehicle', { id: Number(b.dataset.delVeh) }));
    });
  }

  $('#btnNewVehicle')?.addEventListener('click', () => {
    const f = $('#vehicleForm'); f.reset(); f.id.value = '';
    if (currentFilter()) f.job_name.value = currentFilter();
  });

  $('#vehicleForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const f = e.target;
    post('adminSaveVehicle', {
      id: f.id.value ? Number(f.id.value) : null,
      job_name: f.job_name.value,
      marker_id: f.marker_id.value ? Number(f.marker_id.value) : null,
      model: f.model.value, label: f.label.value,
      min_grade: Number(f.min_grade.value) || 0,
      livery: Number(f.livery.value) || 0,
    });
  });

  function renderShops() {
    const list = $('#shopsList');
    if (!list) return;
    const filter = currentFilter();
    const rows = Object.values(state.shops || {}).filter((s) => !filter || s.job_name === filter);
    list.innerHTML = rows.map((s) => `
      <div class="list-item">
        <div>
          <div class="list-item__title">${s.label}</div>
          <div class="list-item__meta">${s.job_name} · ${s.item} · ${s.price}$ · ${s.type}</div>
        </div>
        <div class="list-item__actions">
          <button class="btn btn--soft btn--sm" data-edit-shop="${s.id}">Éditer</button>
          <button class="btn btn--danger btn--sm" data-del-shop="${s.id}">Suppr.</button>
        </div>
      </div>
    `).join('') || '<p class="muted">Aucun item</p>';

    list.querySelectorAll('[data-edit-shop]').forEach((b) => {
      b.addEventListener('click', () => {
        const s = state.shops[b.dataset.editShop] || state.shops[String(b.dataset.editShop)];
        const f = $('#shopForm');
        f.id.value = s.id; f.job_name.value = s.job_name; f.marker_id.value = s.marker_id || '';
        f.item.value = s.item; f.label.value = s.label; f.price.value = s.price || 0;
        f.min_grade.value = s.min_grade || 0; f.type.value = s.type || 'item';
      });
    });
    list.querySelectorAll('[data-del-shop]').forEach((b) => {
      b.addEventListener('click', () => post('adminDeleteShopItem', { id: Number(b.dataset.delShop) }));
    });
  }

  $('#btnNewShop')?.addEventListener('click', () => {
    const f = $('#shopForm'); f.reset(); f.id.value = '';
    if (currentFilter()) f.job_name.value = currentFilter();
  });

  $('#shopForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const f = e.target;
    post('adminSaveShopItem', {
      id: f.id.value ? Number(f.id.value) : null,
      job_name: f.job_name.value,
      marker_id: f.marker_id.value ? Number(f.marker_id.value) : null,
      item: f.item.value, label: f.label.value,
      price: Number(f.price.value) || 0,
      min_grade: Number(f.min_grade.value) || 0,
      type: f.type.value,
    });
  });

  function renderCrafts() {
    const list = $('#craftsList');
    if (!list) return;
    const filter = currentFilter();
    const rows = Object.values(state.crafts || {}).filter((c) => !filter || c.job_name === filter);
    list.innerHTML = rows.map((c) => `
      <div class="list-item">
        <div>
          <div class="list-item__title">${c.label}</div>
          <div class="list-item__meta">${c.job_name} → ${c.result_count}x ${c.result_item}</div>
        </div>
        <div class="list-item__actions">
          <button class="btn btn--soft btn--sm" data-edit-craft="${c.id}">Éditer</button>
          <button class="btn btn--danger btn--sm" data-del-craft="${c.id}">Suppr.</button>
        </div>
      </div>
    `).join('') || '<p class="muted">Aucune recette</p>';

    list.querySelectorAll('[data-edit-craft]').forEach((b) => {
      b.addEventListener('click', () => {
        const c = state.crafts[b.dataset.editCraft] || state.crafts[String(b.dataset.editCraft)];
        const f = $('#craftForm');
        f.id.value = c.id; f.job_name.value = c.job_name; f.marker_id.value = c.marker_id || '';
        f.label.value = c.label; f.result_item.value = c.result_item; f.result_count.value = c.result_count || 1;
        f.duration.value = c.duration || 5000; f.min_grade.value = c.min_grade || 0;
        f.ingredients.value = (c.ingredients || []).map((i) => `${i.item}:${i.count}`).join(', ');
      });
    });
    list.querySelectorAll('[data-del-craft]').forEach((b) => {
      b.addEventListener('click', () => post('adminDeleteCraft', { id: Number(b.dataset.delCraft) }));
    });
  }

  $('#btnNewCraft')?.addEventListener('click', () => {
    const f = $('#craftForm'); f.reset(); f.id.value = '';
    if (currentFilter()) f.job_name.value = currentFilter();
  });

  $('#craftForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const f = e.target;
    const ingredients = (f.ingredients.value || '').split(',').map((s) => s.trim()).filter(Boolean).map((s) => {
      const [item, count] = s.split(':');
      return { item: item.trim(), count: Number(count) || 1 };
    });
    post('adminSaveCraft', {
      id: f.id.value ? Number(f.id.value) : null,
      job_name: f.job_name.value,
      marker_id: f.marker_id.value ? Number(f.marker_id.value) : null,
      label: f.label.value,
      result_item: f.result_item.value,
      result_count: Number(f.result_count.value) || 1,
      duration: Number(f.duration.value) || 5000,
      min_grade: Number(f.min_grade.value) || 0,
      ingredients,
    });
  });

  $('#setJobForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const f = e.target;
    post('adminSetJob', {
      targetId: Number(f.targetId.value),
      job: f.job.value,
      grade: Number(f.grade.value) || 0,
    });
  });

  $('#btnCopyCoords')?.addEventListener('click', async () => {
    const c = await post('adminGetCoords');
    if (c?.x != null) {
      $('#liveCoords').textContent = `vector4(${c.x}, ${c.y}, ${c.z}, ${c.w || 0})`;
    }
  });

  function renderOxGaragesPanel() {
    const list = $('#oxGaragesList');
    const status = $('#oxGarageStatus');
    if (status) {
      status.textContent = state.useOxGarage
        ? `${(state.oxGarages || []).length} garage(s) ox_garage — utilise-les dans Markers (Garage / Ranger).`
        : 'ox_garage non détecté (ensure ox_garage + Config.UseOxGarage = true).';
    }
    if (!list) return;
    const rows = state.oxGarages || [];
    list.innerHTML = rows.map((g) => `
      <div class="list-item">
        <div>
          <div class="list-item__title">${g.label || g.id}</div>
          <div class="list-item__meta">id: ${g.id} · ${g.kind || '?'}${g.job ? ` · job ${g.job}` : ''} · ${g.source || ''}</div>
        </div>
        <div class="list-item__actions">
          <button class="btn btn--soft btn--sm" data-use-ox="${g.id}">Utiliser dans marker</button>
        </div>
      </div>
    `).join('') || '<p class="muted">Aucun garage ox_garage</p>';

    list.querySelectorAll('[data-use-ox]').forEach((btn) => {
      btn.addEventListener('click', () => {
        // Prépare un marker garage lié à cet id
        document.querySelector('[data-tab="markers"]')?.click();
        const f = $('#markerForm');
        if (!f) return;
        f.type.value = 'garage';
        f.label.value = btn.closest('.list-item')?.querySelector('.list-item__title')?.textContent || 'Garage';
        renderMarkerDataFields('garage', {
          ox_mode: String(btn.dataset.useOx).startsWith('job_') ? 'job_fleet' : 'ox_garage',
          ox_garage_id: btn.dataset.useOx,
          register_job_garage: 'false',
          radius: 8,
        });
      });
    });
  }

  $('#btnRefreshOxGaragesTab')?.addEventListener('click', () => post('adminGetOxGarages', {}));
  $('#btnOpenGarageCreator')?.addEventListener('click', () => post('adminOpenGarageCreator', {}));

  function renderAll() {
    fillJobSelects();
    renderJobs();
    renderGrades();
    renderMarkers();
    renderOxGaragesPanel();
    renderVehicles();
    renderShops();
    renderCrafts();
  }

  /* ---------- PLAYER MENUS ---------- */
  const pm = $('#playerMenu');
  const pmBody = $('#pmBody');
  const pmTitle = $('#pmTitle');

  $('#pmClose')?.addEventListener('click', () => post('playerClose'));

  function openPlayerMenu(data) {
    state.playerMenu = data;
    pmTitle.textContent = data.title || 'Menu';
    pmBody.innerHTML = '';
    pm.classList.remove('hidden');

    if (data.type === 'shop') {
      data.items.forEach((it) => {
        const el = document.createElement('div');
        el.className = 'pm-item';
        el.innerHTML = `<div><strong>${it.label}</strong><br/><span>${it.price}$ · ${it.type}</span></div><button class="btn btn--primary btn--sm">Acheter</button>`;
        el.querySelector('button').onclick = () => post('shopBuy', { id: it.id });
        pmBody.appendChild(el);
      });
      if (!data.items.length) pmBody.innerHTML = '<p class="muted">Boutique vide</p>';
    }

    if (data.type === 'craft') {
      data.items.forEach((it) => {
        const el = document.createElement('div');
        el.className = 'pm-item';
        const ings = (it.ingredients || []).map((i) => `${i.count}x ${i.item}`).join(', ');
        el.innerHTML = `<div><strong>${it.label}</strong><br/><span>${ings || '—'}</span></div><button class="btn btn--primary btn--sm">Craft</button>`;
        el.querySelector('button').onclick = () => post('craftDo', { id: it.id });
        pmBody.appendChild(el);
      });
    }

    if (data.type === 'garage') {
      data.items.forEach((it) => {
        const el = document.createElement('div');
        el.className = 'pm-item';
        el.innerHTML = `<div><strong>${it.label}</strong><br/><span>${it.model}</span></div><button class="btn btn--primary btn--sm">Sortir</button>`;
        el.querySelector('button').onclick = () => post('garageSpawn', {
          model: it.model, livery: it.livery || 0, spawn: data.spawn || null,
        });
        pmBody.appendChild(el);
      });
      if (!data.items.length) pmBody.innerHTML = '<p class="muted">Aucun véhicule</p>';
    }

    if (data.type === 'cloakroom') {
      const civ = document.createElement('div');
      civ.className = 'pm-item';
      civ.innerHTML = `<div><strong>Tenue civile</strong></div><button class="btn btn--soft btn--sm">Mettre</button>`;
      civ.querySelector('button').onclick = () => post('cloakApply', { civilian: true });
      pmBody.appendChild(civ);
      data.items.forEach((it) => {
        const el = document.createElement('div');
        el.className = 'pm-item';
        el.innerHTML = `<div><strong>${it.label}</strong><br/><span>grade ≥ ${it.min_grade || 0}</span></div><button class="btn btn--primary btn--sm">Mettre</button>`;
        el.querySelector('button').onclick = () => post('cloakApply', { id: it.id });
        pmBody.appendChild(el);
      });
    }

    if (data.type === 'wash') {
      pmBody.innerHTML = `
        <p class="muted">Frais de blanchiment : ${data.fee || 30}%</p>
        <label class="muted">Montant argent sale
          <input class="input" id="washAmount" type="number" min="1" placeholder="10000" />
        </label>
        <button class="btn btn--primary" id="washBtn">Blanchir</button>
      `;
      $('#washBtn').onclick = () => {
        const amount = Number($('#washAmount').value) || 0;
        post('washDo', { markerId: data.markerId, amount });
      };
    }

    if (data.type === 'actions') {
      data.items.forEach((it) => {
        const el = document.createElement('div');
        el.className = 'pm-item';
        el.innerHTML = `<div><strong>${it.label}</strong></div>`;
        el.onclick = () => post('actionDo', { action: it.id });
        pmBody.appendChild(el);
      });
    }

    if (data.type === 'billing') {
      pmBody.innerHTML = `
        <p class="muted">Choisis un joueur proche puis le montant.</p>
        <div id="billPlayers"></div>
        <label class="muted">Montant <input class="input" id="billAmount" type="number" /></label>
        <label class="muted">Raison <input class="input" id="billReason" value="Facture" /></label>
        <button class="btn btn--primary" id="billSend" disabled>Envoyer</button>
      `;
      post('requestNearby');
      let selected = null;
      window.__onNearby = (players) => {
        const box = $('#billPlayers');
        if (!box) return;
        box.innerHTML = (players || []).map((p) => `
          <div class="pm-item" data-id="${p.id}"><div><strong>${p.name}</strong><br/><span>${p.job}</span></div></div>
        `).join('') || '<p class="muted">Personne à proximité</p>';
        box.querySelectorAll('.pm-item').forEach((el) => {
          el.onclick = () => {
            selected = Number(el.dataset.id);
            box.querySelectorAll('.pm-item').forEach((x) => x.style.borderColor = '');
            el.style.borderColor = 'var(--accent)';
            $('#billSend').disabled = false;
          };
        });
      };
      $('#billSend').onclick = () => {
        post('billSend', {
          targetId: selected,
          amount: Number($('#billAmount').value) || 0,
          reason: $('#billReason').value,
        });
      };
    }

    if (data.type === 'stash') {
      renderStash(data);
    }

    if (data.type === 'search') {
      const d = data.data || {};
      pmBody.innerHTML = `
        <div class="money-line">${d.money || 0}$ · sale ${d.black || 0}$</div>
        <div class="pm-section"><h3>Items</h3>
          ${(d.items || []).map((i) => `<div class="pm-item"><strong>${i.label}</strong><span>x${i.count}</span></div>`).join('') || '<p class="muted">Vide</p>'}
        </div>
        <div class="pm-section"><h3>Armes</h3>
          ${(d.weapons || []).map((w) => `<div class="pm-item"><strong>${w.label}</strong><span>${w.ammo} mun.</span></div>`).join('') || '<p class="muted">Aucune</p>'}
        </div>
      `;
    }

    if (data.type === 'boss') {
      renderBoss(data);
    }
  }

  function renderStash(data) {
    pmBody.innerHTML = `
      <div class="pm-section"><h3>Coffre</h3><div id="stashItems"></div></div>
      <div class="pm-section"><h3>Ton inventaire</h3><div id="stashPlayer"></div></div>
    `;
    const stashBox = $('#stashItems');
    const playerBox = $('#stashPlayer');
    (data.items || []).forEach((it) => {
      const el = document.createElement('div');
      el.className = 'pm-item';
      el.innerHTML = `<div><strong>${it.label || it.name}</strong><br/><span>x${it.count}</span></div>
        <button class="btn btn--soft btn--sm">Retirer</button>`;
      el.querySelector('button').onclick = () => {
        const count = Number(prompt('Quantité', '1')) || 1;
        post('stashWithdraw', { stashId: data.stashId, item: it.name, count });
      };
      stashBox.appendChild(el);
    });
    const pItems = Array.isArray(data.playerItems) ? data.playerItems : Object.values(data.playerItems || {});
    pItems.forEach((it) => {
      if (!it || !it.name || !(it.count > 0)) return;
      const el = document.createElement('div');
      el.className = 'pm-item';
      el.innerHTML = `<div><strong>${it.label || it.name}</strong><br/><span>x${it.count}</span></div>
        <button class="btn btn--primary btn--sm">Déposer</button>`;
      el.querySelector('button').onclick = () => {
        const count = Number(prompt('Quantité', '1')) || 1;
        post('stashDeposit', { stashId: data.stashId, item: it.name, count });
      };
      playerBox.appendChild(el);
    });
  }

  function renderBoss(data) {
    pmBody.innerHTML = `
      <div class="pm-section">
        <h3>Société</h3>
        <div class="money-line" id="bossMoney">…</div>
        <div class="row">
          <input class="input" id="bossAmount" type="number" placeholder="Montant" />
        </div>
        <div class="row" style="margin-top:.4rem">
          <button class="btn btn--primary btn--sm" id="bossDep">Déposer</button>
          <button class="btn btn--soft btn--sm" id="bossWit">Retirer</button>
        </div>
      </div>
      <div class="pm-section">
        <h3>Employés</h3>
        <div id="bossEmployees"></div>
      </div>
      <div class="pm-section">
        <h3>Recruter (proches)</h3>
        <div id="bossNearby"></div>
      </div>
      <button class="btn btn--soft btn--sm" id="bossRefresh">Rafraîchir</button>
    `;

    $('#bossDep').onclick = () => post('bossDeposit', { job: data.job, amount: Number($('#bossAmount').value) || 0 });
    $('#bossWit').onclick = () => post('bossWithdraw', { job: data.job, amount: Number($('#bossAmount').value) || 0 });
    $('#bossRefresh').onclick = () => post('bossRefresh', { job: data.job });
    post('bossRefresh', { job: data.job });
    post('requestNearby');

    window.__onSociety = (d) => {
      if ($('#bossMoney')) $('#bossMoney').textContent = (d.money || 0).toLocaleString('fr-FR') + ' $';
    };

    window.__onEmployees = (d) => {
      const box = $('#bossEmployees');
      if (!box) return;
      const all = [...(d.online || []), ...(d.offline || [])];
      const grades = d.grades || [];
      box.innerHTML = all.map((e) => `
        <div class="pm-item">
          <div>
            <strong>${e.name || e.identifier}</strong><br/>
            <span>${e.online ? 'En ligne' : 'Hors ligne'} · grade ${e.grade}${e.grade_label ? ' ('+e.grade_label+')' : ''}</span>
          </div>
          <div class="list-item__actions">
            <select class="input input--sm" data-grade-for="${e.id || ''}" data-ident="${e.identifier || ''}">
              ${grades.map((g) => `<option value="${g.grade}" ${g.grade === e.grade ? 'selected' : ''}>${g.label}</option>`).join('')}
            </select>
            <button class="btn btn--soft btn--sm" data-set-grade="${e.id || ''}" data-ident="${e.identifier || ''}">OK</button>
            <button class="btn btn--danger btn--sm" data-fire="${e.id || ''}" data-ident="${e.identifier || ''}">Licencier</button>
          </div>
        </div>
      `).join('') || '<p class="muted">Aucun employé</p>';

      box.querySelectorAll('[data-set-grade]').forEach((btn) => {
        btn.onclick = () => {
          const sel = box.querySelector(`select[data-ident="${btn.dataset.ident}"]`) || box.querySelector(`select[data-grade-for="${btn.dataset.setGrade}"]`);
          post('bossSetGrade', {
            job: data.job,
            targetId: btn.dataset.setGrade ? Number(btn.dataset.setGrade) : null,
            identifier: btn.dataset.ident || null,
            grade: Number(sel?.value) || 0,
          });
        };
      });
      box.querySelectorAll('[data-fire]').forEach((btn) => {
        btn.onclick = () => post('bossFire', {
          job: data.job,
          targetId: btn.dataset.fire ? Number(btn.dataset.fire) : null,
          identifier: btn.dataset.ident || null,
        });
      });
    };

    window.__onNearby = (players) => {
      const box = $('#bossNearby');
      if (!box) return;
      box.innerHTML = (players || []).map((p) => `
        <div class="pm-item">
          <div><strong>${p.name}</strong><br/><span>${p.job}</span></div>
          <button class="btn btn--primary btn--sm" data-hire="${p.id}">Recruter</button>
        </div>
      `).join('') || '<p class="muted">Personne à proximité</p>';
      box.querySelectorAll('[data-hire]').forEach((btn) => {
        btn.onclick = () => post('bossHire', { job: data.job, targetId: Number(btn.dataset.hire), grade: 0 });
      });
    };
  }

  /* ---------- MESSAGES ---------- */
  window.addEventListener('message', (event) => {
    const msg = event.data || {};

    if (msg.action === 'openAdmin') {
      const d = msg.data || {};
      state.jobs = d.jobs || {};
      state.markers = d.markers || {};
      state.vehicles = d.vehicles || {};
      state.outfits = d.outfits || {};
      state.shops = d.shops || {};
      state.crafts = d.crafts || {};
      state.markerTypes = d.markerTypes || [];
      state.permissions = d.permissions || [];
      state.defaultActions = d.defaultActions || [];
      state.oxGarages = d.oxGarages || [];
      state.useOxGarage = !!d.useOxGarage;
      state.playerCoords = msg.playerCoords;
      $('#admin').classList.remove('hidden');
      initMarkerTypes();
      buildActionChecks({});
      buildPermChecks({});
      renderAll();
      renderOxGaragesPanel();
      if (state.playerCoords) {
        $('#liveCoords').textContent = `vector4(${state.playerCoords.x}, ${state.playerCoords.y}, ${state.playerCoords.z}, ${state.playerCoords.w || 0})`;
      }
    }

    if (msg.action === 'oxGarages') {
      state.oxGarages = msg.data || [];
      renderOxGaragesPanel();
      const type = $('#markerTypeSelect')?.value;
      if (type === 'garage' || type === 'garage_store') {
        const mode = $('select[name="data_ox_mode"]')?.value || 'job_fleet';
        const currentId = $('select[name="data_ox_garage_id"]')?.value || '';
        const radius = $('input[name="data_radius"]')?.value || '8';
        const spawn = $('input[name="data_spawn"]')?.value || '';
        const reg = $('select[name="data_register_job_garage"]')?.value || 'false';
        renderMarkerDataFields(type, {
          ox_mode: mode,
          ox_garage_id: currentId,
          radius,
          spawn,
          register_job_garage: reg,
        });
      }
    }

    if (msg.action === 'closeAdmin') {
      $('#admin').classList.add('hidden');
    }

    if (msg.action === 'playerMenu') {
      openPlayerMenu(msg.data || {});
    }

    if (msg.action === 'closePlayerMenu') {
      pm.classList.add('hidden');
      state.playerMenu = null;
    }

    if (msg.action === 'refreshStash' && state.playerMenu?.type === 'stash') {
      state.playerMenu.items = msg.items || [];
      renderStash(state.playerMenu);
    }

    if (msg.action === 'nearbyPlayers' && typeof window.__onNearby === 'function') {
      window.__onNearby(msg.players || []);
    }

    if (msg.action === 'employeesData' && typeof window.__onEmployees === 'function') {
      window.__onEmployees(msg.data || {});
    }

    if (msg.action === 'societyData' && typeof window.__onSociety === 'function') {
      window.__onSociety(msg.data || {});
    }
  });
})();
