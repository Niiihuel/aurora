import QtQuick

/**
 * The login screen's liquid glass: shell/shaders/glass.frag (compiled into
 * this theme by nix/login.nix) over the wallpaper. The greeter has no live
 * scene to refract, so `frost` is the wallpaper blurred and `sharp` the
 * wallpaper itself, both covering `backdrop` (the whole screen). A smaller
 * version of the shell's components/Glass.qml, without press response.
 */
ShaderEffect {
    id: glass

    required property Item backdrop
    required property var frost
    required property var sharp
    property real cornerRadius: height / 2
    property color veil: Qt.rgba(0.149, 0.149, 0.157, 0.48) // Tokens.glass.regular (dark)
    property real bend: 14 // refraction, points
    property bool edge: true
    /** mapToItem isn't reactive: whatever moves this on screen goes here (as in the shell's Glass). */
    property var track: []
    property bool settled: false
    Component.onCompleted: Qt.callLater(() => settled = true)

    property var source: frost
    property vector2d itemSize: Qt.vector2d(Math.max(1, width), Math.max(1, height))
    property vector4d mapping: {
        void track;
        void settled;
        void width;
        void height;
        const a = glass.mapToItem(backdrop, 0, 0);
        return Qt.vector4d(a.x / backdrop.width, a.y / backdrop.height, width / backdrop.width, height / backdrop.height);
    }
    property vector4d tint: Qt.vector4d(veil.r, veil.g, veil.b, veil.a)
    property vector4d material: Qt.vector4d(bend, 0.5, 2.2, 0) // refraction, dispersion, saturation, dim
    property real radius: cornerRadius
    property real power: cornerRadius >= 0.5 * Math.min(width, height) - 0.5 ? 2 : 4
    property real dpr: Screen.devicePixelRatio
    property vector4d glow: Qt.vector4d(0.5, 0.5, 0, 1)
    property vector4d lens: Qt.vector4d(1, 0, edge ? 1 : 0, 0)

    fragmentShader: "glass.frag.qsb"
}
