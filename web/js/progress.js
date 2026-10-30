const ProgressState = {
    active: false,
    paused: false,
    duration: 0,
    elapsed: 0,
    lastTick: 0,
    rafId: null,
    canceled: false,
};

const progressContainer = document.getElementById('progress-container');
const progressPanel = document.getElementById('progress-panel');
const progressFill = document.getElementById('progress-fill');
const progressLabel = document.getElementById('progress-label');
const progressPercent = document.getElementById('progress-percent');
const progressIcon = document.getElementById('progress-icon');
const progressDots = document.getElementById('progress-dots');
const progressCheck = document.getElementById('progress-check');
const progressResult = document.getElementById('progress-result');
const progressCancelHint = document.getElementById('progress-cancel-hint');
const stage1El = document.getElementById('stage-1');
const stage2El = document.getElementById('stage-2');

function setProgressText(percent) {
    const rounded = Math.max(0, Math.min(100, Math.round(percent)));

    if (progressFill) progressFill.style.width = `${rounded}%`;
    if (progressPercent) progressPercent.textContent = `${rounded}%`;
}

function currentPercent() {
    if (ProgressState.duration <= 0) return 100;
    return (ProgressState.elapsed / ProgressState.duration) * 100;
}

function stopTicking() {
    if (ProgressState.rafId) {
        cancelAnimationFrame(ProgressState.rafId);
        ProgressState.rafId = null;
    }
}

function tickProgress() {
    if (!ProgressState.active || ProgressState.paused) return;

    const now = performance.now();
    ProgressState.elapsed += now - ProgressState.lastTick;
    ProgressState.lastTick = now;

    const percent = currentPercent();
    setProgressText(percent);

    if (percent >= 100) {
        ProgressState.active = false;
        stopTicking();
        return;
    }

    ProgressState.rafId = requestAnimationFrame(tickProgress);
}

function applyStage(el, state) {
    if (!el) return;

    el.classList.remove('success', 'fail');

    if (state === 'perfect' || state === 'good') {
        el.classList.add('success');
        el.textContent = '\u2713';
    } else if (state === 'miss') {
        el.classList.add('fail');
        el.textContent = '\u00d7';
    } else {
        el.textContent = el.dataset.label || '';
    }
}

function openProgress(opts) {
    const options = opts || {};

    if (typeof hideHint === 'function') hideHint(true);

    ProgressState.active = true;
    ProgressState.paused = false;
    ProgressState.canceled = false;
    ProgressState.duration = options.duration || 3500;
    ProgressState.elapsed = 0;
    ProgressState.lastTick = performance.now();

    if (progressPanel) {
        progressPanel.classList.remove('completed', 'bonus', 'bonus-upgrade');
    }
    if (progressDots) progressDots.classList.remove('hidden');
    if (progressCheck) progressCheck.classList.add('hidden');
    if (progressResult) {
        progressResult.classList.add('hidden');
        progressResult.textContent = '';
    }

    applyStage(stage1El, 'pending');
    applyStage(stage2El, 'pending');

    if (progressLabel) {
        progressLabel.textContent = options.label || t('progressLabel');
    }

    if (progressCancelHint) {
        progressCancelHint.textContent = t('harvestCancel');
    }

    if (progressIcon) {
        if (options.icon) {
            progressIcon.src = `images/${options.icon}`;
            progressIcon.classList.remove('hidden');

            applyCropAccent(options.icon.split('.')[0]);
        } else {
            progressIcon.classList.add('hidden');
        }
    }

    if (progressContainer) progressContainer.classList.remove('hidden');

    if (progressPanel) {
        progressPanel.classList.remove('enter');
        void progressPanel.offsetWidth;
        progressPanel.classList.add('enter');
    }

    setProgressText(0);
    tickProgress();
}

function pauseProgress() {
    if (!ProgressState.active || ProgressState.paused) return;

    ProgressState.elapsed += performance.now() - ProgressState.lastTick;
    ProgressState.paused = true;

    stopTicking();
    setProgressText(currentPercent());
}

function resumeProgress() {
    if (!ProgressState.active || !ProgressState.paused) return;

    ProgressState.paused = false;
    ProgressState.lastTick = performance.now();

    tickProgress();
}

function setStages(data) {
    if (!data) return;

    applyStage(stage1El, data.stage1);
    applyStage(stage2El, data.stage2);
}

function completeProgress(data) {
    ProgressState.active = false;
    ProgressState.paused = false;
    stopTicking();

    setProgressText(100);

    if (progressPanel) {
        progressPanel.classList.add('completed');

        progressPanel.classList.toggle('bonus', !!(data && data.bonus));
        progressPanel.classList.toggle('bonus-upgrade', !!(data && data.bonus === 'upgrade'));
    }
    if (progressDots) progressDots.classList.add('hidden');
    if (progressCheck) progressCheck.classList.remove('hidden');

    if (progressLabel) progressLabel.textContent = t('progressDone');

    if (progressResult) {
        if (data && data.bonus === 'extra') {
            progressResult.textContent = '+1';
            progressResult.classList.remove('hidden');
        } else if (data && data.bonus === 'upgrade') {
            progressResult.textContent = '\u2191';
            progressResult.classList.remove('hidden');
        } else {
            progressResult.textContent = '';
            progressResult.classList.add('hidden');
        }
    }
}

function closeProgress() {
    ProgressState.active = false;
    ProgressState.paused = false;
    stopTicking();

    if (progressContainer) progressContainer.classList.add('hidden');
    if (progressPanel) progressPanel.classList.remove('completed');
}

function isProgressCanceled() {
    return ProgressState.canceled;
}

window.addEventListener('keydown', function (e) {
    if (!ProgressState.active) return;

    if (e.code === 'KeyX' || e.code === 'Escape') {
        ProgressState.canceled = true;
        closeProgress();

        fetch('https://ddev_farm/cancelProgress', { method: 'POST' });
    }
});

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'openProgress') {
        openProgress(data);
    } else if (data.action === 'pauseProgress') {
        pauseProgress();
    } else if (data.action === 'resumeProgress') {
        resumeProgress();
    } else if (data.action === 'setStages') {
        setStages(data);
    } else if (data.action === 'completeProgress') {
        completeProgress(data);
    } else if (data.action === 'closeProgress') {
        closeProgress();
    } else if (data.action === 'setLocale') {
        I18N.load(data.lang || 'en').then(function () {
            if (typeof renderMarket === 'function') renderMarket();
        });
    }
});
