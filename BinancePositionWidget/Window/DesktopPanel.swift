import AppKit

final class DesktopPanel: NSPanel {
    private var dragStartMouseLocation: NSPoint?
    private var dragStartOrigin: NSPoint?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if isInDragArea(event.locationInWindow) {
                dragStartMouseLocation = NSEvent.mouseLocation
                dragStartOrigin = frame.origin
                return
            }
        case .leftMouseDragged:
            if let dragStartMouseLocation, let dragStartOrigin {
                let current = NSEvent.mouseLocation
                let delta = NSPoint(
                    x: current.x - dragStartMouseLocation.x,
                    y: current.y - dragStartMouseLocation.y
                )
                setFrameOrigin(NSPoint(
                    x: dragStartOrigin.x + delta.x,
                    y: dragStartOrigin.y + delta.y
                ))
                return
            }
        case .leftMouseUp:
            if dragStartMouseLocation != nil {
                dragStartMouseLocation = nil
                dragStartOrigin = nil
                return
            }
        default:
            break
        }

        super.sendEvent(event)
    }

    private func isInDragArea(_ point: NSPoint) -> Bool {
        let headerHeight: CGFloat = 44
        let controlsWidth: CGFloat = 132
        let isHeader = point.y >= frame.height - headerHeight
        let isOutsideControls = point.x <= frame.width - controlsWidth
        return isHeader && isOutsideControls
    }
}
