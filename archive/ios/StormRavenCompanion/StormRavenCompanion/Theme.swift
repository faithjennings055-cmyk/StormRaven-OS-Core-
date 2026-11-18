import SwiftUI

/// StormRaven dark — deep slate surfaces, storm-cyan accent.
enum Theme {
    static let background   = Color(red: 0.055, green: 0.065, blue: 0.09)   // near-black slate
    static let surface      = Color(red: 0.10,  green: 0.115, blue: 0.15)   // card
    static let surfaceAlt   = Color(red: 0.145, green: 0.16,  blue: 0.21)   // raised card
    static let accent       = Color(red: 0.20,  green: 0.78,  blue: 0.91)   // storm cyan
    static let accentWarm   = Color(red: 0.95,  green: 0.62,  blue: 0.28)   // ember (warnings)
    static let ok           = Color(red: 0.30,  green: 0.85,  blue: 0.55)   // online green
    static let danger       = Color(red: 0.94,  green: 0.35,  blue: 0.38)   // offline red
    static let textPrimary  = Color(red: 0.92,  green: 0.94,  blue: 0.97)
    static let textDim      = Color(red: 0.55,  green: 0.60,  blue: 0.68)
}
