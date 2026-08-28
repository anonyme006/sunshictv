(() => {
    const screen = document.getElementById('identity');
    if (!screen) return;

    const form = document.getElementById('identity-form');
    const errorNode = document.getElementById('identity-error');
    const firstnameInput = document.getElementById('id-firstname');
    const lastnameInput = document.getElementById('id-lastname');
    const daySelect = document.getElementById('id-day');
    const monthSelect = document.getElementById('id-month');
    const yearSelect = document.getElementById('id-year');
    const nationalitySelect = document.getElementById('id-nationality');
    const heightSelect = document.getElementById('id-height');
    const continueBtn = document.getElementById('btn-identity-continue');
    const backBtn = document.getElementById('btn-identity-back');

    let state = null;
    let submitting = false;

    function resourceName() {
        return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx-charactercreator';
    }

    async function nui(name, data) {
        if (window.CREATOR_PREVIEW) {
            return { ok: true };
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

    function showError(message) {
        errorNode.textContent = message;
        errorNode.classList.remove('hidden');
        screen.classList.add('has-error');
    }

    function clearError() {
        errorNode.textContent = '';
        errorNode.classList.add('hidden');
        screen.classList.remove('has-error');
    }

    function fillSelect(select, items, selected) {
        select.innerHTML = '';
        items.forEach((item) => {
            const option = document.createElement('option');
            option.value = item.value;
            option.textContent = item.label;
            if (String(item.value) === String(selected)) option.selected = true;
            select.appendChild(option);
        });
    }

    function parseBirthdate(value) {
        if (!value) return { day: '', month: '', year: '' };
        const iso = String(value).match(/^(\d{4})-(\d{2})-(\d{2})$/);
        if (iso) return { year: iso[1], month: iso[2], day: iso[3] };
        const fr = String(value).match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
        if (fr) return { day: fr[1], month: fr[2], year: fr[3] };
        return { day: '', month: '', year: '' };
    }

    function daysInMonth(year, month) {
        const y = Number(year);
        const m = Number(month);
        if (!y || !m) return 31;
        return new Date(y, m, 0).getDate();
    }

    function pad(value) {
        return String(value).padStart(2, '0');
    }

    function renderDate(identity) {
        const cfg = state.config || {};
        const now = new Date();
        const maxYear = now.getFullYear() - (cfg.minAge || 18);
        const minYear = now.getFullYear() - (cfg.maxAge || 80);
        const parsed = parseBirthdate(identity && identity.birthdate);
        const hasDate = Boolean(parsed.year && parsed.month && parsed.day);
        const year = hasDate ? parsed.year : '';
        const month = hasDate ? parsed.month : '';
        const maxDay = daysInMonth(year || 2000, month || 1);
        const day = hasDate && Number(parsed.day) <= maxDay ? parsed.day : '';

        const days = [{ value: '', label: t('identity.day', 'JJ') }];
        for (let i = 1; i <= maxDay; i += 1) days.push({ value: pad(i), label: pad(i) });
        const months = [{ value: '', label: t('identity.month', 'MM') }];
        for (let i = 1; i <= 12; i += 1) months.push({ value: pad(i), label: pad(i) });
        const years = [{ value: '', label: t('identity.year', 'AAAA') }];
        for (let y = maxYear; y >= minYear; y -= 1) years.push({ value: String(y), label: String(y) });

        fillSelect(daySelect, days, day);
        fillSelect(monthSelect, months, month);
        fillSelect(yearSelect, years, year);
    }

    function currentBirthdate() {
        const day = daySelect.value;
        const month = monthSelect.value;
        const year = yearSelect.value;
        if (!day || !month || !year) return '';
        return `${year}-${month}-${day}`;
    }

    function refreshDays() {
        const year = yearSelect.value;
        const month = monthSelect.value;
        const previous = daySelect.value;
        const maxDay = daysInMonth(year || 2000, month || 1);
        const days = [{ value: '', label: t('identity.day', 'JJ') }];
        for (let i = 1; i <= maxDay; i += 1) days.push({ value: pad(i), label: pad(i) });
        fillSelect(daySelect, days, Number(previous) <= maxDay ? previous : '');
    }

    function collectIdentity() {
        return {
            firstname: (firstnameInput.value || '').trim(),
            lastname: (lastnameInput.value || '').trim(),
            birthdate: currentBirthdate(),
            nationality: nationalitySelect.value || '',
            height: Number(heightSelect.value),
        };
    }

    function isValidDate(iso) {
        const match = String(iso || '').match(/^(\d{4})-(\d{2})-(\d{2})$/);
        if (!match) return false;
        const year = Number(match[1]);
        const month = Number(match[2]);
        const day = Number(match[3]);
        const date = new Date(year, month - 1, day);
        if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
            return false;
        }
        const today = new Date();
        let age = today.getFullYear() - year;
        if (today.getMonth() + 1 < month || (today.getMonth() + 1 === month && today.getDate() < day)) {
            age -= 1;
        }
        const minAge = (state.config && state.config.minAge) || 18;
        const maxAge = (state.config && state.config.maxAge) || 80;
        return age >= minAge && age <= maxAge;
    }

    function validate(identity) {
        const min = (state.config && state.config.minName) || 2;
        const max = (state.config && state.config.maxName) || 20;
        const minHeight = (state.config && state.config.minHeight) || 150;
        const maxHeight = (state.config && state.config.maxHeight) || 200;
        const nameRe = /^[\p{L}'\- ]+$/u;
        const required = t('ui.required_fields', 'Veuillez remplir tous les champs obligatoires.');

        if (!identity.firstname || identity.firstname.length < min || identity.firstname.length > max || !nameRe.test(identity.firstname)) {
            return identity.firstname ? t('notify.invalid_firstname', required) : required;
        }
        if (!identity.lastname || identity.lastname.length < min || identity.lastname.length > max || !nameRe.test(identity.lastname)) {
            return identity.lastname ? t('notify.invalid_lastname', required) : required;
        }
        if (!identity.birthdate) return required;
        if (!isValidDate(identity.birthdate)) return t('notify.invalid_birthdate', 'Date de naissance invalide.');
        if (!identity.nationality) return required;
        if (!Number.isInteger(identity.height) || identity.height < minHeight || identity.height > maxHeight) {
            return identity.height ? t('notify.invalid_height', 'Taille invalide.') : required;
        }
        return null;
    }

    function render(payload) {
        state = payload || {};
        const identity = state.identity || {};
        const cfg = state.config || {};
        const minHeight = cfg.minHeight || 150;
        const maxHeight = cfg.maxHeight || 200;
        const heightUnit = t('identity.height_unit', 'cm');

        document.getElementById('identity-eyebrow').textContent = t('ui.identity_subtitle', 'Informations personnelles');
        document.getElementById('identity-title').textContent = t('ui.identity_title', 'Création du personnage');
        document.getElementById('identity-hint').textContent = t('ui.identity_hint', '');
        document.getElementById('label-firstname').textContent = t('identity.firstname', 'Prénom');
        document.getElementById('label-lastname').textContent = t('identity.lastname', 'Nom');
        document.getElementById('label-birthdate').textContent = t('identity.birthdate', 'Date de naissance');
        document.getElementById('label-nationality').textContent = t('identity.nationality', 'Nationalité');
        document.getElementById('label-height').textContent = t('identity.height', 'Taille');
        continueBtn.textContent = t('ui.continue', t('ui.next', 'Continuer'));
        backBtn.textContent = t('ui.previous', 'Retour');
        backBtn.classList.toggle('hidden', state.allowCancel === false);

        firstnameInput.value = identity.firstname || '';
        firstnameInput.maxLength = cfg.maxName || 20;
        lastnameInput.value = identity.lastname || '';
        lastnameInput.maxLength = cfg.maxName || 20;

        const nationalities = [{ value: '', label: '—' }].concat(
            (state.nationalities || []).map((item) => ({ value: item, label: item }))
        );
        fillSelect(nationalitySelect, nationalities, identity.nationality || '');

        const heights = [{ value: '', label: '—' }];
        for (let h = minHeight; h <= maxHeight; h += 1) {
            heights.push({ value: String(h), label: `${h} ${heightUnit}` });
        }
        fillSelect(heightSelect, heights, identity.height || '');
        renderDate(identity);
        clearError();
    }

    function open(payload) {
        render(payload);
        screen.classList.remove('hidden');
        screen.setAttribute('aria-hidden', 'false');
        firstnameInput.focus();
    }

    function close() {
        screen.classList.add('hidden');
        screen.setAttribute('aria-hidden', 'true');
        submitting = false;
        continueBtn.disabled = false;
        state = null;
        clearError();
    }

    form.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!state || submitting) return;
        const identity = collectIdentity();
        const error = validate(identity);
        if (error) {
            showError(error);
            nui('notify', { message: error, type: 'error' });
            return;
        }

        submitting = true;
        continueBtn.disabled = true;
        const result = await nui('submitIdentity', { identity });
        if (window.CREATOR_PREVIEW) {
            close();
            window.postMessage({ action: 'previewRcore', data: identity }, '*');
            return;
        }
        if (!result || result.ok === false) {
            submitting = false;
            continueBtn.disabled = false;
            const message = t(result && result.error ? result.error : 'ui.required_fields', 'Veuillez remplir tous les champs obligatoires.');
            showError(message);
            return;
        }
    });

    backBtn.addEventListener('click', () => {
        if (state && state.allowCancel === false) return;
        nui('cancelIdentity');
        if (window.CREATOR_PREVIEW) close();
    });

    [firstnameInput, lastnameInput, daySelect, monthSelect, yearSelect, nationalitySelect, heightSelect].forEach((node) => {
        node.addEventListener('input', clearError);
        node.addEventListener('change', clearError);
    });
    monthSelect.addEventListener('change', refreshDays);
    yearSelect.addEventListener('change', refreshDays);

    window.addEventListener('message', (event) => {
        const { action, data } = event.data || {};
        if (action === 'openIdentity') open(data);
        if (action === 'closeIdentity' || action === 'close') close();
    });
})();
