import SwiftUI

public extension DesignTokens {
    enum Motion {
        public static let quick = Animation.spring(duration: 0.2, bounce: 0)
        public static let standard = Animation.spring(duration: 0.3, bounce: 0.1)
        public static let present = Animation.spring(duration: 0.35, bounce: 0.14)
        public static let pop = Animation.spring(duration: 0.34, bounce: 0.28)
        public static let reduced = Animation.easeOut(duration: 0.15)
        public static let ringFade = Animation.easeOut(duration: 0.1)
    }
}
