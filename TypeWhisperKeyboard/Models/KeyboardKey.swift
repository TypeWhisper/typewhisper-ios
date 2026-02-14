import Foundation
import CoreGraphics

enum KeyboardKeyType {
    case letter
    case shift
    case delete
    case returnKey
    case space
    case mic
    case globe
    case language
    case numberToggle
    case symbolToggle
}

struct KeyboardKey: Identifiable {
    let id: String
    let type: KeyboardKeyType
    let label: String
    let weight: CGFloat

    init(type: KeyboardKeyType, label: String, weight: CGFloat = 1.0) {
        self.id = "\(type)-\(label)"
        self.type = type
        self.label = label
        self.weight = weight
    }
}
