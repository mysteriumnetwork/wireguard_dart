import Foundation
import os.log

public extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let main = Logger(subsystem: subsystem, category: "main")
}
