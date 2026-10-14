import QtQuick
import qs.theme

// Filled line graph of `values`, newest on the right. Scales to `max` (or to
// the largest value when max is 0).
Canvas {
    id: root

    property var values: []
    property real max: 1
    property int capacity: 30
    property color lineColor: Theme.primary

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (values.length < 2)
            return;
        const top = max > 0 ? max : Math.max(...values, 1);
        const step = width / (capacity - 1);
        const x0 = width - (values.length - 1) * step;
        const y = v => height - 2 - Math.min(1, v / top) * (height - 4);

        ctx.beginPath();
        ctx.moveTo(x0, y(values[0]));
        for (let i = 1; i < values.length; i++)
            ctx.lineTo(x0 + i * step, y(values[i]));
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.strokeStyle = lineColor;
        ctx.stroke();

        ctx.lineTo(width, height);
        ctx.lineTo(x0, height);
        ctx.closePath();
        const grad = ctx.createLinearGradient(0, 0, 0, height);
        grad.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.35));
        grad.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0));
        ctx.fillStyle = grad;
        ctx.fill();
    }
}
