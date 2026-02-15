import SwiftUI
import AppKit

/// A small floating indicator that appears near the text cursor during recording.
/// Shows a green mic icon when recording is active.
class RecordingIndicatorWindow {
    static let shared = RecordingIndicatorWindow()
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<RecordingIndicatorView>?
    private let indicatorSize: CGFloat = 40
    
    enum IndicatorState {
        case recording // Green mic - recording
    }
    
    func show(at fallbackLocation: NSPoint) {
        // Try to get text cursor position, fallback to mouse
        let cursorPosition: NSPoint
        if let textPos = getTextCursorPosition() {
            print("[RecordingIndicator] Using text cursor position: \(textPos)")
            cursorPosition = textPos
        } else {
            print("[RecordingIndicator] Fallback to mouse position: \(fallbackLocation)")
            cursorPosition = fallbackLocation
        }
        
        // Create the view
        let indicatorView = RecordingIndicatorView()
        let hosting = NSHostingView(rootView: indicatorView)
        
        // Position: above the text cursor
        let origin = NSPoint(
            x: cursorPosition.x,
            y: cursorPosition.y + 5
        )
        
        let frame = NSRect(
            origin: origin,
            size: NSSize(width: indicatorSize, height: indicatorSize)
        )
        
        let newPanel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.level = .floating
        newPanel.hasShadow = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = false
        newPanel.contentView = hosting
        newPanel.orderFront(nil)
        
        // Animate in
        newPanel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            newPanel.animator().alphaValue = 1.0
        }
        
        self.panel = newPanel
        self.hostingView = hosting
    }
    
    func updateState(_ newState: IndicatorState) {
        guard let hosting = hostingView else { return }
        hosting.rootView = RecordingIndicatorView()
    }
    
    func hide() {
        guard let panel = panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.panel = nil
            self?.hostingView = nil
        })
    }
    
    // MARK: - Text Cursor Position via Accessibility API
    
    private func getTextCursorPosition() -> NSPoint? {
        let systemElement = AXUIElementCreateSystemWide()
        
        // Step 1: Get focused application
        var focusedAppValue: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemElement, kAXFocusedApplicationAttribute as CFString, &focusedAppValue)
        guard appResult == .success, let focusedApp = focusedAppValue else {
            // Normal fallback — some apps don't support AX or no app is focused
            return nil
        }
        
        // Step 2: Get focused UI element
        var focusedElementValue: AnyObject?
        let elemResult = AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElementValue)
        guard elemResult == .success, let focusedElement = focusedElementValue else {
            print("[RecordingIndicator] ❌ Failed to get focused element: \(elemResult.rawValue)")
            return nil
        }
        
        let element = focusedElement as! AXUIElement
        
        // Step 3: Get selected text range (caret position)
        var rangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        guard rangeResult == .success, let range = rangeValue else {
            print("[RecordingIndicator] ❌ Failed to get selected text range: \(rangeResult.rawValue)")
            return nil
        }
        
        // Step 4: Get bounds for the caret range
        var boundsValue: AnyObject?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &boundsValue)
        guard boundsResult == .success, let bounds = boundsValue else {
            print("[RecordingIndicator] ❌ Failed to get bounds for range: \(boundsResult.rawValue)")
            return nil
        }
        
        // Step 5: Extract CGRect
        var caretRect = CGRect.zero
        guard AXValueGetValue(bounds as! AXValue, .cgRect, &caretRect) else {
            print("[RecordingIndicator] ❌ Failed to extract CGRect from AXValue")
            return nil
        }
        
        print("[RecordingIndicator] AX caret rect (top-left origin): \(caretRect)")
        
        // Validate the rect is not zero
        guard caretRect.origin.x != 0 || caretRect.origin.y != 0 || caretRect.width != 0 || caretRect.height != 0 else {
            print("[RecordingIndicator] ❌ Caret rect is zero, discarding")
            return nil
        }
        
        // Step 6: Convert AX coordinates (top-left origin) to NSScreen coordinates (bottom-left origin)
        // Find the screen that contains this point
        let axPoint = caretRect.origin
        var targetScreen: NSScreen? = nil
        for screen in NSScreen.screens {
            // NSScreen.frame is in bottom-left coordinates, but we need to check against AX coords
            // Convert screen frame to top-left coordinates for comparison
            let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
            let screenTopLeftY = mainScreenHeight - screen.frame.maxY
            let screenRectInAX = CGRect(
                x: screen.frame.origin.x,
                y: screenTopLeftY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            if screenRectInAX.contains(axPoint) {
                targetScreen = screen
                break
            }
        }
        
        guard let screen = targetScreen ?? NSScreen.main else {
            print("[RecordingIndicator] ❌ Could not find screen for caret position")
            return nil
        }
        
        // Convert: AX y (top-left) → NS y (bottom-left)
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let nsY = mainScreenHeight - caretRect.origin.y - caretRect.height
        
        let result = NSPoint(x: caretRect.origin.x, y: nsY)
        print("[RecordingIndicator] ✅ Converted to NS coords: \(result)")
        return result
    }
}

struct RecordingIndicatorView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Animated background rings
            Circle()
                .fill(Color.green.opacity(0.15))
                .scaleEffect(isAnimating ? 1.4 : 1.0)
                .opacity(isAnimating ? 0 : 0.6)
            
            Circle()
                .fill(Color.green.opacity(0.1))
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 0 : 0.4)
            
            // Main Glassmorphic background
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
            
            // Mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse)
        }
        .frame(width: 36, height: 36)
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
