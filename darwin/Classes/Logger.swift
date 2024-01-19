import Foundation
import os.log

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    public static let main = Logger(subsystem: subsystem, category: "main")
}
