(() => {
    const app = document.getElementById('app');
    const fields = document.getElementById('fields');
    const categoryList = document.getElementById('category-list');
    const modal = document.getElementById('modal');
    const toasts = document.getElementById('toasts');

    const HINTS = {
        identity: 'Renseignez l’identité officielle de votre personnage.',
        heritage: 'Mélangez les traits hérités du père et de la mère.',
        face: 'Sculptez les volumes du visage en temps réel.',
        hair: 'Coiffure, couleurs, barbe et sourcils.',
        eyes: 'Couleur et ouverture du regard.',
        skin: 'Teint, vieillissement et imperfections.',
        makeup: 'Maquillage, blush et rouge à lèvres.',
        clothing: 'Haut, veste, pantalon et chaussures.',
        accessories: 'Chapeau, lunettes, bijoux et sacs.',
    };

    const FACE_FIELDS = [
        ['cheeksWidth', 'Largeur du visage'],
        ['jawBoneLength', 'Forme du visage'],
        ['eyebrowHeight', 'Hauteur du visage'],
        ['noseWidth', 'Largeur du nez'],
        ['nosePeakHeight', 'Hauteur du nez'],
        ['nosePeakLength', 'Longueur du nez'],
        ['noseBoneHeight', 'Position du nez'],
        ['nosePeakLowering', 'Pointe du nez'],
        ['noseBoneTwist', 'Torsion du nez'],
        ['cheekboneHeight', 'Hauteur des pommettes'],
        ['cheekboneWidth', 'Largeur des pommettes'],
        ['lipsThickness', 'Épaisseur des lèvres'],
        ['jawBoneWidth', 'Largeur de la mâchoire'],
        ['chinBoneLowering', 'Hauteur du menton'],
        ['chinBoneLength', 'Longueur du menton'],
        ['chinBoneWidth', 'Largeur du menton'],
        ['chinDimple', 'Forme du menton'],
        ['neckThickness', 'Cou'],
        ['eyebrowDepth', 'Profondeur des sourcils'],
        ['eyesOpening', 'Ouverture du regard'],
    ];

    let state = null;
    let categoryIndex = 0;
    let dragging = false;
    let lastX = 0;
    let audioCtx = null;
    let modalResolver = null;

    function resourceName() {
        return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx-charactercreator';
    }

    async function nui(name, data) {
        if (window.CREATOR_PREVIEW) {
            return { ok: true, textureMax: 12 };
        }
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
        const locales = state && state.locales ? state.locales : {};
        return path.split('.').reduce((acc, key) => (acc && acc[key] !== undefined ? acc[key] : undefined), locales) || fallback || path;
    }

    function playSound(kind) {
        if (!state || !state.config || !state.config.sound) return;
        const volume = state.config.volume ?? 0.3;
        try {
            audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = audioCtx.createOscillator();
            const gain = audioCtx.createGain();
            const map = { click: 420, category: 520, value: 360, success: 640, error: 180 };
            oscillator.frequency.value = map[kind] || 400;
            oscillator.type = kind === 'error' ? 'sawtooth' : 'sine';
            gain.gain.value = volume * 0.08;
            oscillator.connect(gain);
            gain.connect(audioCtx.destination);
            oscillator.start();
            oscillator.stop(audioCtx.currentTime + 0.06);
        } catch (error) {
            return;
        }
        nui('sound', { name: 'NAV_LEFT_RIGHT', set: 'HUD_FRONTEND_DEFAULT_SOUNDSET' });
    }

    function toast(message, type) {
        const node = document.createElement('div');
        node.className = `toast ${type || ''}`;
        node.textContent = message;
        toasts.appendChild(node);
        setTimeout(() => node.remove(), 4200);
        nui('notify', { message, type: type || 'inform' });
    }

    function openModal(title, text) {
        document.getElementById('modal-title').textContent = title;
        document.getElementById('modal-text').textContent = text;
        modal.classList.remove('hidden');
        return new Promise((resolve) => {
            modalResolver = resolve;
        });
    }

    function closeModal(result) {
        modal.classList.add('hidden');
        if (modalResolver) modalResolver(result);
        modalResolver = null;
    }

    function currentCategory() {
        return state.categories[categoryIndex];
    }

    function updateChrome() {
        const key = currentCategory();
        const total = state.categories.length;
        document.getElementById('ui-title').textContent = t('ui.title', 'Création de personnage');
        document.getElementById('step-label').textContent = `${t('ui.step', 'Étape')} ${categoryIndex + 1} ${t('ui.of', 'sur')} ${total}`;
        document.getElementById('category-label').textContent = t(`categories.${key}`, key);
        document.getElementById('panel-title').textContent = t(`categories.${key}`, key);
        document.getElementById('panel-eyebrow').textContent = t('ui.title', 'Création');
        document.getElementById('panel-hint').textContent = HINTS[key] || '';
        document.getElementById('progress-bar').style.width = `${((categoryIndex + 1) / total) * 100}%`;
        document.getElementById('btn-prev').disabled = categoryIndex === 0;
        document.getElementById('btn-next').textContent = categoryIndex === total - 1 ? t('ui.confirm', 'Confirmer') : t('ui.next', 'Continuer');
        document.getElementById('btn-cancel').classList.toggle('hidden', state.allowCancel === false);
        document.querySelectorAll('.cat-btn').forEach((btn, index) => {
            btn.classList.toggle('active', index === categoryIndex);
        });
    }

    function renderNav() {
        categoryList.innerHTML = '';
        state.categories.forEach((key, index) => {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = `cat-btn${index === categoryIndex ? ' active' : ''}`;
            button.innerHTML = `${window.CreatorIcons[key] || ''}<span>${t(`categories.${key}`, key)}</span>`;
            button.addEventListener('click', () => setCategory(index, true));
            categoryList.appendChild(button);
        });
    }

    function setCategory(index, fromNav) {
        categoryIndex = Math.max(0, Math.min(state.categories.length - 1, index));
        updateChrome();
        renderFields();
        playSound('category');
        nui('changeCamera', { category: currentCategory() });
        if (fromNav) return;
    }

    function updateAppearance(section, payload) {
        state.appearance[section] = payload;
        nui('updateAppearance', { section, payload });
        playSound('value');
    }

    function validateIdentity() {
        const identity = state.identity;
        const min = state.config.minName;
        const max = state.config.maxName;
        const nameRe = /^[\p{L}'\- ]+$/u;
        if (!identity.firstname || identity.firstname.trim().length < min || identity.firstname.length > max || !nameRe.test(identity.firstname)) {
            return 'notify.invalid_firstname';
        }
        if (!identity.lastname || identity.lastname.trim().length < min || identity.lastname.length > max || !nameRe.test(identity.lastname)) {
            return 'notify.invalid_lastname';
        }
        if (!identity.birthdate) return 'notify.invalid_birthdate';
        const birth = new Date(identity.birthdate);
        if (Number.isNaN(birth.getTime())) return 'notify.invalid_birthdate';
        const today = new Date();
        let age = today.getFullYear() - birth.getFullYear();
        const month = today.getMonth() - birth.getMonth();
        if (month < 0 || (month === 0 && today.getDate() < birth.getDate())) age -= 1;
        if (age < state.config.minAge || age > state.config.maxAge) return 'notify.invalid_age';
        return null;
    }

    function renderIdentity() {
        const C = window.CreatorControls;
        fields.appendChild(C.input({
            label: t('identity.firstname', 'Prénom'),
            value: state.identity.firstname,
            maxlength: state.config.maxName,
        }, (value) => {
            state.identity.firstname = value;
            nui('updateIdentity', { firstname: value });
        }));
        fields.appendChild(C.input({
            label: t('identity.lastname', 'Nom'),
            value: state.identity.lastname,
            maxlength: state.config.maxName,
        }, (value) => {
            state.identity.lastname = value;
            nui('updateIdentity', { lastname: value });
        }));
        fields.appendChild(C.input({
            label: t('identity.birthdate', 'Date de naissance'),
            type: 'date',
            value: state.identity.birthdate,
        }, (value) => {
            state.identity.birthdate = value;
            nui('updateIdentity', { birthdate: value });
        }));
        fields.appendChild(C.select({
            label: t('identity.gender', 'Sexe'),
            value: state.identity.gender,
            items: [
                { value: 0, label: t('identity.male', 'Homme') },
                { value: 1, label: t('identity.female', 'Femme') },
            ],
        }, (value) => {
            state.identity.gender = Number(value);
            nui('updateIdentity', { gender: Number(value), category: 'identity' });
        }));
        fields.appendChild(C.slider({
            label: t('identity.height', 'Taille (cm)'),
            min: state.config.minHeight,
            max: state.config.maxHeight,
            value: state.identity.height,
            step: 1,
        }, (value) => {
            state.identity.height = value;
            nui('updateIdentity', { height: value });
        }));
        fields.appendChild(C.select({
            label: t('identity.nationality', 'Nationalité'),
            value: state.identity.nationality,
            items: (state.nationalities || []).map((item) => ({ value: item, label: item })),
        }, (value) => {
            state.identity.nationality = value;
            nui('updateIdentity', { nationality: value });
        }));
    }

    function renderHeritage() {
        const C = window.CreatorControls;
        const heritage = state.appearance.heritage;
        fields.appendChild(C.select({
            label: 'Mère',
            value: heritage.mother,
            items: state.parents.mothers.map((item) => ({ value: item.id, label: item.label })),
        }, (value) => {
            heritage.mother = Number(value);
            updateAppearance('heritage', heritage);
        }));
        fields.appendChild(C.select({
            label: 'Père',
            value: heritage.father,
            items: state.parents.fathers.map((item) => ({ value: item.id, label: item.label })),
        }, (value) => {
            heritage.father = Number(value);
            updateAppearance('heritage', heritage);
        }));
        fields.appendChild(C.slider({
            label: 'Ressemblance mère / père',
            min: 0,
            max: 1,
            step: 0.01,
            value: heritage.resemblance,
            percent: true,
        }, (value) => {
            heritage.resemblance = value;
            heritage.faceResemblance = value;
            updateAppearance('heritage', heritage);
        }));
        fields.appendChild(C.slider({
            label: 'Ressemblance visage',
            min: 0,
            max: 1,
            step: 0.01,
            value: heritage.faceResemblance,
            percent: true,
        }, (value) => {
            heritage.faceResemblance = value;
            updateAppearance('heritage', heritage);
        }));
        fields.appendChild(C.slider({
            label: 'Couleur de peau héritée',
            min: 0,
            max: 1,
            step: 0.01,
            value: heritage.skinMix,
            percent: true,
        }, (value) => {
            heritage.skinMix = value;
            updateAppearance('heritage', heritage);
        }));
    }

    function renderFace() {
        const C = window.CreatorControls;
        const face = state.appearance.face;
        FACE_FIELDS.forEach(([key, label]) => {
            fields.appendChild(C.slider({
                label,
                min: -1,
                max: 1,
                step: 0.01,
                value: face[key] ?? 0,
            }, (value) => {
                face[key] = value;
                updateAppearance('face', face);
            }));
        });
    }

    function overlaySlider(name, label, extraColor) {
        const C = window.CreatorControls;
        const overlay = state.appearance.overlays[name];
        const maxStyle = state.limits.overlays?.[name] ?? 20;
        fields.appendChild(C.slider({
            label: `${label} · modèle`,
            min: 0,
            max: maxStyle,
            step: 1,
            value: overlay.style,
        }, (value) => {
            overlay.style = value;
            nui('updateAppearance', { section: 'overlay', payload: { name, ...overlay } });
            playSound('value');
        }));
        fields.appendChild(C.slider({
            label: `${label} · opacité`,
            min: 0,
            max: 1,
            step: 0.01,
            value: overlay.opacity,
            percent: true,
        }, (value) => {
            overlay.opacity = value;
            nui('updateAppearance', { section: 'overlay', payload: { name, ...overlay } });
        }));
        if (extraColor) {
            fields.appendChild(C.slider({
                label: `${label} · couleur`,
                min: 0,
                max: state.limits.hairColors || 63,
                step: 1,
                value: overlay.color,
            }, (value) => {
                overlay.color = value;
                nui('updateAppearance', { section: 'overlay', payload: { name, ...overlay } });
            }));
        }
    }

    function renderHair() {
        const C = window.CreatorControls;
        const hair = state.appearance.hair;
        fields.appendChild(C.slider({
            label: 'Coiffure',
            min: 0,
            max: state.limits.hair || 40,
            step: 1,
            value: hair.style,
        }, (value) => {
            hair.style = value;
            updateAppearance('hair', hair);
        }));
        fields.appendChild(C.slider({
            label: 'Couleur principale',
            min: 0,
            max: state.limits.hairColors || 63,
            step: 1,
            value: hair.color,
        }, (value) => {
            hair.color = value;
            updateAppearance('hair', hair);
        }));
        fields.appendChild(C.slider({
            label: 'Couleur secondaire',
            min: 0,
            max: state.limits.hairColors || 63,
            step: 1,
            value: hair.highlight,
        }, (value) => {
            hair.highlight = value;
            updateAppearance('hair', hair);
        }));
        overlaySlider('eyebrows', 'Sourcils', true);
        overlaySlider('beard', 'Barbe', true);
        overlaySlider('chestHair', 'Pilosité', true);
    }

    function renderEyes() {
        const C = window.CreatorControls;
        const eyes = state.appearance.eyes;
        fields.appendChild(C.slider({
            label: 'Couleur des yeux',
            min: 0,
            max: 31,
            step: 1,
            value: eyes.color,
        }, (value) => {
            eyes.color = value;
            updateAppearance('eyes', eyes);
        }));
        fields.appendChild(C.slider({
            label: 'Taille des yeux',
            min: -1,
            max: 1,
            step: 0.01,
            value: eyes.size,
        }, (value) => {
            eyes.size = value;
            updateAppearance('eyes', eyes);
        }));
        fields.appendChild(C.slider({
            label: 'Ouverture des yeux',
            min: -1,
            max: 1,
            step: 0.01,
            value: eyes.opening,
        }, (value) => {
            eyes.opening = value;
            updateAppearance('eyes', eyes);
        }));
        fields.appendChild(C.slider({
            label: 'Position des yeux',
            min: -1,
            max: 1,
            step: 0.01,
            value: eyes.position,
        }, (value) => {
            eyes.position = value;
            updateAppearance('eyes', eyes);
        }));
    }

    function renderSkin() {
        overlaySlider('complexion', 'Teint', false);
        overlaySlider('ageing', 'Vieillissement / rides', false);
        overlaySlider('blemishes', 'Imperfections', false);
        overlaySlider('moles', 'Taches', false);
        overlaySlider('sunDamage', 'Coups de soleil', false);
    }

    function renderMakeup() {
        overlaySlider('makeup', 'Maquillage', true);
        overlaySlider('blush', 'Blush', true);
        overlaySlider('lipstick', 'Rouge à lèvres', true);
    }

    function clothingValue(bucket, id, fallback) {
        const store = state.appearance.clothing[bucket] || {};
        return store[id] || store[String(id)] || fallback;
    }

    function renderSlots(slots, prop) {
        const bucket = prop ? 'props' : 'components';
        const limits = prop ? state.limits.clothing.props : state.limits.clothing.components;
        slots.forEach((slot) => {
            const current = clothingValue(bucket, slot.id, { drawable: prop ? -1 : 0, texture: prop ? -1 : 0 });
            const limit = limits[slot.id] || limits[String(slot.id)] || { drawable: 20, texture: 10 };
            const block = window.CreatorControls.pair(
                slot.label,
                { min: prop ? -1 : 0, max: limit.drawable, value: current.drawable },
                { min: prop ? -1 : 0, max: Math.max(limit.texture, 0), value: current.texture },
                async (drawable) => {
                    current.drawable = drawable;
                    if (!state.appearance.clothing[bucket]) state.appearance.clothing[bucket] = {};
                    state.appearance.clothing[bucket][slot.id] = current;
                    const result = await nui('updateClothing', {
                        id: slot.id,
                        drawable,
                        texture: current.texture,
                        prop,
                    });
                    if (result && result.textureMax !== undefined) {
                        limit.texture = result.textureMax;
                    }
                    playSound('value');
                },
                (texture) => {
                    current.texture = texture;
                    if (!state.appearance.clothing[bucket]) state.appearance.clothing[bucket] = {};
                    state.appearance.clothing[bucket][slot.id] = current;
                    nui('updateClothing', {
                        id: slot.id,
                        drawable: current.drawable,
                        texture,
                        prop,
                    });
                }
            );
            fields.appendChild(block);
        });
    }

    function renderFields() {
        fields.innerHTML = '';
        const key = currentCategory();
        if (key === 'identity') renderIdentity();
        if (key === 'heritage') renderHeritage();
        if (key === 'face') renderFace();
        if (key === 'hair') renderHair();
        if (key === 'eyes') renderEyes();
        if (key === 'skin') renderSkin();
        if (key === 'makeup') renderMakeup();
        if (key === 'clothing') renderSlots(state.clothingSlots, false);
        if (key === 'accessories') renderSlots(state.accessorySlots, true);
    }

    async function next() {
        if (currentCategory() === 'identity') {
            const error = validateIdentity();
            if (error) {
                playSound('error');
                toast(t(error, 'Valeur invalide'), 'error');
                return;
            }
        }
        if (categoryIndex >= state.categories.length - 1) {
            const confirmed = await openModal(t('ui.confirm_title', 'Valider ?'), t('ui.confirm_text', 'Entrer en ville'));
            if (!confirmed) return;
            const result = await nui('saveCharacter', {
                identity: state.identity,
                appearance: state.appearance,
            });
            if (!result.ok) {
                playSound('error');
                toast(t(result.error || 'notify.save_error', 'Erreur de sauvegarde'), 'error');
                return;
            }
            playSound('success');
            return;
        }
        setCategory(categoryIndex + 1);
    }

    async function cancel() {
        if (state.allowCancel === false) return;
        const confirmed = await openModal(t('ui.cancel_title', 'Annuler ?'), t('ui.cancel_text', 'Quitter la création'));
        if (!confirmed) return;
        nui('cancelCreator');
    }

    async function reset() {
        const result = await nui('resetCharacter');
        if (result && result.appearance) {
            state.appearance = result.appearance;
            if (result.limits) state.limits = result.limits;
            renderFields();
        }
        playSound('click');
    }

    function bindUi() {
        document.getElementById('btn-next').addEventListener('click', next);
        document.getElementById('btn-prev').addEventListener('click', () => setCategory(categoryIndex - 1));
        document.getElementById('btn-cancel').addEventListener('click', cancel);
        document.getElementById('btn-reset').addEventListener('click', reset);
        document.getElementById('modal-yes').addEventListener('click', () => closeModal(true));
        document.getElementById('modal-no').addEventListener('click', () => closeModal(false));

        document.querySelectorAll('[data-rotate]').forEach((button) => {
            button.addEventListener('click', () => {
                const value = button.getAttribute('data-rotate');
                if (value === 'reset') nui('rotateCharacter', { action: 'reset' });
                else nui('rotateCharacter', { action: 'add', delta: Number(value) });
                playSound('click');
            });
        });

        const stage = document.getElementById('stage');
        stage.addEventListener('mousedown', (event) => {
            if (event.button !== 0) return;
            dragging = true;
            lastX = event.clientX;
        });
        window.addEventListener('mouseup', () => { dragging = false; });
        window.addEventListener('mousemove', (event) => {
            if (!dragging) return;
            const delta = (lastX - event.clientX) * 0.6;
            lastX = event.clientX;
            nui('rotateCharacter', { action: 'add', delta });
        });

        window.addEventListener('keydown', (event) => {
            if (!state || app.classList.contains('hidden')) return;
            const tag = (event.target && event.target.tagName) || '';
            if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
            if (event.key === 'ArrowLeft' || event.key === 'a' || event.key === 'A') {
                nui('rotateCharacter', { action: 'add', delta: 4 });
            }
            if (event.key === 'ArrowRight' || event.key === 'd' || event.key === 'D') {
                nui('rotateCharacter', { action: 'add', delta: -4 });
            }
            if (event.key === 'r' || event.key === 'R') {
                nui('rotateCharacter', { action: 'reset' });
            }
        });
    }

    function open(payload) {
        state = payload;
        categoryIndex = 0;
        app.classList.remove('hidden');
        app.setAttribute('aria-hidden', 'false');
        document.getElementById('btn-reset').textContent = t('ui.reset', 'Réinitialiser');
        document.getElementById('btn-cancel').textContent = t('ui.cancel', 'Annuler');
        document.getElementById('btn-prev').textContent = t('ui.previous', 'Retour');
        document.getElementById('btn-next').textContent = t('ui.next', 'Continuer');
        renderNav();
        setCategory(0);
    }

    function close() {
        app.classList.add('hidden');
        app.setAttribute('aria-hidden', 'true');
        modal.classList.add('hidden');
        state = null;
    }

    window.addEventListener('message', (event) => {
        const { action, data } = event.data || {};
        if (action === 'open') open(data);
        if (action === 'close') close();
        if (action === 'limits' && state) state.limits = data;
        if (action === 'appearance' && state) {
            state.appearance = data;
            if (currentCategory() === 'clothing' || currentCategory() === 'accessories' || currentCategory() === 'identity') {
                renderFields();
            }
        }
    });

    document.getElementById('btn-reset').textContent = 'Réinitialiser';
    document.getElementById('btn-cancel').textContent = 'Annuler';
    document.getElementById('btn-prev').textContent = 'Retour';
    document.getElementById('btn-next').textContent = 'Continuer';
    bindUi();
    nui('ready');
})();
