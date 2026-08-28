(() => {
    const locales = {
        ui: {
            title: 'Création de personnage',
            step: 'Étape',
            of: 'sur',
            previous: 'Retour',
            next: 'Continuer',
            confirm: 'Confirmer',
            cancel: 'Annuler',
            reset: 'Réinitialiser',
            confirm_title: 'Valider ce personnage ?',
            confirm_text: 'Cette apparence sera enregistrée et vous entrerez en ville.',
            cancel_title: 'Annuler la création ?',
            cancel_text: 'Les modifications non enregistrées seront perdues. Une sauvegarde temporaire peut être conservée.',
            play: 'Entrer en ville',
            create: 'Créer un personnage',
            continue: 'Continuer',
            required_fields: 'Veuillez remplir tous les champs obligatoires.',
            identity_title: 'Création du personnage',
            identity_subtitle: 'Informations personnelles',
            identity_hint: 'Ces informations seront enregistrées sur votre personnage. L’apparence se configure ensuite.',
            delete: 'Supprimer',
            empty_slot: 'Emplacement libre',
            slot: 'Emplacement',
            no_character: 'Aucun personnage sur cet emplacement',
            cash: 'Espèces',
            bank: 'Banque',
            job: 'Emploi',
        },
        categories: {
            identity: 'Identité',
            heritage: 'Parents',
            face: 'Visage',
            hair: 'Cheveux',
            eyes: 'Yeux',
            skin: 'Peau',
            makeup: 'Maquillage',
            clothing: 'Vêtements',
            accessories: 'Accessoires',
        },
        identity: {
            firstname: 'Prénom',
            lastname: 'Nom',
            birthdate: 'Date de naissance',
            gender: 'Sexe',
            male: 'Homme',
            female: 'Femme',
            height: 'Taille',
            height_unit: 'cm',
            nationality: 'Nationalité',
            day: 'JJ',
            month: 'MM',
            year: 'AAAA',
        },
        notify: {
            invalid_firstname: 'Prénom invalide.',
            invalid_lastname: 'Nom invalide.',
            invalid_birthdate: 'Date de naissance invalide.',
            invalid_age: 'Âge invalide pour ce serveur.',
            invalid_height: 'Taille invalide.',
            invalid_nationality: 'Nationalité invalide.',
            save_error: 'Impossible d’enregistrer le personnage.',
        },
    };

    const payload = {
        mode: 'create',
        first: true,
        allowCancel: true,
        identity: {
            firstname: 'Léa',
            lastname: 'Moreau',
            birthdate: '1998-04-12',
            gender: 1,
            height: 172,
            nationality: 'Française',
        },
        appearance: {
            model: 'mp_f_freemode_01',
            heritage: { mother: 31, father: 0, resemblance: 0.42, faceResemblance: 0.42, skinMix: 0.35 },
            face: {
                noseWidth: 0.12, nosePeakHeight: -0.08, nosePeakLength: 0.05, noseBoneHeight: 0.0,
                nosePeakLowering: 0.0, noseBoneTwist: 0.0, eyebrowHeight: 0.1, eyebrowDepth: 0.05,
                cheekboneHeight: 0.18, cheekboneWidth: 0.1, cheeksWidth: -0.05, eyesOpening: 0.12,
                lipsThickness: 0.08, jawBoneWidth: -0.04, jawBoneLength: 0.02, chinBoneLowering: 0.0,
                chinBoneLength: 0.04, chinBoneWidth: 0.0, chinDimple: 0.0, neckThickness: 0.0,
            },
            hair: { style: 15, texture: 0, color: 4, highlight: 2 },
            overlays: {
                blemishes: { style: 0, opacity: 0, color: 0, secondColor: 0 },
                beard: { style: 0, opacity: 0, color: 0, secondColor: 0 },
                eyebrows: { style: 3, opacity: 1, color: 4, secondColor: 0 },
                ageing: { style: 0, opacity: 0, color: 0, secondColor: 0 },
                makeup: { style: 2, opacity: 0.35, color: 8, secondColor: 0 },
                blush: { style: 1, opacity: 0.2, color: 6, secondColor: 0 },
                complexion: { style: 0, opacity: 0, color: 0, secondColor: 0 },
                sunDamage: { style: 0, opacity: 0, color: 0, secondColor: 0 },
                lipstick: { style: 2, opacity: 0.45, color: 12, secondColor: 0 },
                moles: { style: 0, opacity: 0, color: 0, secondColor: 0 },
                chestHair: { style: 0, opacity: 0, color: 0, secondColor: 0 },
                bodyBlemishes: { style: 0, opacity: 0, color: 0, secondColor: 0 },
            },
            eyes: { color: 3, size: 0.1, opening: 0.12, position: 0.05 },
            clothing: {
                components: {
                    1: { drawable: 0, texture: 0 },
                    3: { drawable: 15, texture: 0 },
                    4: { drawable: 15, texture: 3 },
                    5: { drawable: 0, texture: 0 },
                    6: { drawable: 35, texture: 0 },
                    7: { drawable: 0, texture: 0 },
                    8: { drawable: 14, texture: 0 },
                    9: { drawable: 0, texture: 0 },
                    10: { drawable: 0, texture: 0 },
                    11: { drawable: 15, texture: 3 },
                },
                props: {
                    0: { drawable: -1, texture: -1 },
                    1: { drawable: -1, texture: -1 },
                    2: { drawable: -1, texture: -1 },
                    6: { drawable: -1, texture: -1 },
                    7: { drawable: -1, texture: -1 },
                },
            },
        },
        categories: ['identity', 'heritage', 'face', 'hair', 'eyes', 'skin', 'makeup', 'clothing', 'accessories'],
        locales,
        parents: {
            fathers: [
                { id: 0, label: 'Benjamin' }, { id: 4, label: 'Andrew' }, { id: 15, label: 'Michael' },
            ],
            mothers: [
                { id: 21, label: 'Hannah' }, { id: 31, label: 'Sophia' }, { id: 41, label: 'Emma' },
            ],
        },
        nationalities: [
            'Française', 'Américaine', 'Anglaise', 'Espagnole', 'Italienne',
            'Allemande', 'Belge', 'Canadienne', 'Portugaise', 'Néerlandaise',
            'Suisse', 'Australienne', 'Autre',
        ],
        limits: {
            hair: 40,
            hairColors: 63,
            makeupColors: 63,
            overlays: {
                blemishes: 23, beard: 28, eyebrows: 33, ageing: 14, makeup: 74, blush: 6,
                complexion: 11, sunDamage: 10, lipstick: 9, moles: 17, chestHair: 16, bodyBlemishes: 11,
            },
            clothing: {
                components: {
                    1: { drawable: 20, texture: 4 }, 3: { drawable: 40, texture: 4 }, 4: { drawable: 50, texture: 8 },
                    5: { drawable: 20, texture: 4 }, 6: { drawable: 40, texture: 6 }, 7: { drawable: 30, texture: 4 },
                    8: { drawable: 40, texture: 8 }, 9: { drawable: 20, texture: 4 }, 10: { drawable: 20, texture: 4 },
                    11: { drawable: 60, texture: 8 },
                },
                props: {
                    0: { drawable: 20, texture: 6 }, 1: { drawable: 16, texture: 6 }, 2: { drawable: 10, texture: 4 },
                    6: { drawable: 12, texture: 4 }, 7: { drawable: 10, texture: 4 },
                },
            },
        },
        clothingSlots: [
            { key: 'mask', label: 'Masque', type: 'component', id: 1 },
            { key: 'arms', label: 'Bras', type: 'component', id: 3 },
            { key: 'pants', label: 'Pantalon', type: 'component', id: 4 },
            { key: 'bags', label: 'Sacs', type: 'component', id: 5 },
            { key: 'shoes', label: 'Chaussures', type: 'component', id: 6 },
            { key: 'chains', label: 'Chaînes', type: 'component', id: 7 },
            { key: 'undershirt', label: 'Sous-vêtements', type: 'component', id: 8 },
            { key: 'vest', label: 'Veste', type: 'component', id: 9 },
            { key: 'decals', label: 'Accessoires', type: 'component', id: 10 },
            { key: 'tops', label: 'Haut', type: 'component', id: 11 },
        ],
        accessorySlots: [
            { key: 'hat', label: 'Chapeau', type: 'prop', id: 0 },
            { key: 'glasses', label: 'Lunettes', type: 'prop', id: 1 },
            { key: 'ears', label: 'Oreilles', type: 'prop', id: 2 },
            { key: 'watches', label: 'Montres', type: 'prop', id: 6 },
            { key: 'bracelets', label: 'Bracelets', type: 'prop', id: 7 },
        ],
        config: {
            minAge: 18, maxAge: 80, minHeight: 150, maxHeight: 200, defaultHeight: 180,
            minName: 2, maxName: 20, sound: false, volume: 0.3,
            enableMakeup: true, enableClothing: true, enableAccessories: true,
        },
    };

    window.addEventListener('load', () => {
        const createPayload = payload;
        const selectPayload = {
            characters: [
                {
                    citizenid: 'ABC12345',
                    cid: 1,
                    charinfo: {
                        firstname: 'Léa',
                        lastname: 'Moreau',
                        birthdate: '1998-04-12',
                        nationality: 'Française',
                        gender: 1,
                    },
                    money: { cash: 1250, bank: 18400 },
                    job: { label: 'Citoyenne', grade: 'Civil' },
                },
            ],
            slots: 3,
            enableDelete: true,
            translations: payload.locales,
        };

        const identityPayload = {
            allowCancel: true,
            identity: {
                firstname: '',
                lastname: '',
                birthdate: '',
                height: '',
                nationality: '',
            },
            nationalities: createPayload.nationalities,
            locales,
            config: createPayload.config,
        };

        const rcoreMock = document.getElementById('rcore-mock');
        const spawnMock = document.getElementById('spawn-mock');

        function openIdentityPreview(data) {
            document.getElementById('select').classList.add('hidden');
            document.getElementById('app').classList.add('hidden');
            rcoreMock.classList.add('hidden');
            spawnMock.classList.add('hidden');
            window.postMessage({ action: 'openIdentity', data: data || identityPayload }, '*');
        }

        window.addEventListener('message', (event) => {
            const { action, data } = event.data || {};
            if (action !== 'previewRcore') return;
            rcoreMock.classList.remove('hidden');
            rcoreMock.setAttribute('aria-hidden', 'false');
            const summary = document.getElementById('rcore-mock-identity');
            if (data) {
                summary.textContent = `${data.firstname} ${data.lastname} · ${data.birthdate} · ${data.nationality} · ${data.height} cm`;
            }
        });

        document.getElementById('rcore-mock-save').addEventListener('click', () => {
            rcoreMock.classList.add('hidden');
            spawnMock.classList.remove('hidden');
            const summary = document.getElementById('rcore-mock-identity');
            document.getElementById('spawn-mock-text').textContent = summary.textContent
                ? `Spawn : ${summary.textContent} + apparence rCore Clothing.`
                : 'Le personnage entre en ville avec l’identité Qbox et l’apparence rCore Clothing.';
        });

        document.getElementById('btn-play').addEventListener('click', () => {
            const playBtn = document.getElementById('btn-play');
            if (playBtn.textContent.includes('Créer')) {
                openIdentityPreview(identityPayload);
            }
        });

        document.getElementById('btn-identity-back').addEventListener('click', () => {
            window.postMessage({ action: 'select', data: selectPayload }, '*');
        });

        if (window.location.hash === '#studio') {
            window.postMessage({ action: 'open', data: createPayload }, '*');
            return;
        }
        if (window.location.hash === '#create') {
            openIdentityPreview(identityPayload);
            return;
        }

        window.postMessage({ action: 'select', data: selectPayload }, '*');
    });

    document.addEventListener('click', (event) => {
        const button = event.target.closest('[data-rotate]');
        if (!button) return;
        const figure = document.getElementById('preview-character');
        if (!figure) return;
        const current = Number(figure.dataset.angle || 0);
        const value = button.getAttribute('data-rotate');
        const next = value === 'reset' ? 0 : current + Number(value) * 3;
        figure.dataset.angle = String(next);
        figure.style.transform = `rotateY(${next}deg)`;
    });
})();
