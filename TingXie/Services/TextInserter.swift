import Cocoa
import Foundation

class TextInserter {
    func insert(text: String) {
        guard !text.isEmpty else {
            print("[TextInserter] Empty text, skipping insertion")
            return
        }
        
        let pasteboard = NSPasteboard.general
        
        // Save current clipboard content
        let previousContents = savePasteboardContents(pasteboard)
        
        // Set new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Small delay to ensure clipboard is ready
        usleep(50_000) // 50ms
        
        // Simulate Cmd+V
        simulatePaste()
        
        // Restore original clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.restorePasteboardContents(pasteboard, contents: previousContents)
            print("[TextInserter] Clipboard restored")
        }
        
        print("[TextInserter] Inserted text: \(text)")
    }
    
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key code 9 = 'V'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Clipboard Save/Restore
    
    private struct PasteboardItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }
    
    private func savePasteboardContents(_ pasteboard: NSPasteboard) -> [PasteboardItem] {
        var items: [PasteboardItem] = []
        
        guard let types = pasteboard.types else { return items }
        
        for type in types {
            if let data = pasteboard.data(forType: type) {
                items.append(PasteboardItem(type: type, data: data))
            }
        }
        
        return items
    }
    
    private func restorePasteboardContents(_ pasteboard: NSPasteboard, contents: [PasteboardItem]) {
        pasteboard.clearContents()
        
        if contents.isEmpty {
            return
        }
        
        for item in contents {
            pasteboard.setData(item.data, forType: item.type)
        }
    }
}
