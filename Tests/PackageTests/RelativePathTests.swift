import XCTest
import SWNotify

class RelativePathTests: XCTestCase {
    private let tempDirectory = FileManager.default.temporaryDirectory.path
    private let directoryPath = "\(FileManager.default.temporaryDirectory.path)/SWNotifyTestDirectory"

    override class func setUp() {
        try? FileManager.default.createDirectory(atPath: "\(FileManager.default.temporaryDirectory.path)/SWNotifyTestDirectory", withIntermediateDirectories: false, attributes: nil)
        Notifier.default.includeAbsolutePathsInEvents = false // Necessary because `swift test` apparently will reuse the object from AbsolutePathTests, which has this property set to true
    }

    override class func tearDown() {
        try? FileManager.default.removeItem(atPath: "\(FileManager.default.temporaryDirectory.path)/SWNotifyTestDirectory")
    }

    func testFileCreate() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.create])
        let filename = UUID().uuidString

        let expectation = self.expectation(description: "File creation callback")

        Notifier.default.addOnFileCreateCallback { file in
            if file == filename {
                expectation.fulfill()
            }
        }

        // Using data to write to a file instead of FileManager, because FileManager does not trigger the create event
        try Data().write(to: URL(fileURLWithPath: "\(directoryPath)/\(filename)"))

        waitForExpectations(timeout: 2) { error in
            if let error = error {
                XCTFail("File creation callback was not called: \(error)")
            }
        }
    }

    func testFileDelete() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.delete])

        let filename = UUID().uuidString
        let filePath = "\(directoryPath)/\(filename)"

        let expectation = self.expectation(description: "File deletion callback")

        let _ = FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

        Notifier.default.addOnFileDeleteCallback { file in
            if file == filename {
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

        let filename = UUID().uuidString
        let filePath = "\(directoryPath)/\(filename)"

        let expectation = self.expectation(description: "File modification callback")

        let _ = FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

        Notifier.default.addOnFileModifyCallback { file in
            if file == filename {
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

        let filename = UUID().uuidString
        let initialFilePath = "\(directoryPath)/\(filename)"

        let expectation = self.expectation(description: "File move from callback")

        let _ = FileManager.default.createFile(atPath: initialFilePath, contents: nil, attributes: nil)

        Notifier.default.addOnFileMoveFromCallback { file in
            if file == filename {
                expectation.fulfill()
            }
        }

        let movedFilePath = "\(tempDirectory)/\(UUID().uuidString)"
        try FileManager.default.moveItem(atPath: initialFilePath, toPath: movedFilePath)

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

        Notifier.default.addOnFileMoveToCallback { file in
            if file == fileUUID {
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

        let oldFileUUID = UUID().uuidString
        let newFileUUID = UUID().uuidString

        let oldFilePath = "\(directoryPath)/\(oldFileUUID)"
        let newFilePath = "\(directoryPath)/\(newFileUUID)"

        let expectation = self.expectation(description: "File rename callback")

        let _ = FileManager.default.createFile(atPath: oldFilePath, contents: nil, attributes: nil)

        Notifier.default.addOnFileRenameCallback { oldFile, newFile in
            if oldFile == oldFileUUID && newFile == newFileUUID {
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
