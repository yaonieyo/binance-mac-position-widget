import AppKit
import SwiftUI

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ nsView: DragView, context: Context) {}

    final class DragView: NSView {
        override var isOpaque: Bool { false }
        override var mouseDownCanMoveWindow: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { self }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
