import Foundation
import CNotify

public enum NotifierError: Error {
    case noSuchDirectory
    case accessDenied
    case invalidTarget
    case failedToAddNotifier
    case failedToRemoveNotifier
}

public enum FileSystemEvent: Int32 {
    case create = 0x0100
    case delete = 0x0200
    case modify = 0x0002
    case moveFrom = 0x0040
    case moveTo = 0x0080
    case rename = 0x00C0
}

fileprivate func expandPath(_ path: String) -> String {
    let expandedTildePath = NSString(string: path).expandingTildeInPath
    let absolutePath = URL(fileURLWithPath: expandedTildePath).standardizedFileURL.path
    return absolutePath
}

public class Notifier {
    private static let _default = Notifier()
    private var watches: [String: Int32] = [:]
    private var watchesReversed: [Int32: String] = [:]

    private var createCallbacks: [UUID : (String) -> Void] = [:]
    private var deleteCallbacks: [UUID : (String) -> Void] = [:]
    private var modifyCallbacks: [UUID : (String) -> Void] = [:]
    private var moveFromCallbacks: [UUID : (String) -> Void] = [:]
    private var moveToCallbacks: [UUID : (String) -> Void] = [:]
    private var renameCallbacks: [UUID : (String, String) -> Void] = [:]

    private let onFileCreated: @convention(c) (UnsafePointer<CChar>?, Int32) -> Void = { filename, wd in
       let filepath = (_default.includeAbsolutePathsInEvents ? "\(expandPath(_default.watchesReversed[wd]!))/" : "") + String(cString: filename!)
        _default.createCallbacks.values.forEach { $0(filepath) }
    }

    private let onFileDeleted: @convention(c) (UnsafePointer<CChar>?, Int32) -> Void = { filename, wd in
        let filepath = (_default.includeAbsolutePathsInEvents ? "\(expandPath(_default.watchesReversed[wd]!))/" : "") + String(cString: filename!)
        _default.deleteCallbacks.values.forEach { $0(filepath) }
    }

    private let onFileModified: @convention(c) (UnsafePointer<CChar>?, Int32) -> Void = { filename, wd in
        let filepath = (_default.includeAbsolutePathsInEvents ? "\(expandPath(_default.watchesReversed[wd]!))/" : "") + String(cString: filename!)
        _default.modifyCallbacks.values.forEach { $0(filepath) }
    }

    private let onFileMovedFrom: @convention(c) (UnsafePointer<CChar>?, Int32) -> Void = { filename, wd in
        let filepath = (_default.includeAbsolutePathsInEvents ? "\(expandPath(_default.watchesReversed[wd]!))/" : "") + String(cString: filename!)
        _default.moveFromCallbacks.values.forEach { $0(filepath) }
    }

    private let onFileMovedTo: @convention(c) (UnsafePointer<CChar>?, Int32) -> Void = { filename, wd in
        let filepath = (_default.includeAbsolutePathsInEvents ? "\(expandPath(_default.watchesReversed[wd]!))/" : "") + String(cString: filename!)
        _default.moveToCallbacks.values.forEach { $0(filepath) }
    }

    private let onFileRenamed: @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, Int32) -> Void = { oldFilename, newFilename, wd in
        let fullPath = expandPath(_default.watchesReversed[wd]!)
        let oldFilepath = (_default.includeAbsolutePathsInEvents ? "\(fullPath)/" : "") + String(cString: oldFilename!)
        let newFilepath = (_default.includeAbsolutePathsInEvents ? "\(fullPath)/" : "") + String(cString: newFilename!)
        _default.renameCallbacks.values.forEach { $0(oldFilepath, newFilepath) }
    }

    /// The default notifier instance. Use this to interact with the notifier.
    public class var `default`: Notifier {
        get {
            return _default
        }
    }

    /// Whether or not to include full paths in events. If false (the default value), only the filename will be included in events.
    public var includeAbsolutePathsInEvents = false;

    private init() {
        let result = notifier_init()
        if result != 0 {
            print("Failed to initialize notifier")
        }
        else {
            set_callback(onFileCreated, FileSystemEvent.create.rawValue)
            set_callback(onFileDeleted, FileSystemEvent.delete.rawValue)
            set_callback(onFileModified, FileSystemEvent.modify.rawValue)
            set_callback(onFileMovedFrom, 0x0040)
            set_callback(onFileMovedTo, 0x0080)
            set_rename_callback(onFileRenamed)

            start_notifier()
        }
    }

    /// Add a notifier for specific events from a given path.
    /// - Parameters:
    /// for: The path to watch for events.
    /// events: The events to watch for.
    /// - Throws:
    /// `NotifierError.noSuchDirectory` if the path does not exist.
    /// `NotifierError.accessDenied` if the path is not accessible.
    /// `NotifierError.failedToAddNotifier` if the notifier could not be added.
    public func addNotifier(for path: String, events: [FileSystemEvent]) throws {
        let eventMask = events.reduce(0) { $0 | $1.rawValue }
        let watchId = add_watch(path, eventMask);

        guard watchId >= 0 else {
            switch watchId {
            case -1:
                throw NotifierError.noSuchDirectory
            case -2:
                throw NotifierError.accessDenied
            default:
                throw NotifierError.failedToAddNotifier
            }
        }

        self.watches[path] = watchId
        self.watchesReversed[watchId] = path

        var isDirectory = false
        let _ = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

        if (!isDirectory) {
            throw NotifierError.invalidTarget
        }
    }

    /// Remove a notifier for a given path.
    /// - Parameters:
    /// for: The path to remove the notifier for.
    /// - Throws: NotifierError.failedToRemoveNotifier if the notifier could not be removed.
    public func removeNotifier(for path: String) throws {
        guard let watchId = self.watches[path] else {
            throw NotifierError.failedToRemoveNotifier
        }

        guard remove_watch(watchId) != 0 else {
            throw NotifierError.failedToRemoveNotifier
        }

        self.watches.removeValue(forKey: path)
        self.watchesReversed.removeValue(forKey: watchId)
    }

    /// Add a callback to be called when a file is created.
    /// - Parameters:
    /// callback: The callback to be called when a file is created. The callback takes the path of the created file as a parameter.
    /// - Returns: A UUID that can be used to remove the callback.
    @discardableResult
    public func addOnFileCreateCallback(_ callback: @escaping (String) -> Void) -> UUID {
        let callbackIdentifier = UUID()
        self.createCallbacks[callbackIdentifier] = callback

        return callbackIdentifier
    }

    /// Add a callback to be called when a file is deleted.
    /// - Parameters:
    /// callback: The callback to be called when a file is deleted. Takes callback takes the path of the deleted file as an argument.
    /// - Returns: A UUID that can be used to remove the callback.
    @discardableResult
    public func addOnFileDeleteCallback(_ callback: @escaping (String) -> Void) -> UUID {
        let callbackIdentifier = UUID()
        self.deleteCallbacks[callbackIdentifier] = callback

        return callbackIdentifier
    }

    /// Add a callback to be called when a file is modified.
    /// - Parameters:
    /// callback: The callback to be called when a file is modified. The callback takes the path of the modified file as an argument.
    /// - Returns: A UUID that can be used to remove the callback.
    @discardableResult
    public func addOnFileModifyCallback(_ callback: @escaping (String) -> Void) -> UUID {
        let callbackIdentifier = UUID()
        self.modifyCallbacks[callbackIdentifier] = callback

        return callbackIdentifier
    }

    /// Add a callback to be called when a file is moved from a watched directory.
    /// - Parameters:
    /// callback: The callback to be called when a file is moved from a watched directory. The callback takes the old path of the file as an argument.
    /// - Returns: A `UUID` that can be used to remove the callback.
    /// - Discussion:
    @discardableResult
    public func addOnFileMoveFromCallback(_ callback: @escaping (String) -> Void) -> UUID {
        let callbackIdentifier = UUID()
        self.moveFromCallbacks[callbackIdentifier] = callback

        return callbackIdentifier
    }

    /// Add a callback to be called when a file is moved to a watched directory.
    /// - Parameters:
    /// callback: The callback to be called when a file is moved to a watched directory. The callback takes the new path of the file as an argument.
    /// - Returns: A `UUID` that can be used to remove the callback.
    @discardableResult
    public func addOnFileMoveToCallback(_ callback: @escaping (String) -> Void) -> UUID {
        let callbackIdentifier = UUID()
        self.moveToCallbacks[callbackIdentifier] = callback

        return callbackIdentifier
    }

    /// Add a callback to be called when a file is renamed.
    /// - Parameters:
    /// callback: The callback to be called when a file is renamed. The callback takes the old path and the new path of the file as arguments.
    /// - Returns: A `UUID` that can be used to remove the callback.
    @discardableResult
    public func addOnFileRenameCallback(_ callback: @escaping (String, String) -> Void) -> UUID {
        let callbackIdentifier = UUID()
        self.renameCallbacks[callbackIdentifier] = callback

        return callbackIdentifier
    }

    /// Remove a callback for a given identifier.
    /// - Parameter identifier: The identifier of the callback to remove.
    public func removeCallback(forCallbackId identifier: UUID) {
        self.createCallbacks.removeValue(forKey: identifier)
        self.deleteCallbacks.removeValue(forKey: identifier)
        self.modifyCallbacks.removeValue(forKey: identifier)
        self.moveFromCallbacks.removeValue(forKey: identifier)
        self.moveToCallbacks.removeValue(forKey: identifier)
        self.renameCallbacks.removeValue(forKey: identifier)
    }
}
