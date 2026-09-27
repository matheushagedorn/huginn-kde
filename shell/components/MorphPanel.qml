import QtQuick
import Quickshell
import "../theme"

// A popup panel that grows out of the control that opened it.
//
// The popups used to fade in and scale up from a corner, which says "a
// window appeared" but not where it came from. This one starts as the
// button's own rectangle and opens out into the panel, so the eye follows it
// from the thing that was clicked; closing folds it back into the button.
//
// It cannot do that by resizing the popup: a mapped PopupWindow keeps the
// size and position it was created with. So the surface is mapped at full
// size from the first frame, and what moves is the panel drawn inside it: a
// GlassPanel whose rectangle travels from the button's to the whole surface,
// clipping the content as it goes. The content itself never moves. It sits
// where it will be at rest, and the shape uncovers it, which is why a click
// lands on the right row even halfway through the opening, and why anything
// aligned to the screen underneath it stays aligned: only the window over it
// changes, not what is seen through it.
//
// The button usually lives in another window (the bar or the dock), above or
// below the popup, and most of its rectangle falls outside the popup's
// surface. That is on purpose. The shape starts where the button really is
// and the surface edge cuts it, so what shows is a tab sliding out from under
// the bar, as wide as the button, that widens and lengthens into the panel.
//
// A popup adopts it by replacing its GlassPanel with this and handing over
// its window, the button and the flag that opens it; mapping and unmapping
// the window is done here, so the close can play out before the surface goes.
Item {
    id: morph

    // The PopupWindow this panel fills.
    property var popup: null
    // The control the panel grows out of, in the window the popup is
    // anchored to. With none, the panel unrolls from its own edge.
    property Item trigger: null
    // Whether the popup should be showing: usually a PopupService flag.
    property bool open: false

    property alias color: shape.color
    property alias contentItem: content
    default property alias data: content.data

    // How far the shape has travelled from the button (0) to the panel (1),
    // and how far the content has faded in. They are separate so the content
    // can follow the shape instead of arriving with it: text that scales or
    // slides while it grows is hard to read, text that appears once there is
    // room for it is not.
    property real shapeProgress: 0
    property real contentProgress: 0

    // The button's rectangle in this panel's coordinates, taken when the
    // opening starts. Taken once rather than bound: the centre bar re-centres
    // as the track title changes, and a shape chasing it mid-flight wobbles.
    property real originX: 0
    property real originY: 0
    property real originWidth: 0
    property real originHeight: 0
    property real originRadius: Theme.radiusChip

    function lerp(from, to, t) {
        return from + (to - from) * t
    }

    // Where the popup sits in its parent window, worked out the way the
    // compositor places it: the anchor point on anchor.rect picked by
    // `edges`, then the surface laid out from that point towards `gravity`.
    // Wayland never tells a client where its popup ended up, but the bar keeps
    // its popups inside the window (see Theme.popupX), so the compositor has
    // no reason to move them and this is where they are. The halves are
    // floored because the positioner works in whole pixels: a rect left at
    // its default 1px width anchors at its left edge, not half a pixel in.
    function popupOrigin() {
        var a = popup.anchor
        var r = a.rect
        var w = popup.implicitWidth
        var h = popup.implicitHeight

        var ax = (a.edges & Edges.Left) ? r.x : ((a.edges & Edges.Right) ? r.x + r.width : r.x + Math.floor(r.width / 2))
        var ay = (a.edges & Edges.Top) ? r.y : ((a.edges & Edges.Bottom) ? r.y + r.height : r.y + Math.floor(r.height / 2))

        return Qt.point((a.gravity & Edges.Left) ? ax - w : ((a.gravity & Edges.Right) ? ax : ax - Math.floor(w / 2)),
                        (a.gravity & Edges.Top) ? ay - h : ((a.gravity & Edges.Bottom) ? ay : ay - Math.floor(h / 2)))
    }

    // The button's own corner, so the shape starts as the capsule that was
    // clicked. The parameter is untyped on purpose: most triggers are
    // Rectangles, and the ones that are not have no radius to take.
    function cornerOf(item) {
        return item.radius !== undefined ? item.radius : Theme.radiusChip
    }

    function captureOrigin() {
        if (!popup || !trigger) {
            // A sliver along the edge nearest the window it hangs from, full
            // width: the panel unrolls away from it rather than popping in.
            originX = 0
            originY = popup && (popup.anchor.gravity & Edges.Top) ? popup.implicitHeight : 0
            originWidth = popup ? popup.implicitWidth : width
            originHeight = 0
            originRadius = Theme.radiusChip
            return
        }

        // Both corners, not a corner plus the size: a dock icon under the
        // pointer is scaled up, and its width alone would be the resting one.
        var topLeft = trigger.mapToItem(null, 0, 0)
        var bottomRight = trigger.mapToItem(null, trigger.width, trigger.height)
        var at = popupOrigin()
        // The panel normally fills the popup, but nothing forces it to.
        var self = morph.mapToItem(null, 0, 0)

        originX = topLeft.x - at.x - self.x
        originY = topLeft.y - at.y - self.y
        originWidth = bottomRight.x - topLeft.x
        originHeight = bottomRight.y - topLeft.y
        originRadius = cornerOf(trigger)
    }

    function show() {
        closeAnim.stop()
        // Reopening in the middle of a close turns the same shape around; any
        // other opening starts from the button as it is now.
        if (!popup || !popup.visible || shapeProgress === 0) {
            captureOrigin()
            shapeProgress = 0
            contentProgress = 0
        }
        if (popup) popup.visible = true
        openAnim.restart()
    }

    function hide() {
        openAnim.stop()
        if (popup && !popup.visible) {
            shapeProgress = 0
            contentProgress = 0
            return
        }
        closeAnim.restart()
    }

    // Opening again from a different button while already open, as the tray
    // does when the pointer moves to the next icon. A mapped popup keeps the
    // position it was created at, so it is unmapped and mapped again to land
    // under the new button, and the shape starts over from there.
    function replay() {
        openAnim.stop()
        closeAnim.stop()
        if (popup) popup.visible = false
        captureOrigin()
        shapeProgress = 0
        contentProgress = 0
        if (popup) popup.visible = true
        openAnim.restart()
    }

    onOpenChanged: open ? show() : hide()
    Component.onCompleted: if (open) show()

    // Opening: the shape leads, on a bezier fitted to a critically damped
    // spring (within 2% of 1 - (1 + wt)e^-wt, settling in the 260ms). That is
    // a spring with exactly enough damping not to overshoot: it gathers pace
    // from rest, covers two thirds of the way in the first 80ms and settles
    // long, without the bounce OutBack used to add. The content waits until
    // the shape is about three quarters there.
    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            target: morph
            property: "shapeProgress"
            to: 1
            duration: 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 0.3, 0.15, 1.0, 1, 1]
        }

        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation {
                target: morph
                property: "contentProgress"
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }

    // Closing is shorter and accelerates into the button: nobody waits to
    // watch a panel leave. The content goes first so the shape never folds
    // over readable text.
    ParallelAnimation {
        id: closeAnim

        NumberAnimation {
            target: morph
            property: "shapeProgress"
            to: 0
            duration: 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.3, 0.0, 0.8, 0.15, 1, 1]
        }

        NumberAnimation {
            target: morph
            property: "contentProgress"
            to: 0
            duration: 90
            easing.type: Easing.InQuad
        }

        onFinished: if (!morph.open && morph.popup) morph.popup.visible = false
    }

    GlassPanel {
        id: shape

        // Whole pixels: a 1px border on a fractional edge smears into two
        // faint ones for the whole flight.
        x: Math.round(morph.lerp(morph.originX, 0, morph.shapeProgress))
        y: Math.round(morph.lerp(morph.originY, 0, morph.shapeProgress))
        width: Math.round(morph.lerp(morph.originWidth, morph.width, morph.shapeProgress))
        height: Math.round(morph.lerp(morph.originHeight, morph.height, morph.shapeProgress))
        radius: morph.lerp(morph.originRadius, Theme.cornerRadius, morph.shapeProgress)
        // A button-sized slab of panel colour would appear and vanish in one
        // frame at either end; the first stretch of travel fades it instead.
        opacity: Math.min(1, morph.shapeProgress * 4)
        clip: true

        // Pinned to the panel, not to the shape: the shape moves over it.
        // GlassPanel already insets its children by 4px, which is where this
        // lands at rest, so the content gets exactly the room it had before.
        Item {
            id: content
            x: -shape.x
            y: -shape.y
            width: morph.width - 8
            height: morph.height - 8
            opacity: morph.contentProgress
        }
    }
}
