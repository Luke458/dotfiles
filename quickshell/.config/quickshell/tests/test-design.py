#!/usr/bin/env python3
"""Exercise theme replacement, control input, and oversized popup content.

Quickshell statically registers its QML plugin, so run QtTest inside qs rather
than qmltestrunner. The offscreen platform has no layer-shell backend: only the
popup window wrapper is replaced; its layout, scrolling and key handling are
unchanged. This does not validate compositor positioning or focus negotiation.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
QML = r'''
import QtQuick
import QtTest
import Quickshell
import "COMPONENTS_URI" as C
FloatingWindow {
    implicitWidth: 500
    implicitHeight: 300
    visible: true
    TestCase {
    id: tests
    visible: true
    name: "ShellDesign"
    width: 500; height: 300
    when: false
    function run() { test_themeReplacement(); cleanup(); test_invalidTokens(); cleanup(); test_keyboard(); cleanup(); test_slider(); popup.open(Qt.resolvedUrl("Large.qml"), null, {}); finish.start(); }
    Timer { interval: 250; running: true; onTriggered: tests.run() }
    TestPopup { id: popup; visible: false; dismissOnHoverLeave: false }
    Timer {
        id: finish; interval: 200
        onTriggered: {
            const bg = tests.findChild(popup.contentItem, "popup-background");
            const view = tests.findChild(popup.contentItem, "popup-viewport");
            tests.verify(bg.width <= popup.width);
            tests.verify(bg.y + bg.height <= popup.height);
            tests.verify(view.contentWidth > view.width);
            tests.verify(view.contentHeight > view.height);
            view.forceActiveFocus();
            tests.keyClick(Qt.Key_Escape);
            tests.compare(popup.visible, false);
            console.log("DESIGN_TEST_PASS");
            Qt.quit();
        }
    }
    C.StyledButton { id: button; text: "Connect"; y: 40 }
    C.StyledSwitch { id: toggle; y: 90; onToggled: checked = !checked }
    property real sourceValue: 0.5
    C.StyledSlider {
        id: slider; x: 20; y: 150; width: 200
        from: 0; to: 1; stepSize: 0.1
        Binding on value { value: tests.sourceValue; when: !slider.pressed; restoreMode: Binding.RestoreNone }
        onCommitted: newValue => tests.sourceValue = newValue
    }
    SignalSpy { id: commits; target: slider; signalName: "committed" }
    function test_slider() {
        slider.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Right);
        compare(commits.count, 1);
        fuzzyCompare(sourceValue, 0.6, 0.001);
        sourceValue = 0.2;
        compare(commits.count, 1);
        fuzzyCompare(slider.value, 0.2, 0.001);
        mousePress(slider, 45, 12);
        mouseMove(slider, 170, 12, 30);
        compare(commits.count, 1);
        mouseRelease(slider, 170, 12);
        compare(commits.count, 2);
        verify(sourceValue >= 0.8);
        slider.enabled = false;
        keyClick(Qt.Key_Left);
        compare(commits.count, 2);
    }
    SignalSpy { id: clicks; target: button; signalName: "clicked" }
    function cleanup() { C.Theme.applyThemeOverrides("{}"); button.enabled = true; toggle.busy = false }
    function test_themeReplacement() {
        C.Theme.applyThemeOverrides('{"selBg":"#123456","fg":"#202020","bgSolid":"#eeeeee","fontSizeBar":17}');
        compare(C.Theme.overrideCount, 4);
        compare(C.Theme.selBg.toString(), "#123456");
        compare(C.Theme.bg.toString(), "#eeeeee");
        compare(C.Theme.hover.r, C.Theme.fg.r);
        C.Theme.applyThemeOverrides('{"bgSolid":"#ffffff"}');
        compare(C.Theme.selBg.toString(), "#005577");
        compare(C.Theme.fontSizeBar, 13);
        compare(C.Theme.bg.toString(), "#ffffff");
        C.Theme.applyThemeOverrides('{"bg":"#112233"}');
        compare(C.Theme.bg.toString(), "#112233");
        C.Theme.applyThemeOverrides('{}');
        compare(C.Theme.bg.toString(), "#222222");
    }
    function test_invalidTokens() {
        C.Theme.applyThemeOverrides('{"hasOwnProperty":0,"fontSizeBar":-1,"bg":"nonsense","opacityMuted":2,"themeFileUsed":"bad","selection":"red","fontMono":false}');
        compare(C.Theme.overrideCount, 0);
        compare(C.Theme.fontSizeBar, 13);
        C.Theme.applyThemeOverrides('{"selBg":"red"}');
        compare(C.Theme.selBg.toString(), "#ff0000");
        C.Theme.applyThemeOverrides('{');
        compare(C.Theme.selBg.toString(), "#ff0000");
    }
    function test_keyboard() {
        button.forceActiveFocus(Qt.TabFocusReason);
        verify(button.activeFocus);
        verify(button.visualFocus);
        keyClick(Qt.Key_Space);
        compare(clicks.count, 1);
        button.enabled = false;
        keyClick(Qt.Key_Space);
        compare(clicks.count, 1);
        toggle.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Space);
        compare(toggle.checked, true);
        toggle.busy = true;
        keyClick(Qt.Key_Space);
        compare(toggle.checked, true);
    }
}

}
'''

with tempfile.TemporaryDirectory(prefix="qs-design-") as directory:
    test = Path(directory)
    components_uri = (ROOT / "components").as_uri()
    (test / "shell.qml").write_text(QML.replace("COMPONENTS_URI", components_uri))
    popup = (ROOT / "components/ShellPopup.qml").read_text()
    popup = popup.replace('import "."', f'import "{components_uri}"')
    popup = popup.replace("PanelWindow {", "FloatingWindow {")
    popup = re.sub(r"^    WlrLayershell\..*\n", "", popup, flags=re.M)
    popup, count = re.subn(r"    anchors \{\n.*?\n    \}",
                          "    implicitWidth: 800\n    implicitHeight: 600",
                          popup, count=1, flags=re.S)
    if count != 1:
        raise SystemExit("Could not isolate popup window anchors")
    (test / "TestPopup.qml").write_text(popup)
    (test / "Large.qml").write_text(
        'import QtQuick\nRectangle { implicitWidth: 1200; implicitHeight: 1400 }\n')
    runtime = test / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen",
               QS_THEME_FILE=str(test / "missing-theme.json"), QS_UI_SCALE="1")
    try:
        result = subprocess.run(["qs", "-p", str(test / "shell.qml")], env=env,
                                capture_output=True, text=True, timeout=10)
    except subprocess.TimeoutExpired as error:
        raise SystemExit(f"Design tests timed out: {error.stdout!r} {error.stderr!r}")
    output = result.stdout + result.stderr
    if result.returncode != 0 or "DESIGN_TEST_PASS" not in output:
        raise SystemExit(output)
    print("Design tests passed: theme replacement/validation, keyboard controls, slider commit/binding behavior, popup bounds and Escape")
