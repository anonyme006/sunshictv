(() => {
    const screen = document.getElementById('select');
    if (!screen) return;

    const slotList = document.getElementById('slot-list');
    const details = document.getElementById('select-details');
    const playBtn = document.getElementById('btn-play');
    const deleteBtn = document.getElementById('btn-delete');
    const countLabel = document.getElementById('select-count');

    let payload = null;
    let selectedIndex = 0;
    let pendingDelete = false;

    function resourceName() {
        return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx-charactercreator';
    }

    async function nui(name, data) {
        if (window.CREATOR_PREVIEW) return { ok: true };
        try {
            const response = await fetch(`https://${resourceName()}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data || {}),
            });
            return await response.json();
        } catch (error) {
            return { ok: false };
        }
    }

    function t(path, fallback) {
        const locales = payload && payload.translations ? payload.translations : {};
        return path.split('.').reduce((acc, key) => (acc && acc[key] !== undefined ? acc[key] : undefined), locales) || fallback || path;
    }

    function money(value) {
        return new Intl.NumberFormat('fr-FR').format(Number(value) || 0) + ' $';
    }

    function slots() {
        const characters = (payload && payload.characters) || [];
        const max = payload && payload.slots ? payload.slots : 3;
        const list = [];
        for (let i = 0; i < max; i += 1) {
            list.push(characters[i] || null);
        }
        return list;
    }

    function current() {
        return slots()[selectedIndex] || null;
    }

    function render() {
        const list = slots();
        slotList.innerHTML = '';
        list.forEach((character, index) => {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = `slot-card${character ? '' : ' empty'}${index === selectedIndex ? ' active' : ''}`;
            if (character) {
                button.innerHTML = `<strong>${character.charinfo.firstname} ${character.charinfo.lastname}</strong><span>${character.citizenid}</span>`;
            } else {
                button.innerHTML = `<strong>${t('ui.empty_slot', 'Emplacement libre')}</strong><span>${t('ui.slot', 'Emplacement')} ${index + 1}</span>`;
            }
            button.addEventListener('click', () => selectSlot(index, true));
            slotList.appendChild(button);
        });

        const character = current();
        countLabel.textContent = `${list.filter(Boolean).length} / ${list.length}`;
        if (character) {
            details.innerHTML = `
                <p><strong>${character.charinfo.firstname} ${character.charinfo.lastname}</strong></p>
                <p>${t('identity.birthdate', 'Date de naissance')} · ${character.charinfo.birthdate || '—'}</p>
                <p>${t('ui.job', 'Emploi')} · ${character.job && character.job.label ? character.job.label : '—'}</p>
                <p>${t('ui.cash', 'Espèces')} · ${money(character.money && character.money.cash)}</p>
                <p>${t('ui.bank', 'Banque')} · ${money(character.money && character.money.bank)}</p>
            `;
            playBtn.textContent = t('ui.play', 'Entrer en ville');
            deleteBtn.classList.toggle('hidden', payload.enableDelete === false);
            deleteBtn.textContent = t('ui.delete', 'Supprimer');
            pendingDelete = false;
        } else {
            details.innerHTML = `<p>${t('ui.no_character', 'Aucun personnage sur cet emplacement')}</p>`;
            playBtn.textContent = t('ui.create', 'Créer un personnage');
            deleteBtn.classList.add('hidden');
        }
    }

    function selectSlot(index, preview) {
        selectedIndex = index;
        render();
        const character = current();
        if (preview) nui('selectPreview', { citizenid: character && character.citizenid });
    }

    playBtn.addEventListener('click', () => {
        const character = current();
        if (character) nui('selectPlay', { citizenid: character.citizenid });
        else nui('selectCreate', { cid: selectedIndex + 1 });
    });

    deleteBtn.addEventListener('click', async () => {
        const character = current();
        if (!character || payload.enableDelete === false) return;
        if (!pendingDelete) {
            pendingDelete = true;
            deleteBtn.textContent = t('ui.confirm', 'Confirmer');
            return;
        }
        const result = await nui('selectDelete', { citizenid: character.citizenid });
        pendingDelete = false;
        if (result && result.ok === false) return;
        selectedIndex = 0;
    });

    function open(data) {
        payload = data || { characters: [], slots: 3, enableDelete: true };
        selectedIndex = 0;
        screen.classList.remove('hidden');
        screen.setAttribute('aria-hidden', 'false');
        document.getElementById('app').classList.add('hidden');
        render();
        const first = current();
        nui('selectPreview', { citizenid: first && first.citizenid });
    }

    function close() {
        screen.classList.add('hidden');
        screen.setAttribute('aria-hidden', 'true');
        payload = null;
    }

    window.addEventListener('message', (event) => {
        const { action, data } = event.data || {};
        if (action === 'select') open(data);
        if (action === 'closeSelect') close();
    });
})();
