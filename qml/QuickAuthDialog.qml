/*  This file is part of the KDE project
    SPDX-FileCopyrightText: 2021 Aleix Pol Gonzalez <aleixpol@kde.org>
    SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtMultimedia
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.sounds
import org.kde.polkitkde

Kirigami.AbstractApplicationWindow {
    id: root
    title: i18n("User Account Control") //i18n("Authentication Required")
    minimumHeight: intendedWindowHeight
    maximumHeight: intendedWindowHeight
    minimumWidth: intendedWindowWidth
    maximumWidth: intendedWindowWidth
    width: intendedWindowWidth
    height: intendedWindowHeight
    // Setting both minimum and maximum to the same value makes the window
    // fully fixed-size. KWin does not show a maximize button for a
    // fixed-size window — the same approach used by the official
    // polkit-kde-agent-1. Works on both Wayland and X11 sessions.

    property alias password: passwordField.text
    property alias identitiesModel: identitiesCombo.model
    property alias identitiesCurrentIndex: identitiesCombo.currentIndex
    property alias selectedIdentity: identitiesCombo.currentValue
    property bool waitingForAuthentication: false

    // passed in by QuickAuthDialog.cpp
    property string mainText
    property string subtitle
    property string descriptionString
    property string descriptionActionId
    property string descriptionVendorName
    property string descriptionVendorUrl
    property string descriptionIcon
    property bool sevenLike: true

    // ── Theme colors via SystemPalette (auto-updates on theme switch) ──
    SystemPalette { id: sysPalette; colorGroup: SystemPalette.Active }

    readonly property bool isDarkMode: {
        var lum = 0.299 * sysPalette.window.r + 0.587 * sysPalette.window.g + 0.114 * sysPalette.window.b;
        return lum < 0.5;
    }

    readonly property color accentColor: sysPalette.highlight
    readonly property color accentTextColor: sysPalette.highlightedText
    readonly property color themeTextColor: sysPalette.windowText
    readonly property color themeBgColor: sysPalette.window
    readonly property color themePlaceholderColor: sysPalette.mid
    readonly property color themeButtonBg: sysPalette.button
    readonly property color themeButtonBorder: sysPalette.mid
    readonly property color themeInputBg: sysPalette.base
    readonly property color themeInputBorder: sysPalette.mid

    signal accept()
    signal reject()
    signal userSelected()

    onSelectedIdentityChanged: userSelected()

    onAccept: {
        waitingForAuthentication = true;
        // disable password field while password is being checked
        if (passwordField.text !== "") {
            passwordField.enabled = false;
        }
    }

    color: themeBgColor

    Shortcut {
        sequence: StandardKey.Cancel
        onActivated: root.reject()
    }

    function rejectPassword() {
        passwordField.clear()
        passwordField.enabled = true
        passwordField.focus = true
        waitingForAuthentication = false;
    }

    function authenticationFailure() {
        authenticationError.visible = true;
        rejectPassword()
    }

    function request() {
        if (passwordField.text !== "" && waitingForAuthentication) {
            rejectPassword()
        }
    }

    readonly property real intendedWindowWidth: (Kirigami.Units.largeSpacing * 57) - 5
    // Window height is dynamic: the minimum is the collapsed size; the
    // maximum is unset so the window can grow when the identity list
    // expands inline (preventing text overlap from content overflow).
    readonly property real intendedWindowHeight: mainContent.implicitHeight + bottomControls.height + (Kirigami.Units.largeSpacing * 2)
    // Qt window size properties don't always react to binding changes in
    // real-time, so manually update them when the intended height changes
    // (e.g. when the inline identity list expands). This mirrors the
    // approach used by the official polkit-kde-agent-1.
    onIntendedWindowHeightChanged: {
        minimumHeight = intendedWindowHeight;
        height = intendedWindowHeight;
        maximumHeight = intendedWindowHeight;
    }

    onActiveChanged: {
        if (active) {
            // immediately focus on password field when window is focused
            passwordField.forceActiveFocus();
        }
    }

    onVisibleChanged: {
        if (visible) {
            // immediately focus on password field on load
            passwordField.forceActiveFocus();
        } else {
            // reject on close
            root.reject();
        }
    }

    // select user combobox — invisible, used only for state management
    // (currentIndex, currentValue, currentText).
    property QQC2.ComboBox selectIdentityCombobox: QQC2.ComboBox {
        id: identitiesCombo
        visible: false
        textRole: "display"
        valueRole: "userRole"
        enabled: count > 0
        model: IdentitiesModel {
            id: identitiesModel
        }
    }

    // Inline identity list — expands/collapses inside the dialog layout
    // instead of a floating popup that gets clipped by the window edges.
    property bool identityListVisible: false

    Column {
        id: mainContent
        anchors.fill: parent
        spacing: 16

        Rectangle {
            id: header
            property bool isUnknown: descriptionActionId == "org.freedesktop.policykit.exec"
            anchors {
                right: parent.right
                left: parent.left
            }
            implicitHeight: root.sevenLike ? 52 : 40

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 1.0; color: header.isUnknown ? "#ffcd4a" : "#137798"}
                GradientStop { position: 0.0; color: header.isUnknown ? "#f4b200" : "#073f6e"}
            }

            RowLayout {
                spacing: Kirigami.Units.largeSpacing
                anchors {
                    fill: parent
                    leftMargin: Kirigami.Units.largeSpacing
                    rightMargin: Kirigami.Units.largeSpacing
                }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                    source: header.isUnknown ? "firewall-applet-panic" : "dialog-password"
                }

                Kirigami.Heading {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    level: 2
                    text: root.mainText
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    color: header.isUnknown ? "black" : "white"
                }
            }
        }

        ColumnLayout {
            id: contentItem
            anchors {
                right: parent.right
                left: parent.left
                margins: 20
            }
            spacing: root.sevenLike ? Kirigami.Units.smallSpacing + Kirigami.Units.largeSpacing : Kirigami.Units.largeSpacing

            RowLayout {
                id: content
                Layout.alignment: Qt.AlignLeft
                Layout.fillWidth: true
                Layout.leftMargin: 50
                spacing: Kirigami.Units.largeSpacing * 3

                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                    Layout.alignment: Qt.AlignTop
                    source: descriptionIcon == "" ? "application-default-icon" : descriptionIcon
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    Row {
                        spacing: 4
                        QQC2.Label {
                            text: i18n("ID:")
                            visible: root.sevenLike
                            color: themeTextColor
                        }
                        QQC2.Label {
                            text: descriptionActionId
                            color: themeTextColor
                        }
                    }

                    Row {
                        spacing: 4
                        visible: descriptionVendorName !== ""
                        QQC2.Label {
                            text: i18n("Vendor:")
                            visible: root.sevenLike
                            color: themeTextColor
                        }
                        QQC2.Label {
                            text: descriptionVendorName
                            font.bold: true
                            color: themeTextColor
                            Kirigami.UrlButton {
                                anchors.left: parent.right
                                width: Kirigami.Units.iconSizes.small
                                height: parent.height
                                text: " "
                                url: descriptionVendorUrl
                                font.underline: false
                            }
                        }
                    }

                    RowLayout {
                        spacing: 4
                        Layout.fillWidth: true
                        QQC2.Label {
                            text: i18n("Action:")
                            visible: root.sevenLike
                            color: themeTextColor
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: descriptionString
                            wrapMode: Text.WordWrap
                            color: themeTextColor
                        }
                    }
                }
            }

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                Rectangle {
                    id: sep
                    Layout.fillWidth: true
                    Layout.rightMargin: root.sevenLike ? -4 : 0
                    Layout.leftMargin: root.sevenLike ? -4 : 0
                    implicitHeight: 1
                    color: themeButtonBorder
                }
                LayoutItemProxy { target: sep; visible: root.sevenLike }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("To continue, type an administrator password, and then click OK.")
                    color: themeTextColor
                }

                LayoutItemProxy { target: sep; visible: !root.sevenLike }
            }

            Column {
                id: authenticationPrompt
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                Item {
                    id: user
                    anchors {
                        right: parent.right
                        left: parent.left
                    }
                    // Height grows when the identity list expands so that
                    // the inline list is fully visible instead of being
                    // clipped inside this 76px box and overlapping the
                    // instruction text above.
                    height: 76 + (root.identityListVisible
                                  ? identityList.Layout.preferredHeight
                                  : 0)

                    Row {
                        anchors.fill: parent
                        spacing: 16

                        // ── Circular avatar ──
                        // Qt Quick's clip only crops to the rectangular bounds (it
                        // ignores radius), so the photo is painted into a Canvas
                        // with a circular clip path instead: nothing outside the
                        // circle is ever rendered, regardless of theme or paint
                        // timing. The photo is cover-cropped so it fills the frame
                        // edge to edge.
                        Item {
                            id: avatarFrame
                            width: 60
                            height: 60

                            // Check if source is a file path (user photo) or icon name
                            property string avatarSource: {
                                var icon = identitiesModel.iconForIndex(identitiesCombo.currentIndex);
                                return icon ? icon : "cs-user-accounts";
                            }
                            property bool isDefaultIcon: {
                                var src = avatarSource;
                                return !src || src.indexOf('/') === -1;
                            }
                            // The query suffix is unique per dialog instance. The
                            // agent process is long-lived and QML's pixmap cache
                            // is keyed by URL, so an avatar changed in System
                            // Settings would otherwise keep serving the stale
                            // cached copy; a fresh URL forces a re-read from disk.
                            property string photoUrlBase: isDefaultIcon
                                                          ? ""
                                                          : (avatarSource.indexOf("file:") === 0
                                                             ? avatarSource
                                                             : "file://" + avatarSource)
                            property string avatarNonce: Date.now()
                            property url photoUrl: photoUrlBase === ""
                                                   ? ""
                                                   : photoUrlBase + "?" + avatarNonce

                            // Frame interior behind the photo
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: themeButtonBg
                            }

                            // Default icon when the user has no photo (icon files
                            // have transparency, so no corner problem)
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 40
                                height: 40
                                visible: avatarFrame.isDefaultIcon
                                source: avatarFrame.isDefaultIcon ? avatarFrame.avatarSource : ""
                                color: themeTextColor
                            }

                            // Hidden probe that reports the photo's natural size
                            // for the cover-crop math below
                            Image {
                                id: avatarProbe
                                visible: false
                                cache: false
                                source: avatarFrame.photoUrl
                                onStatusChanged: if (status === Image.Ready) avatarCanvas.requestPaint()
                            }

                            // The photo, cover-cropped and clipped to the circle
                            Canvas {
                                id: avatarCanvas
                                anchors.fill: parent
                                visible: !avatarFrame.isDefaultIcon

                                property url photoSource: avatarFrame.photoUrl
                                onPhotoSourceChanged: {
                                    if (photoSource.toString() !== "") {
                                        loadImage(photoSource);
                                    }
                                }
                                Component.onCompleted: {
                                    if (photoSource.toString() !== "") {
                                        loadImage(photoSource);
                                    }
                                }
                                onImageLoaded: requestPaint()
                                onWidthChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    var url = photoSource.toString();
                                    if (url === "" || !isImageLoaded(url)) {
                                        return;
                                    }
                                    // circular clip — nothing outside is drawn
                                    ctx.beginPath();
                                    ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI);
                                    ctx.clip();
                                    // cover-crop: scale the shorter side up, center
                                    var iw = avatarProbe.implicitWidth;
                                    var ih = avatarProbe.implicitHeight;
                                    if (iw <= 0 || ih <= 0) {
                                        return;
                                    }
                                    var s = Math.max(width / iw, height / ih);
                                    var dw = iw * s;
                                    var dh = ih * s;
                                    ctx.drawImage(url, (width - dw) / 2, (height - dh) / 2, dw, dh);
                                }
                            }

                            // Ring on top so it stays crisp above the photo
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.color: themeButtonBorder
                                border.width: 2
                            }
                        }

                        ColumnLayout {
                            // Anchor to the top of the Row (not vertically
                            // centered) so when the identity list expands
                            // the content grows downward without being
                            // squeezed into a fixed-height box.
                            anchors.top: parent.top
                            spacing: 9
                            Layout.fillWidth: true

                            RowLayout {
                                Kirigami.Heading {
                                    level: 2
                                    text: identitiesCombo.currentText
                                    color: themeTextColor
                                }
                                Kirigami.LinkButton {
                                    Layout.alignment: Qt.AlignVCenter
                                    id: switchButton
                                    text: i18n("Switch…")
                                    visible: identitiesCombo.count > 1
                                    onClicked: root.identityListVisible = !root.identityListVisible
                                }
                            }

                            // ── Inline identity list ──
                            // Expands/collapses inside the dialog layout
                            // (not a floating popup) so the dialog window
                            // grows to fit it and nothing gets clipped.
                            ListView {
                                id: identityList
                                visible: root.identityListVisible
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.identityListVisible
                                                          ? Math.min(count * 30, 120)
                                                          : 0
                                clip: true
                                model: identitiesModel
                                interactive: false

                                Behavior on Layout.preferredHeight {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                                }

                                delegate: Rectangle {
                                    id: identityDelegate
                                    width: identityList.width
                                    height: 30
                                    // Use a semi-transparent accent so the
                                    // highlight is light enough for dark
                                    // text to remain readable.
                                    color: (identityRowMouse.containsMouse || identitiesCombo.currentIndex === index)
                                           ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35)
                                           : themeBgColor
                                    border.color: themeButtonBorder
                                    border.width: 1

                                    Text {
                                        id: rowText
                                        anchors {
                                            verticalCenter: parent.verticalCenter
                                            left: parent.left
                                            right: parent.right
                                            leftMargin: 8
                                            rightMargin: 8
                                        }
                                        text: model.display
                                        color: themeTextColor
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: identityRowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            identitiesCombo.currentIndex = index
                                            root.identityListVisible = false
                                        }
                                    }
                                }
                            }

                            // ── Password field ──
                            Item {
                                Layout.alignment: Qt.AlignLeft
                                Layout.preferredWidth: 220
                                Layout.preferredHeight: 25

                                Rectangle {
                                    anchors.fill: parent
                                    color: themeInputBg
                                    border.color: passwordField.activeFocus ? accentColor : themeInputBorder
                                    border.width: 1
                                    radius: 2
                                }

                                QQC2.TextField {
                                    id: passwordField
                                    anchors.fill: parent
                                    leftPadding: 8
                                    rightPadding: 30
                                    echoMode: TextInput.Password
                                    color: themeTextColor
                                    selectionColor: accentColor
                                    selectedTextColor: accentTextColor
                                    onAccepted: root.accept()
                                    background: Item {}
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: passwordField.leftPadding
                                    anchors.verticalCenter: passwordField.verticalCenter
                                    text: i18n("Password…")
                                    color: themePlaceholderColor
                                    font: passwordField.font
                                    visible: passwordField.text === "" && !passwordField.activeFocus
                                }

                                // Eye icon
                                MouseArea {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    height: 20
                                    onClicked: {
                                        passwordField.echoMode = passwordField.echoMode === TextInput.Password
                                            ? TextInput.Normal
                                            : TextInput.Password;
                                    }

                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        source: passwordField.echoMode === TextInput.Password ? "view-visible" : "view-hidden"
                                        width: 16
                                        height: 16
                                        color: themeTextColor
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    id: authenticationError
                    visible: false
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: "dialog-error"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: i18n("Authentication failure, please try again.")
                        color: themeTextColor
                    }
                }
            }
        }
    }

    Rectangle {
        id: bottomControls
        anchors {
            bottom: parent.bottom
            right: parent.right
            left: parent.left
            margins: -1
        }
        height: 43
        border.width: 1
        border.color: themeButtonBorder
        color: themeButtonBg

        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            anchors.rightMargin: 12
            spacing: 8

            Item { Layout.fillWidth: true }

            // ── OK Button ──
            QQC2.Button {
                id: okButton
                implicitWidth: 73
                implicitHeight: 21
                bottomPadding: 2
                topPadding: 0
                onClicked: root.accept()
                background: Rectangle {
                    color: okButton.down ? accentColor : (okButton.hovered ? accentColor : themeButtonBg)
                    border.color: okButton.down ? accentColor : (okButton.hovered ? accentColor : themeButtonBorder)
                    border.width: 1
                    radius: 10
                }
                contentItem: Text {
                    text: i18n("OK")
                    font: okButton.font
                    color: okButton.down ? accentTextColor : (okButton.hovered ? accentTextColor : themeTextColor)
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // ── Cancel Button ──
            QQC2.Button {
                id: cancelButton
                implicitWidth: 73
                implicitHeight: 21
                bottomPadding: 2
                topPadding: 0
                onClicked: root.reject()
                background: Rectangle {
                    color: cancelButton.down ? accentColor : (cancelButton.hovered ? accentColor : themeButtonBg)
                    border.color: cancelButton.down ? accentColor : (cancelButton.hovered ? accentColor : themeButtonBorder)
                    border.width: 1
                    radius: 10
                }
                contentItem: Text {
                    text: i18n("Cancel")
                    font: cancelButton.font
                    color: cancelButton.down ? accentTextColor : (cancelButton.hovered ? accentTextColor : themeTextColor)
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
    //Component.onCompleted: executable.exec("kreadconfig6 --file ~/.config/kdeglobals --group Sounds --key Theme");
}
