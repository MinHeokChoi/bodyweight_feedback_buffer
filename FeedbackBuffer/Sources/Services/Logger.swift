import Foundation
import os

enum AppLog {
    private static let subsystem = "com.julyheuk.feedbackbuffer"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
