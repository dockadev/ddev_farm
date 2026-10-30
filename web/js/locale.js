const I18N = {
    lang: 'en',
    strings: {},

    t(key, ...args) {
        let text = this.strings[key];

        if (typeof text !== 'string') text = key;

        if (args.length > 0) {
            text = text.replace(/\{(\d+)\}/g, (m, i) => (args[i] !== undefined ? args[i] : m));
        }

        return text;
    },

    apply(root) {
        const scope = root || document;

        scope.querySelectorAll('[data-i18n]').forEach((el) => {
            const key = el.getAttribute('data-i18n');
            const value = this.strings[key];

            if (typeof value === 'string') {
                el.textContent = value;
            }
        });
    },

    async load(lang) {
        this.lang = lang || 'en';

        try {
            const res = await fetch(`locales/${this.lang}.json`);
            this.strings = await res.json();
        } catch (e) {
            this.lang = 'en';
            this.strings = {};
        }

        document.documentElement.lang = this.lang;
        this.apply();
    },
};

function t(key, ...args) {
    return I18N.t(key, ...args);
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { I18N.load('en'); });
} else {
    I18N.load('en');
}
