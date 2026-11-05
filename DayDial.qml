import QtQuick
import qs.Commons

// Actual 24-hour prayer positions, clockwise from midnight. No repaint loop.
Item {
  id: root
  property color foreground: Color.foreground
  property color accent: Color.accent
  property var points: []
  property var journey: ({})

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var cx = width / 2, cy = height / 2
      var r = Math.min(width, height) / 2 - Style.space(10)
      var fg = root.foreground, ac = root.accent, j = root.journey || {}
      var start = -Math.PI / 2
      ctx.lineWidth = Style.space(3)
      ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.14)
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, Math.PI * 2)
      ctx.stroke()
      if (j.hasWindow) {
        var from = Number(j.fromFraction) || 0
        var now = Number(j.nowFraction) || 0
        if (now < from) now += 1
        ctx.strokeStyle = ac
        ctx.lineCap = "round"
        ctx.beginPath()
        ctx.arc(cx, cy, r, start + from * Math.PI * 2, start + now * Math.PI * 2)
        ctx.stroke()
      }
      for (var i = 0; i < root.points.length; i++) {
        var pt = root.points[i]
        var angle = start + pt.fraction * Math.PI * 2
        var next = pt.id === j.nextId
        ctx.beginPath()
        ctx.fillStyle = next ? ac : Qt.rgba(fg.r, fg.g, fg.b, pt.isSunrise ? 0.5 : 0.8)
        ctx.arc(cx + Math.cos(angle) * r, cy + Math.sin(angle) * r,
          Style.space(next ? 4.5 : 2.5), 0, Math.PI * 2)
        ctx.fill()
      }
      if (j.hasWindow) {
        var a = start + (Number(j.nowFraction) || 0) * Math.PI * 2
        ctx.beginPath()
        ctx.fillStyle = fg
        ctx.arc(cx + Math.cos(a) * r, cy + Math.sin(a) * r, Style.space(3), 0, Math.PI * 2)
        ctx.fill()
      }
    }
  }
  onPointsChanged: canvas.requestPaint()
  onJourneyChanged: canvas.requestPaint()
  onForegroundChanged: canvas.requestPaint()
  onAccentChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
}
