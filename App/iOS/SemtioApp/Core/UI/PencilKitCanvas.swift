import SwiftUI
import PencilKit

struct PencilKitCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    var isUserInteractionEnabled: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isUserInteractionEnabled = isUserInteractionEnabled
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isUserInteractionEnabled
        
        // Manage ToolPicker visibility
        if isUserInteractionEnabled {
            toolPicker.setVisible(true, forFirstResponder: uiView)
            toolPicker.addObserver(canvasView)
            uiView.becomeFirstResponder()
        } else {
            toolPicker.setVisible(false, forFirstResponder: uiView)
            toolPicker.removeObserver(canvasView)
            uiView.resignFirstResponder()
        }
    }
}
