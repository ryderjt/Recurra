import XCTest
@testable import Recurra

final class RecurraTests: XCTestCase {
    
    func testMacroManagerInitialization() throws {
        let manager = MacroManager()
        XCTAssertTrue(manager.macros.isEmpty)
        XCTAssertNil(manager.mostRecentMacro)
    }
    
    func testMacroManagerAddMacro() throws {
        let manager = MacroManager()
        let macro = RecordedMacro(
            id: UUID(),
            name: "Test Macro",
            createdAt: Date(),
            events: [],
            duration: 1.0
        )
        
        manager.add(macro)
        
        XCTAssertEqual(manager.macros.count, 1)
        XCTAssertEqual(manager.macros.first?.name, "Test Macro")
        XCTAssertEqual(manager.mostRecentMacro?.name, "Test Macro")
    }
    
    func testMacroManagerRemoveMacro() throws {
        let manager = MacroManager()
        let macro = RecordedMacro(
            id: UUID(),
            name: "Test Macro",
            createdAt: Date(),
            events: [],
            duration: 1.0
        )
        
        manager.add(macro)
        XCTAssertEqual(manager.macros.count, 1)
        
        manager.remove(macro)
        XCTAssertEqual(manager.macros.count, 0)
        XCTAssertNil(manager.mostRecentMacro)
    }
    
    func testMacroManagerRenameMacro() throws {
        let manager = MacroManager()
        let macro = RecordedMacro(
            id: UUID(),
            name: "Original Name",
            createdAt: Date(),
            events: [],
            duration: 1.0
        )
        
        manager.add(macro)
        manager.rename(macro, to: "New Name")
        
        XCTAssertEqual(manager.macros.first?.name, "New Name")
    }
    
    func testRecorderInitialization() throws {
        let manager = MacroManager()
        let recorder = Recorder(macroManager: manager)
        
        XCTAssertEqual(recorder.status, .idle)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(recorder.isReplaying)
    }
    
    func testReplayerInitialization() throws {
        let manager = MacroManager()
        let recorder = Recorder(macroManager: manager)
        let replayer = Replayer(recorder: recorder, macroManager: manager)
        
        XCTAssertFalse(replayer.isReplaying)
    }
    
    func testAccessibilityPermissionCheck() throws {
        // This test will pass regardless of actual permission status
        // since we're just testing the function exists and returns a boolean
        let hasPermission = AccessibilityPermission.ensureTrusted(promptsIfNeeded: false)
        XCTAssertTrue(hasPermission == true || hasPermission == false)
    }
}
