import QtQuick

// The old "recorder-animation": fade in, hold, fade out on a 2 s loop.
// Put inside an item and bind `running`; the target's opacity resets when stopped.
SequentialAnimation {
    id: root

    required property Item target

    loops: Animation.Infinite
    onRunningChanged: if (!running) target.opacity = 1

    NumberAnimation { target: root.target; property: "opacity"; from: 0; to: 1; duration: 1000 }
    PauseAnimation { duration: 800 }
    NumberAnimation { target: root.target; property: "opacity"; to: 0; duration: 200 }
}
