import QtQuick

// The one section-heading treatment for flyouts and panels: mono, bold,
// small-label size, selected foreground. Replaces the per-file variants.
Text {
    text: ""
    textFormat: Text.PlainText
    color: Theme.selFg
    font.family: Theme.fontMono
    font.pixelSize: Theme.panelBodySize
    font.bold: true
}
