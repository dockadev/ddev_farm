const skillState = {
    active: false,
    pressed: false,
    startTime: 0,
    duration: 3200,
    period: 1500,
    zoneWidth: 18,
    zoneLeft: 0,
    rafId: null,
    resultShown: false,
};

const scContainer = document.getElementById('skillcheck-container');
const scBar = document.getElementById('skillcheck-bar');
const scZone = document.getElementById('skillcheck-zone');
const scCursor = document.getElementById('skillcheck-cursor');
const scHint = document.getElementById('skillcheck-hint');

function cursorRatio() {
    const elapsed = performance.now() - skillState.startTime;
    const phase = (elapsed % skillState.period) / skillState.period;

    return 0.5 - 0.5 * Math.cos(phase * Math.PI * 2);
}

function animateSkillCheck() {
    if (!skillState.active) return;

    const ratio = cursorRatio();

    if (scCursor) {
        scCursor.style.left = `${ratio * 100}%`;
    }

    const elapsed = performance.now() - skillState.startTime;
    if (elapsed >= skillState.duration) {
        finishSkillCheck('miss');
        return;
    }

    skillState.rafId = requestAnimationFrame(animateSkillCheck);
}

function randomizeZone() {
    const width = skillState.zoneWidth;

    const maxLeft = 100 - width;
    const margin = 4;

    const left = margin + Math.random() * Math.max(0, maxLeft - margin * 2);

    skillState.zoneLeft = left;

    if (scZone) {
        scZone.style.left = `${left}%`;
        scZone.style.width = `${width}%`;
    }
}

function openSkillCheck(data) {
    const options = data || {};

    skillState.active = true;
    skillState.pressed = false;
    skillState.resultShown = false;
    skillState.startTime = performance.now();
    skillState.duration = options.duration || 3200;
    skillState.period = options.period || 1500;
    skillState.zoneWidth = options.zoneWidth || 18;

    randomizeZone();

    if (scCursor) {
        scCursor.style.left = '0%';
    }

    if (scHint) {
        scHint.textContent = options.label || t('skillcheckHint');
    }

    if (scContainer) {
        scContainer.classList.remove('hidden');
    }

    animateSkillCheck();
}

function closeSkillCheck() {
    skillState.active = false;

    if (skillState.rafId) {
        cancelAnimationFrame(skillState.rafId);
        skillState.rafId = null;
    }

    if (scContainer) {
        scContainer.classList.add('hidden');
    }
}

function evaluateSkillCheck() {
    if (!scCursor || !scZone) return 'miss';

    const cursorRect = scCursor.getBoundingClientRect();
    const zoneRect = scZone.getBoundingClientRect();

    const overlap = cursorRect.right >= zoneRect.left && cursorRect.left <= zoneRect.right;

    if (!overlap) return 'miss';

    const cursorCenter = cursorRect.left + cursorRect.width / 2;
    const zoneCenter = zoneRect.left + zoneRect.width / 2;
    const halfZone = zoneRect.width / 2;

    const distance = Math.abs(cursorCenter - zoneCenter);

    return distance <= halfZone / 2 ? 'perfect' : 'good';
}

function finishSkillCheck(tier) {
    if (!skillState.active || skillState.pressed) return;

    skillState.pressed = true;
    closeSkillCheck();

    fetch('https://ddev_farm/skillcheckResult', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            nodeId: skillState.nodeId,
            branchIndex: skillState.branchIndex,
            tier: tier,
        }),
    });
}

window.addEventListener('keydown', function (e) {
    if (e.code !== 'KeyE') return;
    if (!skillState.active || skillState.pressed) return;

    const tier = evaluateSkillCheck();
    finishSkillCheck(tier);
});

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'openSkillCheck') {
        skillState.nodeId = data.nodeId;
        skillState.branchIndex = data.branchIndex || 0;
        openSkillCheck(data);
    } else if (data.action === 'closeSkillCheck') {
        closeSkillCheck();
    }
});
