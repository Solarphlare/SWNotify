import XCTest
import SWNotify

class AbsolutePathTests: XCTestCase {
    private let tempDirectory = FileManager.default.temporaryDirectory.path
    private let directoryPath = "\(FileManager.default.temporaryDirectory.path)/SWNotifyTestDirectory"

    override class func setUp() {
        try? FileManager.default.createDirectory(atPath: "\(FileManager.default.temporaryDirectory.path)/SWNotifyTestDirectory", withIntermediateDirectories: false, attributes: nil)
        Notifier.default.includeAbsolutePathsInEvents = true
    }

    override class func tearDown() {
        try? FileManager.default.removeItem(atPath: "\(FileManager.default.temporaryDirectory.path)/SWNotifyTestDirectory")
    }

    func testFileCreate() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.create])

        let filePath = "\(directoryPath)/\(UUID().uuidString)"
        let expectation = self.expectation(description: "File creation callback")

        Notifier.default.addOnFileCreateCallback { path in
            if path == filePath {
                expectation.fulfill()
            }
        }

        // Using data to write to a file instead of FileManager, because FileManager does not trigger the create event
        try Data().write(to: URL(fileURLWithPath: filePath))

        waitForExpectations(timeout: 2) { error in
            if let error = error {
                XCTFail("File creation callback was not called: \(error)")
            }
        }
    }

    func testFileDelete() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.delete])

        let filePath = "\(directoryPath)/\(UUID().uuidString)"
        let _ = FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

        let expectation = self.expectation(description: "File deletion callback")

        Notifier.default.addOnFileDeleteCallback { path in
            if path == filePath {
                expectation.fulfill()
            }
        }

        try FileManager.default.removeItem(atPath: filePath)

        waitForExpectations(timeout: 2) { error in
            if let error = error {
                XCTFail("File deletion callback was not called: \(error)")
            }
        }
    }

    func testFileModify() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.modify])

        let filePath = "\(directoryPath)/\(UUID().uuidString)"
        let _ = FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

        let expectation = self.expectation(description: "File modification callback")

        Notifier.default.addOnFileModifyCallback { path in
            if path == filePath {
                expectation.fulfill()
            }
        }

        try "Hello world!".write(toFile: filePath, atomically: false, encoding: .utf8)

        waitForExpectations(timeout: 2) { error in
            if let error = error {
                XCTFail("File modification callback was not called: \(error)")
            }
        }
    }

    func testFileMoveFrom() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.moveFrom])

        let filePath = "\(directoryPath)/\(UUID().uuidString)"
        let _ = FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

        let expectation = self.expectation(description: "File move from callback")

        Notifier.default.addOnFileMoveFromCallback { path in
            if path == filePath {
                expectation.fulfill()
            }
        }

        let newFilePath = "\(tempDirectory)/\(UUID().uuidString)"
        try FileManager.default.moveItem(atPath: filePath, toPath: newFilePath)

        waitForExpectations(timeout: 2) { error in
            if let error = error {
                XCTFail("File move from callback was not called: \(error)")
            }
        }
    }

    func testFileMoveTo() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.moveTo])

        let fileUUID = UUID().uuidString
        let initialCreationFilePath = "\(tempDirectory)/\(fileUUID)"
        let targetFilePath = "\(directoryPath)/\(fileUUID)"

        let expectation = self.expectation(description: "File move to callback")

        Notifier.default.addOnFileMoveToCallback { path in
            if path == targetFilePath {
                expectation.fulfill()
            }
        }

        let _ = FileManager.default.createFile(atPath: initialCreationFilePath, contents: nil, attributes: nil)

        try FileManager.default.moveItem(atPath: initialCreationFilePath, toPath: targetFilePath)

        waitForExpectations(timeout: 2) { error in
            if let error = error {
                XCTFail("File move to callback was not called: \(error)")
            }
        }
    }

    func testFileRename() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.rename])

        let fileUUID = UUID().uuidString
        let oldFilePath = "\(directoryPath)/\(fileUUID)"
        let newFilePath = "\(directoryPath)/\(UUID().uuidString)"

        let expectation = self.expectation(description: "File rename callback")

        let _ = FileManager.default.createFile(atPath: oldFilePath, contents: nil, attributes: nil)

        Notifier.default.addOnFileRenameCallback { oldPath, newPath in
            if oldPath == oldFilePath && newPath == newFilePath {
                expectation.fulfill()
            }
        }

        try FileManager.default.moveItem(atPath: oldFilePath, toPath: newFilePath)

        waitForExpectations(timeout: 2) { error in
            if let error = error {
                XCTFail("File rename callback was not called: \(error)")
            }
        }
    }
}
