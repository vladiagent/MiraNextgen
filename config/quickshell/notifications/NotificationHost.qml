pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Scope {
    Variants {
        model:Quickshell.screens
        delegate:NotificationToasts {required property ShellScreen modelData;targetScreen:modelData}
    }
    NotificationCenter {}
}
