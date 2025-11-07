//
//  Item.swift
//  AntiEmoPet
//
//  Created by Selena Yang on 07/11/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
