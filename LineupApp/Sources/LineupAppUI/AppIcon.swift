import AppKit

/// The app's icon, shipped as a resource of this target. A built app also carries it in its bundle
/// for the Finder and the Dock; setting it here gives a run from the command line the same icon.
public enum AppIcon {
    /// Shows the icon in the Dock. Does nothing if the resource is missing, since the icon is decoration.
    @MainActor public static func apply() {
        guard let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url) else { return }
        NSApplication.shared.applicationIconImage = image
    }
}
