import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import "AstralEngine.js" as Engine

DesktopPluginComponent {
    id: root

    minWidth: 200
    minHeight: 80

    // ── Settings (reactive, mirrored from pluginData) ────────────────
    function num(key, def, lo, hi) {
        var v = Number(pluginData[key] ?? def)
        if (!isFinite(v))
            v = def
        return Math.max(lo, Math.min(hi, v))
    }

    // What to show when hyprwhspr is NOT recording:
    //   "dim"    – a faint resting thread of stars, so the widget stays
    //              visible and resizable without having to start dictation
    //   "hidden" – fully transparent (pure overlay; only appears while recording)
    readonly property string idleBehavior: pluginData.idleBehavior ?? "dim"
    readonly property real idleOpacity: num("idleOpacity", 50, 5, 100) / 100
    readonly property real activeOpacity: num("activeOpacity", 100, 10, 100) / 100
    readonly property bool showBackground: pluginData.showBackground ?? false

    readonly property string paletteMode: pluginData.palette ?? "theme"
    readonly property color custom1: pluginData.customColor1 ?? Theme.primary
    readonly property color custom2: pluginData.customColor2 ?? Theme.secondary
    readonly property color custom3: pluginData.customColor3 ?? Theme.tertiary

    readonly property int maxFps: num("maxFps", 60, 15, 240)

    function rgb(c) {
        return [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)]
    }

    readonly property var paletteColors: {
        switch (root.paletteMode) {
        case "astral":
            return [[223, 233, 255], [159, 180, 255], [200, 168, 255]]
        case "ember":
            return [[242, 207, 122], [232, 154, 90], [255, 241, 201]]
        case "primary":
            return [rgb(Theme.primary), rgb(Qt.lighter(Theme.primary, 1.25)), rgb(Theme.primary)]
        case "duo":
            return [rgb(Theme.primary), rgb(Theme.secondary), rgb(Theme.primary)]
        case "custom":
            return [rgb(root.custom1), rgb(root.custom2), rgb(root.custom3)]
        default:
            return [rgb(Theme.primary), rgb(Theme.secondary), rgb(Theme.tertiary)]
        }
    }

    // Everything the engine reads. Re-evaluated whenever any setting changes;
    // the engine merges it in place (grains are only rebuilt on a count change).
    readonly property var engineOptions: ({
        "sensitivity": num("sensitivity", 200, 50, 500) / 100,
        "peakBoost": num("peakBoost", 160, 0, 300) / 100,
        "onsetSparkle": num("onsetSparkle", 100, 0, 200) / 100,
        "motionSpeed": num("motionSpeed", 100, 25, 250) / 100,
        "reactivity": num("reactivity", 150, 0, 300) / 100,
        "rippleSpread": num("rippleSpread", 100, 0, 200) / 100,
        "autoGain": num("autoGain", 70, 0, 100) / 100,
        "starCount": num("starCount", 220, 40, 600),
        "ribbonHeight": num("ribbonHeight", 100, 20, 150) / 100,
        "starSize": num("starSize", 100, 50, 250) / 100,
        "twinkle": num("twinkle", 100, 0, 100) / 100,
        "centerEnvelope": pluginData.centerEnvelope ?? true,
        "bandGlow": num("bandGlow", 100, 0, 200) / 100,
        "driftAmount": num("driftAmount", 100, 0, 300) / 100,
        "driftSpeed": num("driftSpeed", 100, 25, 250) / 100,
        "maxMotes": num("maxMotes", 500, 0, 1500),
        "linkDensity": parseFloat(pluginData.linkDensity ?? "1") || 0,
        "linkReach": num("linkReach", 100, 40, 250) / 100,
        "linkLifetime": num("linkLifetime", 100, 25, 300) / 100,
        "constellations": pluginData.constellations ?? true,
        "exitStyle": pluginData.exitStyle ?? "dissolve",
        "exitDuration": num("exitDuration", 450, 0, 3000) / 1000,
        "glowQuality": parseInt(pluginData.glowQuality ?? "2") || 0,
        "colors": root.paletteColors
    })

    property var engine: Engine.create(engineOptions)

    onEngineOptionsChanged: {
        Engine.configure(root.engine, root.engineOptions)
        if (!root.animating)
            canvas.requestPaint()
    }

    // ── Size from settings sliders (same mechanism as the Voice Overlay) ──
    // Desktop-widget size is stored per-monitor in the instance's "positions".
    // The Width/Height sliders write widthPx/heightPx into the instance config;
    // mirror those into the saved size so the slider resizes the widget live.
    readonly property int cfgWidth: Math.round(pluginData.widthPx ?? 0)
    readonly property int cfgHeight: Math.round(pluginData.heightPx ?? 0)

    onCfgWidthChanged: if (root.cfgWidth > 0) sizeApplyTimer.restart()
    onCfgHeightChanged: if (root.cfgHeight > 0) sizeApplyTimer.restart()

    Timer {
        id: sizeApplyTimer
        interval: 120
        onTriggered: root.applyConfiguredSize()
    }

    function applyConfiguredSize() {
        if (!root.instanceId || root.cfgWidth <= 0 || root.cfgHeight <= 0)
            return
        var positions = (root.instanceData && root.instanceData.positions) ? root.instanceData.positions : {}
        var keys = Object.keys(positions)
        if (keys.length === 0)
            keys = [""]
        for (var i = 0; i < keys.length; i++) {
            var cur = positions[keys[i]] || {}
            if (cur.width === root.cfgWidth && cur.height === root.cfgHeight)
                continue
            SettingsData.updateDesktopWidgetInstancePosition(root.instanceId, keys[i], {
                "width": root.cfgWidth,
                "height": root.cfgHeight
            })
        }
    }

    // On first run, seed the sliders from the widget's actual current size.
    function initSizeFromCurrent() {
        if (!root.instanceId || (pluginData.widthPx ?? 0) > 0)
            return
        var positions = (root.instanceData && root.instanceData.positions) ? root.instanceData.positions : {}
        var w = 0, h = 0
        for (var k in positions) {
            if (positions[k] && positions[k].width) {
                w = positions[k].width
                h = positions[k].height
                break
            }
        }
        if (!w) {
            w = Math.round(root.width) || 520
            h = Math.round(root.height) || 180
        }
        SettingsData.updateDesktopWidgetInstanceConfig(root.instanceId, {
            "widthPx": Math.round(w),
            "heightPx": Math.round(h)
        })
    }

    Component.onCompleted: Qt.callLater(root.initSizeFromCurrent)

    // ── Runtime state ────────────────────────────────────────────────
    property bool recording: false
    property real level: 0.0
    // True while the scene is still moving: recording, or fading out after
    // recording stopped (ribbon settling, motes and links dissolving).
    property bool animating: false
    property real pendingDt: 0
    property real sinceLastPaint: 0

    onRecordingChanged: {
        if (root.recording) {
            root.animating = true
        }
    }

    // ── State + level monitor (same hyprwhspr IPC files as the other widgets) ──
    // All shell builtins (test/read/printf + read-based sleep on a pipe), so the
    // steady state forks no processes. While idle it prints a single "I" on the
    // transition and then stays silent.
    Process {
        id: monitor
        running: true
        command: ["bash", "-c",
            'D="${XDG_CONFIG_HOME:-$HOME/.config}/hyprwhspr"\n'
            + 'exec 9<> <(:)\n'
            + 'snore() { read -t "$1" -u 9 2>/dev/null || :; }\n'
            + 'prev=""\n'
            + 'while :; do\n'
            + '  if [ -e "$D/recording_status" ]; then\n'
            + '    L=0\n'
            + '    { IFS= read -r L < "$D/audio_level"; } 2>/dev/null\n'
            + '    printf "R %s\\n" "${L:-0}"\n'
            + '    prev=R\n'
            + '    snore 0.06\n'
            + '  else\n'
            + '    if [ "$prev" != I ]; then printf "I\\n"; prev=I; fi\n'
            + '    snore 0.35\n'
            + '  fi\n'
            + 'done\n']
        stdout: SplitParser {
            onRead: line => root.onMonitorLine(line)
        }
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 1500
        onTriggered: monitor.running = true
    }

    function onMonitorLine(line) {
        var s = (line || "").trim()
        if (s.length === 0)
            return
        if (s.charAt(0) === "R") {
            root.recording = true
            var v = parseFloat(s.substring(2))
            root.level = isNaN(v) ? 0 : Math.max(0, Math.min(1, v))
        } else {
            root.recording = false
            root.level = 0
        }
    }

    // Frame-synced loop, only while animating. Frames are throttled to maxFps;
    // skipped frames accumulate into the next dt so motion stays real-time.
    FrameAnimation {
        running: root.animating && root.visible
        onTriggered: {
            root.pendingDt += frameTime
            root.sinceLastPaint += frameTime
            if (root.sinceLastPaint >= 1 / root.maxFps - 0.002) {
                root.sinceLastPaint = 0
                canvas.requestPaint()
            }
        }
    }

    // ── Visuals ──────────────────────────────────────────────────────
    readonly property bool idleVisible: !root.animating && root.idleBehavior === "dim"

    onIdleBehaviorChanged: if (!root.animating) canvas.requestPaint()

    opacity: root.animating ? root.activeOpacity : (root.idleBehavior === "hidden" ? 0 : root.idleOpacity)
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
    }

    // Optional backing panel; also shown as a faint outline in the idle
    // placeholder so the resizable bounds are visible.
    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        visible: root.showBackground || root.idleVisible
        color: root.showBackground ? Theme.withAlpha(Theme.surfaceContainer, 0.55)
                                    : Theme.withAlpha(Theme.surfaceContainer, 0.18)
        border.width: 1
        border.color: root.showBackground
            ? Theme.withAlpha(Theme.outline, 0.25)
            : Theme.withAlpha(Theme.primary, 0.28)
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image

        onWidthChanged: if (!root.animating) requestPaint()
        onHeightChanged: if (!root.animating) requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            Engine.setSize(root.engine, width, height)
            if (root.animating) {
                var dt = root.pendingDt
                root.pendingDt = 0
                Engine.frame(root.engine, ctx, dt, root.level, root.recording)
                if (!Engine.isActive(root.engine, root.recording)) {
                    Engine.clear(root.engine)
                    root.animating = false
                    requestPaint()
                }
            } else if (root.idleBehavior === "dim") {
                Engine.drawIdle(root.engine, ctx)
            } else {
                ctx.clearRect(0, 0, width, height)
            }
        }
    }
}
