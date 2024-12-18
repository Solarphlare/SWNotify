import XCTest
import SWNotify

class PackageTests: XCTestCase {
    private let tempDirectory = FileManager.default.temporaryDirectory.path
    private let directoryPath = "\(FileManager.default.temporaryDirectory.path)/SWNotifyTestDirectory"

    override class func setUp() {
        try! FileManager.default.createDirectory(atPath: "\(FileManager.default.temporaryDirectory.path)/SWNotifyTestDirectory", withIntermediateDirectories: false, attributes: nil)
    }

    override class func tearDown() {
        try? FileManager.default.removeItem(atPath: "\(FileManager.default.temporaryDirectory.path)/SWNotifyTestDirectory")
    }

    func testFileCreate() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.create])

        let filePath = "\(directoryPath)/\(UUID().uuidString)"

        Notifier.default.addOnFileCreateCallback { path in
            if path == filePath {
                XCTAssertTrue(true)
            }
        }

        let _ = FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

        Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            XCTFail("File creation callback was not called.")
        }
    }

    func testFileDelete() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.delete])

        let filePath = "\(directoryPath)/\(UUID().uuidString)"

        let _ = FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

        Notifier.default.addOnFileDeleteCallback { path in
            if path == filePath {
                XCTAssertTrue(true)
            }
        }

        try FileManager.default.removeItem(atPath: filePath)

        Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            XCTFail("File deletion callback was not called.")
        }
    }

    func testFileModify() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.modify])

        let filePath = "\(directoryPath)/\(UUID().uuidString)"

        let _ = FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

        Notifier.default.addOnFileModifyCallback { path in
            if path == filePath {
                XCTAssertTrue(true)
            }
        }

        try "Hello world!".write(toFile: filePath, atomically: false, encoding: .utf8)

        Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            XCTFail("File modification callback was not called.")
        }
    }

    func testFileMoveFrom() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.moveFrom])

        let filePath = "\(directoryPath)/\(UUID().uuidString)"

        let _ = FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

        Notifier.default.addOnFileMoveFromCallback { path in
            if path == filePath {
                XCTAssertTrue(true)
            }
        }

        let newFilePath = "\(tempDirectory)/\(UUID().uuidString)"
        try FileManager.default.moveItem(atPath: filePath, toPath: newFilePath)

        Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            XCTFail("File move from callback was not called.")
        }
    }

    func testFileMoveTo() throws {
        try Notifier.default.addNotifier(for: directoryPath, events: [.moveTo])
        let fileUUID = UUID().uuidString

        let initialCreationFilePath = "\(tempDirectory)/\(fileUUID)"
        let targetFilePath = "\(directoryPath)/\(fileUUID)"

        Notifier.default.addOnFileMoveToCallback { path in
            if path == targetFilePath {
                XCTAssertTrue(true)
            }
        }

        let _ = FileManager.default.createFile(atPath: initialCreationFilePath, contents: nil, attributes: nil)

        try FileManager.default.moveItem(atPath: initialCreationFilePath, toPath: targetFilePath)

        Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            XCTFail("File move to callback was not called.")
        }
    }

    func testFileRename() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.path
        let directoryPath = "\(tempDirectory)/SWNotifyTestDirectory"

        try Notifier.default.addNotifier(for: directoryPath, events: [.rename])
        let fileUUID = UUID().uuidString

        let oldFilePath = "\(directoryPath)/\(fileUUID)"
        let newFilePath = "\(directoryPath)/\(UUID().uuidString)"

        let _ = FileManager.default.createFile(atPath: oldFilePath, contents: nil, attributes: nil)

        Notifier.default.addOnFileRenameCallback { oldPath, newPath in
            if oldPath == oldFilePath && newPath == newFilePath {
                XCTAssertTrue(true)
            }
        }

        try FileManager.default.moveItem(atPath: oldFilePath, toPath: newFilePath)

        Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            XCTFail("File rename callback was not called.")
        }
    }
}
