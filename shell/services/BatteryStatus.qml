pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

/** The laptop battery as UPower's display device reports it. */
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: !!device && device.isPresent && device.isLaptopBattery

    /** 0–1, normalized whatever scale the backend reports. */
    readonly property real level: {
        const p = device ? device.percentage : 0;
        return Math.max(0, Math.min(1, p > 1 ? p / 100 : p));
    }
    readonly property bool charging: !!device && device.state === UPowerDeviceState.Charging
    readonly property bool full: !!device && device.state === UPowerDeviceState.FullyCharged
    readonly property bool pluggedIn: !UPower.onBattery
    /** Low battery: macOS turns the fill red at 10% and below. */
    readonly property bool low: !pluggedIn && level <= 0.10

    /** Seconds until empty (on battery) or full (charging); 0 when unknown. */
    readonly property real timeToEmpty: device ? device.timeToEmpty : 0
    readonly property real timeToFull: device ? device.timeToFull : 0

    /** "3:05"-style hours:minutes for a duration in seconds. */
    function duration(seconds) {
        const m = Math.round(seconds / 60);
        return Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0");
    }

    // --- Energy mode (power-profiles-daemon) -------------------------------------

    /** "saver", "balanced" or "performance". */
    readonly property string mode: PowerProfiles.profile === PowerProfile.PowerSaver ? "saver"
        : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    function setMode(m) {
        PowerProfiles.profile = m === "saver" ? PowerProfile.PowerSaver
            : m === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
    }
}
