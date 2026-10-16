pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * aurora's translations. Every string people read goes through `I18n.tr`:
 *
 *     text: I18n.tr("sound.title")
 *     text: I18n.tr("battery.percent", { n: 80 })        // "{n} %"
 *     text: I18n.tr("bluetooth.devices", { count: 3 })   // picks "…_one" / "…_other"
 *
 * Strings live in shell/i18n/<language>.json as flat "area.thing" keys. English
 * is the reference and the fallback: a key missing from the active language
 * shows the English text; one missing everywhere shows the key itself so it's
 * easy to spot. `scripts/check-i18n.py` (also run by `nix flake check`) fails
 * when a key used in QML is missing from any language or the files disagree.
 *
 * Adding a language: copy en.json to <code>.json, translate the values, and
 * add the code to `available` below.
 *
 * Bindings that call tr() re-evaluate when the language changes, because tr()
 * reads `strings` and `fallback`.
 */
Singleton {
    id: root

    /** Languages shipped, in the order a settings picker shows them. */
    readonly property var available: ["en", "es"]

    /** Settings.language ("en", "es"…) or, when empty, the system language. */
    readonly property string language: {
        const wanted = Settings.language.length ? Settings.language : Qt.locale().name.split("_")[0];
        return available.includes(wanted) ? wanted : "en";
    }

    /**
     * Locale for dates, times and numbers: Settings.locale when set, else the
     * language's usual region (Spanish defaults to Argentina, the user's).
     */
    readonly property var locale: Qt.locale(Settings.locale.length ? Settings.locale : ({ en: "en_US", es: "es_AR" })[language] ?? "en_US")

    property var strings: ({})
    property var fallback: ({})

    /** The language's own name, for a picker ("English", "Español"). */
    function nameOf(code) {
        return code === language ? (strings["_meta.name"] ?? code) : code;
    }

    function tr(key, args) {
        let k = key;
        if (args && args.count !== undefined) {
            const plural = key + (args.count === 1 ? "_one" : "_other");
            if (strings[plural] !== undefined || fallback[plural] !== undefined)
                k = plural;
        }
        let s = strings[k] ?? fallback[k] ?? key;
        if (args)
            for (const name in args)
                s = s.split("{" + name + "}").join(String(args[name]));
        return s;
    }

    function parse(view) {
        try {
            return JSON.parse(view.text());
        } catch (e) {
            console.warn("i18n: can't parse", view.path, e);
            return {};
        }
    }

    FileView {
        id: active
        path: Quickshell.shellPath("i18n/" + root.language + ".json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.strings = root.parse(active)
    }

    FileView {
        id: english
        path: Quickshell.shellPath("i18n/en.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.fallback = root.parse(english)
    }
}
