import QtQuick
import "../core"

/**
 * A number that follows `to` like a damped spring. Bind what should move to
 * `value`:
 *
 *     SpringValue { id: openness; to: menu.open ? 1 : 0; preset: Motion.smooth }
 *     opacity: openness.value
 *
 * The preset is SwiftUI-style { duration, bounce }: angular frequency
 * ω = 2π / duration and damping ratio ζ = 1 − bounce, so bounce 0 settles
 * without overshoot in about `duration` seconds. Retargeting mid-flight keeps
 * the current velocity, which is what makes motion feel continuous and
 * interruptible instead of restarting from rest.
 *
 * Integration is semi-implicit Euler in ≤ 1/240 s substeps, driven by a
 * FrameAnimation that runs only while unsettled, so an idle spring costs
 * nothing. Under Reduce Motion it snaps to the target.
 *
 * Until its first frame a spring jumps to new targets: what settles while
 * an item is being built (another spring placing itself, a press state
 * derived from it) must not play as motion nobody caused — Settings'
 * controls used to wobble each time a page opened. An explicit `snap()`
 * (an entrance that starts somewhere on purpose) animates right away.
 */
QtObject {
    id: root

    property real to: 0
    property var preset: Motion.smooth
    /** Settling threshold in the value's own units. */
    property real epsilon: 0.001

    property real value: 0
    property real velocity: 0
    readonly property bool settled: !driver.running
    property bool born: false

    /**
     * Jump to `v` at rest. If `v` isn't the target, the spring then moves on
     * toward `to` from there — so "start from here" works even when the
     * target was already set and didn't change.
     */
    function snap(v) {
        born = true;
        driver.stop();
        velocity = 0;
        value = v;
        if (value !== to && !Motion.reduced)
            driver.start();
    }

    function settle() {
        driver.stop();
        velocity = 0;
        value = to;
    }

    onToChanged: {
        if (Motion.reduced || !born)
            settle();
        else if (value !== to)
            driver.start();
    }

    Component.onCompleted: settle()
    property FrameAnimation birth: FrameAnimation {
        running: true
        onTriggered: {
            root.born = true;
            stop();
        }
    }

    property FrameAnimation driver: FrameAnimation {
        onTriggered: {
            const omega = 2 * Math.PI / Math.max(0.01, root.preset.duration);
            const zeta = Math.max(0, 1 - root.preset.bounce);
            const step = 1 / 240;
            let left = Math.min(frameTime, 1 / 30); // a long stall shouldn't fling it
            let x = root.value, v = root.velocity;
            while (left > 0) {
                const dt = Math.min(step, left);
                const accel = -omega * omega * (x - root.to) - 2 * zeta * omega * v;
                v += accel * dt;
                x += v * dt;
                left -= dt;
            }
            if (Math.abs(x - root.to) < root.epsilon && Math.abs(v) < root.epsilon * omega) {
                x = root.to;
                v = 0;
                stop();
            }
            root.velocity = v;
            root.value = x;
        }
    }
}
