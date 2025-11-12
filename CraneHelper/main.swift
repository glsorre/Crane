//
//  main.swift
//  CraneHelper
//
//  Created by Giuseppe Lucio Sorrentino on 12/11/25.
//

import Foundation
import ContainerPlugin
import Foundation

let isRegistered = try ServiceManager.isRegistered(fullServiceLabel: "com.apple.container.apiserver")
print(isRegistered)
exit(isRegistered ? 1 : 0)
