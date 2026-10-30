import QtQuick
import Qt.labs.folderlistmodel
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

    readonly property string appearance: pluginData.appearance ?? "auto"
    readonly property bool lightMode: appearance === "light" || (appearance === "auto" && SessionData.isLightMode)

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
        "horizon": pluginData.horizon ?? true,
        "horizonOpacity": num("horizonOpacity", 70, 0, 100) / 100,
        "horizonShade": num("horizonShade", 90, 0, 100) / 100,
        "planetSize": num("planetSize", 100, 60, 200) / 100,
        "rimGlow": num("rimGlow", 100, 0, 200) / 100,
        "lightMode": root.lightMode,
        "colors": root.paletteColors
    })

    property var engine: Engine.create(engineOptions)

    onEngineOptionsChanged: {
        Engine.configure(root.engine, root.engineOptions)
        if (!root.animating)
            canvas.requestPaint()
    }

    // ── Size from settings sliders (same mechanism as the Voice Overlay) ──
    // Desktop-widget size is stored per-monitor. Current DMS keeps it in
    // SessionData.desktopWidgetInstancePositions; older releases kept it in the
    // instance's "positions" and updated it through SettingsData.
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

    readonly property bool sessionPositions: typeof SessionData.updateDesktopWidgetInstancePosition === "function"

    function storedPositions() {
        if (root.sessionPositions)
            return (SessionData.desktopWidgetInstancePositions || {})[root.instanceId] || {}
        return (root.instanceData && root.instanceData.positions) ? root.instanceData.positions : {}
    }

    function applyConfiguredSize() {
        if (!root.instanceId || root.cfgWidth <= 0 || root.cfgHeight <= 0)
            return
        var positions = root.storedPositions()
        var keys = Object.keys(positions).filter(k => k.charAt(0) !== "_")
        if (keys.length === 0)
            keys = [""]
        for (var i = 0; i < keys.length; i++) {
            var cur = positions[keys[i]] || {}
            if (cur.width === root.cfgWidth && cur.height === root.cfgHeight)
                continue
            var update = {
                "width": root.cfgWidth,
                "height": root.cfgHeight
            }
            if (root.sessionPositions)
                SessionData.updateDesktopWidgetInstancePosition(root.instanceId, keys[i], update)
            else
                SettingsData.updateDesktopWidgetInstancePosition(root.instanceId, keys[i], update)
        }
    }

    // On first run, seed the sliders from the widget's actual current size.
    function initSizeFromCurrent() {
        if (!root.instanceId || (pluginData.widthPx ?? 0) > 0)
            return
        var positions = root.storedPositions()
        var w = 0, h = 0
        for (var k in positions) {
            if (k.charAt(0) !== "_" && positions[k] && positions[k].width) {
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

    Component.onCompleted: {
        Qt.callLater(root.initSizeFromCurrent)
        root.rewatchRuntime()
    }

    // ── Runtime state ────────────────────────────────────────────────
    // True while the scene is still moving: recording, or fading out after
    // recording stopped (ribbon settling, motes and links dissolving).
    property bool animating: false
    property real pendingDt: 0
    property real sinceLastPaint: 0

    // ── hyprwhspr state ──────────────────────────────────────────────
    // hyprwhspr creates recording_status (and writes audio_level every 100 ms)
    // in $XDG_RUNTIME_DIR/hyprwhspr only while recording. Directory watchers
    // (inotify) report it appearing and disappearing, so nothing polls while
    // idle; audio_level is read in-process, and only while recording. Older
    // hyprwhspr releases used ~/.config/hyprwhspr, which is watched as well
    // (the compatibility symlinks it holds dangle while idle and aren't listed).
    readonly property string runtimeBase: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string runtimeDir: runtimeBase ? runtimeBase + "/hyprwhspr" : ""
    readonly property string legacyDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hyprwhspr"

    readonly property bool runtimeRecording: runtimeStatus.count > 0
    readonly property bool legacyRecording: legacyStatus.count > 0
    readonly property bool recording: runtimeRecording || legacyRecording
    property real level: 0.0

    FolderListModel {
        id: runtimeStatus
        nameFilters: ["recording_status"]
        showDirs: false
        showHidden: true
    }

    // A directory watcher misses files if its directory is created (or
    // recreated by a hyprwhspr restart) after it started, so re-arm it
    // whenever the hyprwhspr directory appears or disappears.
    FolderListModel {
        folder: root.runtimeBase ? "file://" + root.runtimeBase : ""
        nameFilters: ["hyprwhspr"]
        showFiles: false
        showDirs: true
        showHidden: true
        onCountChanged: root.rewatchRuntime()
    }

    function rewatchRuntime() {
        runtimeStatus.folder = ""
        if (root.runtimeDir)
            Qt.callLater(() => runtimeStatus.folder = "file://" + root.runtimeDir)
    }

    FolderListModel {
        id: legacyStatus
        folder: "file://" + root.legacyDir
        nameFilters: ["recording_status"]
        showDirs: false
        showHidden: true
    }

    FileView {
        id: levelFile
        path: root.recording ? (root.runtimeRecording ? root.runtimeDir : root.legacyDir) + "/audio_level" : ""
        blockLoading: true
        printErrors: false
    }

    Timer {
        interval: 60
        repeat: true
        running: root.recording
        onTriggered: {
            levelFile.reload()
            var v = parseFloat(levelFile.text())
            root.level = isNaN(v) ? 0 : Math.max(0, Math.min(1, v))
        }
    }

    onRecordingChanged: {
        if (root.recording)
            root.animating = true
        else
            root.level = 0
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
