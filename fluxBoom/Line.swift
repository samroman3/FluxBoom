//
//  Line.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//

import SwiftUI

struct Line: Identifiable {
    var id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}
