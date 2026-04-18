import SwiftUI

enum Spacing {
    static let xxxs: CGFloat = 2   // Inside tight components
    static let xxs: CGFloat = 4    // Table cell padding, component internals
    static let xs: CGFloat = 6     // Between related items in a group
    static let sm: CGFloat = 8     // Card/popover internal padding
    static let subsection: CGFloat = 10 // Between stacked subsection groups
    static let md: CGFloat = 12    // Between sections, HStack splits
    static let lg: CGFloat = 14    // Comfortable vertical padding (headers, toolbars)
}
