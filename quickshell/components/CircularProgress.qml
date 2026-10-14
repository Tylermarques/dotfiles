import QtQuick
import QtQuick.Shapes
import qs.theme

// Ring showing `value` (0..1) as an arc over a faint track. With a sweep below
// 360 the gap sits at the bottom, like a gauge.
Item {
    id: root

    property real value: 0
    property real thickness: 8
    property real sweep: 360
    property color fillColor: Theme.primary
    property color trackColor: Theme.alpha(Theme.fgSurface, 0.12)

    // Animated copy of value, clamped to 0..1.
    property real shown: Math.min(1, Math.max(0, value))
    readonly property real radius: (Math.min(width, height) - thickness) / 2

    Behavior on shown {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 90 + (360 - root.sweep) / 2
                sweepAngle: root.sweep
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.shown > 0 ? root.fillColor : "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 90 + (360 - root.sweep) / 2
                sweepAngle: root.sweep * root.shown
            }
        }
    }
}
