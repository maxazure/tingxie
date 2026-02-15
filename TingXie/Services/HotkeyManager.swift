import Cocoa
import Foundation

class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?
    
    private var hotkeyCode: Int64 {
        Int64(AppSettings.shared.hotkeyCode)
    }
    
    private var isHotkeyPressed = false
    
    func start() {
        // Clean up any previous event tap first
        stop()
        
        // Prompt for accessibility permission if not granted
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        
        if AXIsProcessTrusted() {
            setupEventTap()
        } else {
            // Trigger the system prompt
            AXIsProcessTrustedWithOptions(options)
            print("[HotkeyManager] Accessibility permission not granted. Waiting for user to grant access...")
            print("[HotkeyManager] 请在 系统设置 → 隐私与安全性 → 辅助功能 中授权 TingXie")
            
            // Retry every 2 seconds until granted
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.retryTimer = nil
                    print("[HotkeyManager] Accessibility permission granted!")
                    self?.setupEventTap()
                }
            }
        }
    }
    
    private func setupEventTap() {
        // Already set up
        guard eventTap == nil else { return }
        
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        // Store self as a pointer for the C callback
        let userInfo = Unmanaged.passRetained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            print("[HotkeyManager] Failed to create event tap. Check Accessibility permissions.")
            Unmanaged<HotkeyManager>.fromOpaque(userInfo).release()
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        print("[HotkeyManager] ✅ Global hotkey listener started (keyCode: \(hotkeyCode))")
        print("[HotkeyManager] 按住右 Option 键开始录音")
    }
    
    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isHotkeyPressed = false
        print("[HotkeyManager] Global hotkey listener stopped")
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle flagsChanged for modifier keys (like Option)
        if type == .flagsChanged {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            
            // Debug: log ALL modifier key events
            print("[HotkeyManager] 🔑 flagsChanged: keyCode=\(keyCode), flags=\(flags.rawValue), alternate=\(flags.contains(.maskAlternate)), target=\(hotkeyCode)")
            
            if keyCode == hotkeyCode {
                // Right Option key: check if Option flag is present
                let isPressed = flags.contains(.maskAlternate)
                
                if isPressed && !isHotkeyPressed {
                    isHotkeyPressed = true
                    print("[HotkeyManager] 🎤 Hotkey DOWN - starting recording")
                    DispatchQueue.main.async { [weak self] in
                        self?.onKeyDown?()
                    }
                    return nil // Consume the event
                } else if !isPressed && isHotkeyPressed {
                    isHotkeyPressed = false
                    print("[HotkeyManager] ⏹ Hotkey UP - stopping recording")
                    DispatchQueue.main.async { [weak self] in
                        self?.onKeyUp?()
                    }
                    return nil // Consume the event
                }
            }
        }
        
        // If the tap is disabled by the system, re-enable it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            print("[HotkeyManager] ⚠️ Event tap was disabled, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    deinit {
        stop()
    }
}

