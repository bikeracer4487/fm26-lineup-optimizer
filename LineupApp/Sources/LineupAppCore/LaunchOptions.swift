/// Why the app's arguments could not be read, as a sentence for the terminal.
public struct LaunchOptionsError: Error, Equatable, CustomStringConvertible {
    public let description: String
}

/// What the app was started with: `--pictures <directory>` draws the screens and exits;
/// `--sample-data <repository root>` uses the engine's sample squads instead of the owner's files.
public struct LaunchOptions: Equatable, Sendable {
    public var picturesDirectory: String?
    public var sampleDataRoot: String?

    public init(picturesDirectory: String?, sampleDataRoot: String?) {
        self.picturesDirectory = picturesDirectory; self.sampleDataRoot = sampleDataRoot
    }

    public static func parse(_ arguments: [String]) throws(LaunchOptionsError) -> LaunchOptions {
        var options = LaunchOptions(picturesDirectory: nil, sampleDataRoot: nil)
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            let value = index + 1 < arguments.count && !arguments[index + 1].hasPrefix("--") ? arguments[index + 1] : nil
            switch argument {
            case "--pictures":
                guard let value else {
                    throw LaunchOptionsError(description: "--pictures needs one directory, for example --pictures .build/pictures")
                }
                guard options.picturesDirectory == nil else { throw LaunchOptionsError(description: "--pictures was given twice.") }
                options.picturesDirectory = value
            case "--sample-data":
                guard let value else {
                    throw LaunchOptionsError(description: "--sample-data needs the repository's root, for example --sample-data ..")
                }
                guard options.sampleDataRoot == nil else { throw LaunchOptionsError(description: "--sample-data was given twice.") }
                options.sampleDataRoot = value
            default:
                throw LaunchOptionsError(description: "The argument \"\(argument)\" is not known. "
                    + "The options are --pictures <directory> and --sample-data <repository root>.")
            }
            index += 2
        }
        return options
    }
}
