import Cocoa
import Combine

final class RecordManager: ObservableObject {
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var recordedEvents: [CGEvent] = []

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func startRecording() {
        guard !isRecording else { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.rightMouseUp.rawValue)
            | (1 << CGEventType.mouseMoved.rawValue)

        let tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
            let manager = Unmanaged<RecordManager>.fromOpaque(refcon!).takeUnretainedValue()
            manager.handle(event: event, ofType: type)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(eventMask),
                                          callback: tapCallback,
                                          userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())) else {
            NSLog("Failed to create event tap. Ensure the app has accessibility permissions.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        isRecording = true
        recordedEvents.removeAll()
    }

    func stopRecording() {
        guard isRecording else { return }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
        isRecording = false
    }

    private func handle(event: CGEvent, ofType type: CGEventType) {
        // Placeholder for serializing CGEvents. Clone events so they can be replayed later.
        guard isRecording else { return }
        if let copiedEvent = event.copy() {
            recordedEvents.append(copiedEvent)
        }
    }
}
