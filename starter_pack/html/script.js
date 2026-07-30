(() => {
  const app = document.getElementById('app');
  const canvas = document.getElementById('wheel');
  const ctx = canvas.getContext('2d');
  const btnSpin = document.getElementById('btnSpin');
  const btnClose = document.getElementById('btnClose');
  const resultBox = document.getElementById('resultBox');
  const resultText = document.getElementById('resultText');
  const rangeLabel = document.getElementById('rangeLabel');
  const rateLabel = document.getElementById('rateLabel');

  let wheel = [];
  let rotation = 0;
  let spinning = false;
  let pendingResult = null;
  let animFrame = null;

  const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'starter_pack';

  function formatMoney(n) {
    return new Intl.NumberFormat('fr-FR').format(n) + ' $';
  }

  function drawWheel() {
    const size = canvas.width;
    const cx = size / 2;
    const cy = size / 2;
    const radius = size / 2 - 4;
    const n = Math.max(wheel.length, 1);
    const arc = (Math.PI * 2) / n;

    ctx.clearRect(0, 0, size, size);
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(rotation);

    for (let i = 0; i < n; i++) {
      const start = i * arc - Math.PI / 2;
      const end = start + arc;
      const seg = wheel[i];

      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.arc(0, 0, radius, start, end);
      ctx.closePath();
      ctx.fillStyle = seg.color || (i % 2 === 0 ? '#3d5a4c' : '#2a3d32');
      ctx.fill();
      ctx.strokeStyle = 'rgba(12, 20, 14, 0.65)';
      ctx.lineWidth = 2;
      ctx.stroke();

      ctx.save();
      ctx.rotate(start + arc / 2);
      ctx.textAlign = 'right';
      ctx.fillStyle = '#f2ead8';
      ctx.font = 'bold 22px "Source Sans 3", sans-serif';
      ctx.fillText(formatMoney(seg.amount).replace(' $', ''), radius - 18, 8);
      ctx.restore();
    }

    ctx.restore();
  }

  function setOpen(data) {
    wheel = Array.isArray(data.wheel) && data.wheel.length
      ? data.wheel
      : [
          { amount: 10000, color: '#3d5a4c' },
          { amount: 20000, color: '#c9a227' },
          { amount: 35000, color: '#c44536' },
        ];

    rotation = 0;
    spinning = false;
    pendingResult = null;

    rangeLabel.textContent =
      formatMoney(data.minReward || 10000) + ' – ' + formatMoney(data.maxReward || 35000);

    const rate = Math.round((data.successRate ?? 0.75) * 100);
    rateLabel.textContent = rate + ' %';

    resultBox.classList.add('hidden');
    resultBox.classList.remove('win', 'lose');
    resultText.textContent = '';
    btnSpin.disabled = false;
    btnClose.disabled = false;

    app.classList.remove('hidden');
    app.setAttribute('aria-hidden', 'false');
    drawWheel();
  }

  function setClosed() {
    if (animFrame) {
      cancelAnimationFrame(animFrame);
      animFrame = null;
    }
    spinning = false;
    app.classList.add('hidden');
    app.setAttribute('aria-hidden', 'true');
  }

  /**
   * Pointeur en haut. Après rotation R (radians, sens horaire positif sur canvas),
   * l'index sous le pointeur = floor( ((2π - (R % 2π)) % 2π) / arc )
   * en tenant compte du décalage -π/2 du dessin.
   */
  function indexAtPointer(rot) {
    const n = wheel.length;
    const arc = (Math.PI * 2) / n;
    let normalized = ((rot % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
    // Segments dessinés depuis -π/2 ; pointeur à -π/2 dans le repère monde
    // → angle relatif dans le repère roue :
    const relative = (Math.PI * 2 - normalized) % (Math.PI * 2);
    return Math.floor(relative / arc) % n;
  }

  function targetRotationForAmount(amount, fullSpins) {
    const n = wheel.length;
    const arc = (Math.PI * 2) / n;
    let idx = wheel.findIndex((s) => s.amount === amount);
    if (idx < 0) idx = 0;

    // Centre du segment sous le pointeur
    const centerAngle = idx * arc + arc / 2;
    const desired = (Math.PI * 2 - centerAngle) % (Math.PI * 2);
    const current = ((rotation % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
    let delta = desired - current;
    if (delta < 0) delta += Math.PI * 2;

    return rotation + delta + fullSpins * Math.PI * 2;
  }

  function animateTo(target, durationMs, onDone) {
    const start = performance.now();
    const from = rotation;
    const dist = target - from;

    function easeOutCubic(t) {
      return 1 - Math.pow(1 - t, 3);
    }

    function frame(now) {
      const t = Math.min(1, (now - start) / durationMs);
      rotation = from + dist * easeOutCubic(t);
      drawWheel();

      if (t < 1) {
        animFrame = requestAnimationFrame(frame);
      } else {
        animFrame = null;
        rotation = target;
        drawWheel();
        onDone && onDone();
      }
    }

    animFrame = requestAnimationFrame(frame);
  }

  function showResult(success, amount) {
    resultBox.classList.remove('hidden', 'win', 'lose');
    if (success && amount > 0) {
      resultBox.classList.add('win');
      resultText.textContent = 'Gagné : ' + formatMoney(amount) + ' versés en banque !';
    } else {
      resultBox.classList.add('lose');
      resultText.textContent = 'Perdu… Pas de gain cette fois.';
    }
    btnSpin.disabled = true;
    btnClose.disabled = false;
    spinning = false;
  }

  function playLoseSpin(onDone) {
    // Petite rotation "ratée" sans s'arrêter pile sur un gros lot
    const extra = Math.PI * 2 * (4 + Math.random() * 2) + Math.random() * Math.PI;
    animateTo(rotation + extra, 4200, onDone);
  }

  function playWinSpin(amount, onDone) {
    const target = targetRotationForAmount(amount, 5 + Math.floor(Math.random() * 2));
    animateTo(target, 5200, onDone);
  }

  function post(name, data) {
    return fetch(`https://${resourceName}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({ ok: false }));
  }

  btnSpin.addEventListener('click', () => {
    if (spinning) return;
    spinning = true;
    btnSpin.disabled = true;
    btnClose.disabled = true;
    resultBox.classList.add('hidden');

    post('spin').then((res) => {
      if (!res || !res.ok) {
        spinning = false;
        btnSpin.disabled = false;
        btnClose.disabled = false;
      }
      // Attente du message "result" du client Lua
    });
  });

  btnClose.addEventListener('click', () => {
    if (spinning) return;
    post('close').then(() => setClosed());
  });

  window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
      setOpen(data);
    }

    if (data.action === 'close') {
      setClosed();
    }

    if (data.action === 'result') {
      pendingResult = data;

      if (data.error) {
        showResult(false, 0);
        return;
      }

      if (data.success && data.amount > 0) {
        playWinSpin(data.amount, () => {
          showResult(true, data.amount);
          setTimeout(() => post('done'), 2200);
        });
      } else {
        playLoseSpin(() => {
          showResult(false, 0);
          setTimeout(() => post('done'), 1800);
        });
      }
    }
  });

  // Dessin initial (au cas où)
  drawWheel();
})();
