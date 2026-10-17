// aurora-rims: entry points. Every mapped window gets a CRimDecoration;
// Hyprland removes them again when the plugin unloads.
#include "Rim.hpp"

#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>

static HANDLE              g_handle = nullptr;
static CHyprSignalListener g_onOpen, g_onFocus, g_onMonitorGone;
static PHLWINDOWREF        g_focused;

static Aurora::CRimDecoration* rimOf(const PHLWINDOW& w) {
    if (w)
        for (const auto& d : w->m_windowDecorations)
            if (const auto rim = dynamic_cast<Aurora::CRimDecoration*>(d.get()))
                return rim;
    return nullptr;
}

static void addRim(const PHLWINDOW& w) {
    if (Desktop::View::validMapped(w) && !rimOf(w))
        HyprlandAPI::addWindowDecoration(g_handle, w, makeUnique<Aurora::CRimDecoration>(w));
}

// The focused rim is brighter: repaint the one losing focus and the one gaining it.
static void onFocus(const PHLWINDOW& w) {
    for (const auto& changed : {g_focused.lock(), w})
        if (const auto rim = rimOf(changed))
            rim->damageEntire();
    g_focused = w;
}

APICALL EXPORT std::string pluginAPIVersion() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO pluginInit(HANDLE handle) {
    g_handle = handle;

    // Built against another Hyprland: refuse to load instead of crashing it.
    if (__hyprland_api_get_hash() != std::string{__hyprland_api_get_client_hash()}) {
        HyprlandAPI::addNotification(handle, "[aurora-rims] built for a different Hyprland; rebuild it", CHyprColor{1.f, 0.2f, 0.2f, 1.f}, 5000);
        throw std::runtime_error("[aurora-rims] version mismatch");
    }

    Aurora::g_rims = makeUnique<Aurora::CRims>();
    for (const auto& w : Desktop::windowState()->windows())
        addRim(w);
    g_onOpen        = Event::bus()->m_events.window.open.listen([](PHLWINDOW w) { addRim(w); });
    g_onFocus       = Event::bus()->m_events.window.active.listen([](PHLWINDOW w, Desktop::eFocusReason) { onFocus(w); });
    g_onMonitorGone = Event::bus()->m_events.monitor.destroyMon.listen([](PHLMONITOR m) { Aurora::g_rims->forget(m->m_id); });

    return {"aurora-rims", "Liquid glass rims on every window", "aurora", "0.1.0"};
}

APICALL EXPORT void pluginExit() {
    g_onOpen.reset();
    g_onFocus.reset();
    g_onMonitorGone.reset();
    Aurora::g_rims.reset();
}
