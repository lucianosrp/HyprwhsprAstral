import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "hyprwhsprAstral"

    component SectionHeader: StyledText {
        width: parent.width
        topPadding: Theme.spacingM
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.primary
    }

    StyledText {
        width: parent.width
        text: "Hyprwhspr Astral"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "A ribbon of stardust that breathes with your voice while hyprwhspr is recording. Motes drift off its crest and nearby stars briefly join into constellations. Place and resize it from the desktop-widget controls."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // ── Layout & visibility ──────────────────────────────────────────
    SectionHeader { text: "Layout & visibility" }

    SliderSetting {
        settingKey: "widthPx"
        label: "Width"
        description: "Widget width in pixels. Resizes the widget live (alternative to dragging the corner)."
        minimum: 200
        maximum: 2400
        defaultValue: 520
        unit: "px"
    }

    SliderSetting {
        settingKey: "heightPx"
        label: "Height"
        minimum: 80
        maximum: 1000
        defaultValue: 180
        unit: "px"
    }

    SelectionSetting {
        settingKey: "idleBehavior"
        label: "When not recording"
        description: "The dim placeholder is a faint resting thread of stars, so you can move and resize the widget without dictating. Hidden makes it appear only while recording."
        options: [
            {label: "Show dim placeholder", value: "dim"},
            {label: "Hidden (overlay only)", value: "hidden"}
        ]
        defaultValue: "dim"
    }

    SliderSetting {
        settingKey: "idleOpacity"
        label: "Idle opacity"
        minimum: 5
        maximum: 100
        defaultValue: 50
        unit: "%"
    }

    SliderSetting {
        settingKey: "activeOpacity"
        label: "Active opacity"
        description: "Overall opacity while recording."
        minimum: 10
        maximum: 100
        defaultValue: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "showBackground"
        label: "Show background panel"
        description: "Translucent panel behind the stars for busy wallpapers."
        defaultValue: false
    }

    // ── Response ─────────────────────────────────────────────────────
    SectionHeader { text: "Response" }

    SliderSetting {
        settingKey: "sensitivity"
        label: "Sensitivity"
        description: "Gain applied to the mic level. 150–200% suits most mics."
        minimum: 50
        maximum: 500
        defaultValue: 200
        unit: "%"
    }

    SliderSetting {
        settingKey: "autoGain"
        label: "Auto gain"
        description: "Adapts to your recent loudness so normal speech uses the full range on any mic. 0% uses Sensitivity alone."
        minimum: 0
        maximum: 100
        defaultValue: 70
        unit: "%"
    }

    SliderSetting {
        settingKey: "reactivity"
        label: "Voice reactivity"
        description: "How strongly syllables kick the grains and speed up the ribbon while you speak."
        minimum: 0
        maximum: 300
        defaultValue: 150
        unit: "%"
    }

    SliderSetting {
        settingKey: "rippleSpread"
        label: "Ripple spread"
        description: "Each syllable travels from the centre outward. 0% moves the whole ribbon at once."
        minimum: 0
        maximum: 200
        defaultValue: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "peakBoost"
        label: "Peak brightness"
        description: "How hard loud moments bloom: larger grains with white-hot cores and a brighter nebula band. Quiet speech stays soft either way."
        minimum: 0
        maximum: 300
        defaultValue: 160
        unit: "%"
    }

    SliderSetting {
        settingKey: "onsetSparkle"
        label: "Onset sparkle"
        description: "Flash and spark burst when a loud syllable starts suddenly. 0% turns it off."
        minimum: 0
        maximum: 200
        defaultValue: 100
        unit: "%"
    }

    // ── Ribbon ───────────────────────────────────────────────────────
    SectionHeader { text: "Stardust ribbon" }

    SliderSetting {
        settingKey: "starCount"
        label: "Stars"
        description: "Number of grains in the ribbon."
        minimum: 40
        maximum: 600
        defaultValue: 220
    }

    SliderSetting {
        settingKey: "ribbonHeight"
        label: "Ribbon height"
        description: "How far the grains spread vertically at full volume."
        minimum: 20
        maximum: 150
        defaultValue: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "starSize"
        label: "Star size"
        minimum: 50
        maximum: 250
        defaultValue: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "twinkle"
        label: "Twinkle"
        description: "How much individual stars shimmer. 0% is steady light."
        minimum: 0
        maximum: 100
        defaultValue: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "motionSpeed"
        label: "Motion speed"
        description: "How fast the ribbon undulates."
        minimum: 25
        maximum: 250
        defaultValue: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "bandGlow"
        label: "Nebula glow"
        description: "Soft band of light behind the ribbon."
        minimum: 0
        maximum: 200
        defaultValue: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "centerEnvelope"
        label: "Center swell"
        description: "The ribbon swells toward the middle. Off spreads evenly across the width."
        defaultValue: true
    }

    // ── Drift ────────────────────────────────────────────────────────
    SectionHeader { text: "Drifting motes" }

    SliderSetting {
        settingKey: "driftAmount"
        label: "Drift amount"
        description: "How many motes break off the crest at peaks. 0% turns drift off."
        minimum: 0
        maximum: 300
        defaultValue: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "driftSpeed"
        label: "Drift speed"
        minimum: 25
        maximum: 250
        defaultValue: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "maxMotes"
        label: "Max motes"
        description: "Upper limit on motes alive at once."
        minimum: 0
        maximum: 1500
        defaultValue: 500
    }

    // ── Constellations ───────────────────────────────────────────────
    SectionHeader { text: "Constellation links" }

    SelectionSetting {
        settingKey: "linkDensity"
        label: "Connections"
        description: "Short-lived lines joining nearby stars. They form more often as you speak louder."
        options: [
            {label: "Off", value: "0"},
            {label: "Sparse", value: "1"},
            {label: "Woven", value: "2.2"},
            {label: "Dense", value: "4"}
        ]
        defaultValue: "1"
    }

    SliderSetting {
        settingKey: "linkReach"
        label: "Link reach"
        description: "How far apart two stars can be and still connect."
        minimum: 40
        maximum: 250
        defaultValue: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "linkLifetime"
        label: "Link lifetime"
        description: "How long a link holds before dissolving."
        minimum: 25
        maximum: 300
        defaultValue: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "constellations"
        label: "Constellations at peaks"
        description: "At loud peaks, links chain across 3–5 stars that light up in sequence."
        defaultValue: true
    }

    // ── Colors ───────────────────────────────────────────────────────
    SectionHeader { text: "Colors" }

    SelectionSetting {
        settingKey: "palette"
        label: "Palette"
        description: "Colors sweep across the ribbon from left to right."
        options: [
            {label: "Theme (primary → secondary → tertiary)", value: "theme"},
            {label: "Theme duo (primary ↔ secondary)", value: "duo"},
            {label: "Theme primary only", value: "primary"},
            {label: "Astral (white-blue-violet)", value: "astral"},
            {label: "Ember (gold)", value: "ember"},
            {label: "Custom", value: "custom"}
        ]
        defaultValue: "theme"
    }

    ColorSetting {
        settingKey: "customColor1"
        label: "Custom color — left"
        description: "Used when Palette is Custom."
        defaultValue: Theme.primary
    }

    ColorSetting {
        settingKey: "customColor2"
        label: "Custom color — middle"
        defaultValue: Theme.secondary
    }

    ColorSetting {
        settingKey: "customColor3"
        label: "Custom color — right"
        defaultValue: Theme.tertiary
    }

    // ── Performance ──────────────────────────────────────────────────
    SectionHeader { text: "Performance" }

    SelectionSetting {
        settingKey: "glowQuality"
        label: "Glow quality"
        description: "Full uses soft gradient halos. Soft and Minimal are cheaper for large widgets or slow machines."
        options: [
            {label: "Full", value: "2"},
            {label: "Soft", value: "1"},
            {label: "Minimal (cores only)", value: "0"}
        ]
        defaultValue: "2"
    }

    SelectionSetting {
        settingKey: "maxFps"
        label: "Frame rate cap"
        description: "Animation only runs while recording and while things settle afterwards."
        options: [
            {label: "30 fps", value: "30"},
            {label: "45 fps", value: "45"},
            {label: "60 fps", value: "60"},
            {label: "120 fps", value: "120"},
            {label: "Display rate", value: "240"}
        ]
        defaultValue: "60"
    }
}
