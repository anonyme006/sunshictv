window.CreatorControls = (function () {
    function el(tag, className, html) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (html !== undefined) node.innerHTML = html;
        return node;
    }

    function fieldShell(label) {
        const wrap = el('label', 'field');
        const title = el('span', 'field-label', label);
        wrap.appendChild(title);
        return wrap;
    }

    function input(options, onChange) {
        const wrap = fieldShell(options.label);
        const control = el('input', 'text-input');
        control.type = options.type || 'text';
        control.value = options.value ?? '';
        control.placeholder = options.placeholder || '';
        if (options.min !== undefined) control.min = options.min;
        if (options.max !== undefined) control.max = options.max;
        if (options.maxlength) control.maxLength = options.maxlength;
        control.addEventListener('input', () => onChange(control.value));
        wrap.appendChild(control);
        return wrap;
    }

    function select(options, onChange) {
        const wrap = fieldShell(options.label);
        const control = el('select', 'select-input');
        (options.items || []).forEach((item) => {
            const opt = document.createElement('option');
            opt.value = item.value;
            opt.textContent = item.label;
            if (String(item.value) === String(options.value)) opt.selected = true;
            control.appendChild(opt);
        });
        control.addEventListener('change', () => onChange(control.value));
        wrap.appendChild(control);
        return wrap;
    }

    function slider(options, onChange) {
        const wrap = fieldShell(options.label);
        const row = el('div', 'slider-row');
        const control = el('input', 'range-input');
        control.type = 'range';
        control.min = options.min;
        control.max = options.max;
        control.step = options.step ?? 1;
        control.value = options.value ?? options.min;
        const value = el('span', 'slider-value', formatValue(control.value, options));
        control.addEventListener('input', () => {
            value.textContent = formatValue(control.value, options);
            onChange(Number(control.value));
        });
        row.appendChild(control);
        row.appendChild(value);
        wrap.appendChild(row);
        return wrap;
    }

    function formatValue(value, options) {
        const number = Number(value);
        if (options.labels && options.labels[number] !== undefined) return options.labels[number];
        if (options.percent) return `${Math.round(number * 100)}%`;
        if (options.step && Number(options.step) < 1) return number.toFixed(2);
        return String(Math.round(number));
    }

    function pair(label, drawable, texture, onDrawable, onTexture) {
        const wrap = el('div', 'pair-field');
        wrap.appendChild(el('p', 'field-label', label));
        const grid = el('div', 'pair-grid');
        grid.appendChild(slider({ label: 'Modèle', min: drawable.min, max: drawable.max, step: 1, value: drawable.value }, onDrawable));
        grid.appendChild(slider({ label: 'Texture', min: texture.min, max: texture.max, step: 1, value: texture.value }, onTexture));
        wrap.appendChild(grid);
        return wrap;
    }

    return { el, input, select, slider, pair };
})();
