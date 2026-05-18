//
//  Log.swift
//  Crane
//

import Foundation
import os.log

enum Log {
    static let subsystem: String = Bundle.main.bundleIdentifier ?? "me.rightright.RightCrane"

    static let launch        = Logger(subsystem: subsystem, category: "Launch")
    static let serviceHelper = Logger(subsystem: subsystem, category: "ServiceHelper")
    static let containers    = Logger(subsystem: subsystem, category: "ContainersStore")
    static let images        = Logger(subsystem: subsystem, category: "ImagesStore")
    static let networks      = Logger(subsystem: subsystem, category: "NetworksStore")
    static let volumes       = Logger(subsystem: subsystem, category: "VolumesStore")
    static let details       = Logger(subsystem: subsystem, category: "Details")
    static let build         = Logger(subsystem: subsystem, category: "Build")
    static let run           = Logger(subsystem: subsystem, category: "Run")
    static let logs          = Logger(subsystem: subsystem, category: "LogStream")
    static let rosetta       = Logger(subsystem: subsystem, category: "Rosetta")
}
