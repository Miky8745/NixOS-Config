# Quickshell-based lock screen, replacing swaylock.
# Adapted from Quickshell's own official example (quickshell/quickshell-examples,
# lockscreen/), with its "let me out" debug button removed - that button calls
# context.unlocked() with zero authentication, which is fine for the upstream
# project's test mode but not acceptable in something actually guarding a
# session. Authentication goes through the "quickshell-lock" PAM service
# declared in configuration.nix (plain pam_unix, same mechanism swaylock uses).
{ ... }:

{
  xdg.configFile."quickshell-lock/shell.qml".text = ''
    import Quickshell
    import Quickshell.Wayland

    ShellRoot {
        // This stores all the information shared between the lock surfaces on each screen.
        LockContext {
            id: lockContext

            onUnlocked: {
                // Unlock the screen before exiting, or the compositor will display a
                // fallback lock you can't interact with.
                lock.locked = false;

                Qt.quit();
            }
        }

        WlSessionLock {
            id: lock

            // Lock the session immediately when quickshell starts.
            locked: true

            WlSessionLockSurface {
                LockSurface {
                    anchors.fill: parent
                    context: lockContext
                }
            }
        }
    }
  '';

  xdg.configFile."quickshell-lock/LockContext.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Services.Pam

    Scope {
        id: root
        signal unlocked()
        signal failed()

        // These properties are in the context and not individual lock surfaces
        // so all surfaces can share the same state.
        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false

        // Clear the failure text once the user starts typing.
        onCurrentTextChanged: showFailure = false;

        function tryUnlock() {
            if (currentText === "") return;

            root.unlockInProgress = true;
            pam.start();
        }

        PamContext {
            id: pam

            // "quickshell-lock" is a real NixOS PAM service (security.pam.services
            // in configuration.nix), resolved from the default /etc/pam.d - same
            // mechanism swaylock's own PAM service already uses on this system.
            config: "quickshell-lock"

            // pam_unix will ask for a response for the password prompt
            onPamMessage: {
                if (this.responseRequired) {
                    this.respond(root.currentText);
                }
            }

            // pam_unix won't send any important messages so all we need is the completion status.
            onCompleted: result => {
                if (result == PamResult.Success) {
                    root.unlocked();
                } else {
                    root.currentText = "";
                    root.showFailure = true;
                }

                root.unlockInProgress = false;
            }
        }
    }
  '';

  xdg.configFile."quickshell-lock/LockSurface.qml".text = ''
    import QtQuick
    import QtQuick.Layouts
    import QtQuick.Controls.Fusion
    import Quickshell.Wayland

    Rectangle {
        id: root
        required property LockContext context
        readonly property ColorGroup colors: Window.active ? palette.active : palette.inactive

        color: colors.window

        Label {
            id: clock
            property var date: new Date()

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: 100
            }

            // The native font renderer tends to look nicer at large sizes.
            renderType: Text.NativeRendering
            font.pointSize: 80

            // updates the clock every second
            Timer {
                running: true
                repeat: true
                interval: 1000

                onTriggered: clock.date = new Date();
            }

            // updated when the date changes
            text: {
                const hours = this.date.getHours().toString().padStart(2, '0');
                const minutes = this.date.getMinutes().toString().padStart(2, '0');
                return `''${hours}:''${minutes}`;
            }
        }

        ColumnLayout {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.verticalCenter
            }

            RowLayout {
                TextField {
                    id: passwordBox

                    implicitWidth: 400
                    padding: 10

                    focus: true
                    enabled: !root.context.unlockInProgress
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData

                    // Update the text in the context when the text in the box changes.
                    onTextChanged: root.context.currentText = this.text;

                    // Try to unlock when enter is pressed.
                    onAccepted: root.context.tryUnlock();

                    // Update the text in the box to match the text in the context.
                    // This makes sure multiple monitors have the same text.
                    Connections {
                        target: root.context

                        function onCurrentTextChanged() {
                            passwordBox.text = root.context.currentText;
                        }
                    }
                }

                Button {
                    text: "Unlock"
                    padding: 10

                    // don't steal focus from the text box
                    focusPolicy: Qt.NoFocus

                    enabled: !root.context.unlockInProgress && root.context.currentText !== "";
                    onClicked: root.context.tryUnlock();
                }
            }

            Label {
                visible: root.context.showFailure
                text: "Incorrect password"
            }
        }
    }
  '';

  # Safe way to test the UI and PAM auth without risking an actual lockout:
  # runs the same LockSurface/LockContext in a normal floating window instead
  # of a real session lock. Try `quickshell -p ~/.config/quickshell-lock/test.qml`
  # and type your password before ever trusting the real thing.
  xdg.configFile."quickshell-lock/test.qml".text = ''
    import QtQuick
    import Quickshell

    ShellRoot {
        LockContext {
            id: lockContext
            onUnlocked: Qt.quit();
        }

        FloatingWindow {
            LockSurface {
                anchors.fill: parent
                context: lockContext
            }
        }

        // exit the example if the window closes
        Connections {
            target: Quickshell

            function onLastWindowClosed() {
                Qt.quit();
            }
        }
    }
  '';
}
