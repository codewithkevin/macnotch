import AppKit

// Small wrapper around the private CoreGraphics "Spaces" API.
//
// `.canJoinAllSpaces` + `.stationary` keeps a window on every Space, but during
// the Space-switch *animation* the window still slides with the desktop. Adding
// the window to a dedicated high-level CGSSpace pins it so it stays welded to
// the notch through the swipe.
//
// Adapted from https://github.com/avaidyam/Parrot (MPL-2.0) via
// TheBoredTeam/boring.notch.

private typealias CGSConnectionID = UInt
private typealias CGSSpaceID = UInt64

@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSSpaceCreate")
private func CGSSpaceCreate(_ cid: CGSConnectionID, _ unknown: Int, _ options: NSDictionary?) -> CGSSpaceID

@_silgen_name("CGSSpaceDestroy")
private func CGSSpaceDestroy(_ cid: CGSConnectionID, _ space: CGSSpaceID)

@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)

@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

@_silgen_name("CGSRemoveWindowsFromSpaces")
private func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

@_silgen_name("CGSShowSpaces")
private func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)

@_silgen_name("CGSHideSpaces")
private func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)

final class CGSSpace {
    private let identifier: CGSSpaceID

    var windows: Set<NSWindow> = [] {
        didSet {
            let remove = oldValue.subtracting(windows)
            let add = windows.subtracting(oldValue)
            let cid = _CGSDefaultConnection()
            CGSRemoveWindowsFromSpaces(cid, remove.map { $0.windowNumber } as NSArray, [identifier])
            CGSAddWindowsToSpaces(cid, add.map { $0.windowNumber } as NSArray, [identifier])
        }
    }

    init(level: Int = Int(Int32.max)) {
        let cid = _CGSDefaultConnection()
        // flag MUST be 1, otherwise Finder starts drawing desktop icons on it.
        identifier = CGSSpaceCreate(cid, 0x1, nil)
        CGSSpaceSetAbsoluteLevel(cid, identifier, level)
        CGSShowSpaces(cid, [identifier])
    }

    deinit {
        let cid = _CGSDefaultConnection()
        CGSHideSpaces(cid, [identifier])
        CGSSpaceDestroy(cid, identifier)
    }
}
