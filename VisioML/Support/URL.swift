//
//  URL.swift
//  Visio ML
//
//  Created by Tom Charman on 5/8/2023.
//  Copyright © 2023 Gaspard+Bruno. All rights reserved.
//

import Foundation

fileprivate let imageExtensions: [String] = ["png", "jpg", "heic", "jpeg"]

extension URL {
  var isImage: Bool {
    return imageExtensions.contains(self.pathExtension.lowercased())
  }
}
