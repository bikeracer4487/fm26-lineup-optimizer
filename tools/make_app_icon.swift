// Draws the app icon's 1024-pixel master from the source artwork: the artwork fills the standard
// Mac icon body (824 of 1024 pixels, rounded corners) with a soft shadow, on a transparent canvas.
//
//   swift tools/make_app_icon.swift <source image> <output png>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: make_app_icon.swift <source image> <output png>\n".utf8))
    exit(2)
}
guard let source = NSImage(contentsOfFile: arguments[1]),
      let artwork = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("The source image could not be read: \(arguments[1])\n".utf8))
    exit(1)
}

let canvas = 1024
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let corner: CGFloat = 185
guard let context = CGContext(
    data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    FileHandle.standardError.write(Data("The drawing surface could not be made.\n".utf8))
    exit(1)
}
context.interpolationQuality = .high
let shape = CGPath(roundedRect: body, cornerWidth: corner, cornerHeight: corner, transform: nil)

// The shadow under the body, as the system's own icons have.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.35))
context.addPath(shape)
context.setFillColor(CGColor(gray: 0, alpha: 1))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(shape)
context.clip()
context.draw(artwork, in: body)
context.restoreGState()

guard let image = context.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("The icon could not be encoded.\n".utf8))
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: arguments[2]))
} catch {
    FileHandle.standardError.write(Data("The icon could not be written to \(arguments[2]): \(error.localizedDescription)\n".utf8))
    exit(1)
}
