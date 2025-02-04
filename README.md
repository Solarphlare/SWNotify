# SWNotify
Watch for file system events in directories in Swift on Linux.

## Supported Platforms
- Any version of Linux that can run Swift

### What's Not Supported
- Apple platforms — this package won't work on Apple platforms due to its use of the `inotify` API. If developing for macOS, please use the [FSEvents](https://developer.apple.com/documentation/coreservices/file_system_events) API in CoreServices instead.

## Requirements
- Swift 5 or newer
- A C compiler (you probably have one if you're writing Swift)

## Installation
Add the following to your Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/CominAtYou/SWNotify", from: "1.0.0")
]
```

## Usage
First, set up notifiers for the direcrories you want:
```swift
// Monitor all supported events at /some/path
try Notifier.default.addNotifier(for: "/some/path", events: [.create, .rename, .delete, .moveFrom, .moveTo])

// Monitor for file creation events at ProcessWorkingDirectory/some/other/path
try Notifier.default.addNotifier(for: "some/other/path", events: [.create])
```
> [!NOTE]
> Any path you pass to an `addNotifer` call must actually exist at the time of the call, otherwise `NotifierError.noSuchDirectory` will be thrown by the `addNotifer` call.

Next, register callbacks to be called for specific events. You can register multiple callbacks for each event.
```swift
// Called whenever a file is created in a watched directory
Notifier.default.addOnFileCreateCallback { path in
    print("File created: \(path)") // /some/path/somefile.txt
}

// Called whenever a file in a watched directory is renamed
Notifier.default.addOnFileRenameCallback { oldPath, newPath in
    print("File renamed: \(oldPath) -> \(newPath)")
}

// Called whenever a file in a watched directory is deleted (i.e., rm or unlink(2))
// Note that this is not called when a file is moved by a user to their desktop environment's trash bin.
// Instead, onFileMoveFrom will be called.
Notifier.default.addOnFileDeleteCallback { path in
    print("File deleted: \(path)")
}

// Called whenever a file is moved out of a watched directory
Notifier.default.addOnFileMoveFromCallback { path in
    print("File moved from directory: \(path)")
}

// Called whenever a file is moved into a watched directory
Notifier.default.addOnFileMoveToCallback { path in
    print("File moved in to directory: \(path)")
}
```
You can stop a callback from being called by deregistering it. Callbacks can be deregistered by passing the UUID returned by an `add[some]Callback(_:)` call to `Notifier.default.removeCallback(forCallbackId:)`.
```swift
let callbackId = Notifier.default.addOnFileDeleteCallback { path in
    // ...
}

Notifier.default.removeCallback(forCallbackId: callbackId); // Removes the callback that was just registered.
```

## Configuration
- `Notifier.default.includeAbsolutePathsInEvents`
    - Type: `Bool`
    - Default: `false`
    - Description: Specify whether or not callbacks should include the absolute path of the target file(s) when an event occurs. If `false`, callbacks will only include the name of the file.

## Building
Clone the repository, cd into it, and run `swift build`.

## Roadmap
- Ability to add callbacks for only certain directories
- Support for macOS via the FSEvents API
