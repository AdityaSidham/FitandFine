import SwiftUI

// MARK: - Color Palette

extension Color {
    // Brand
    static let ffSage       = Color(red: 0.545, green: 0.686, blue: 0.553)   // #8BAF8D
    static let ffMint       = Color(red: 0.784, green: 0.902, blue: 0.788)   // #C8E6C9
    static let ffMintLight  = Color(red: 0.929, green: 0.961, blue: 0.929)   // #EDF5ED

    // Surfaces
    static let ffWarmWhite   = Color(red: 0.980, green: 0.980, blue: 0.973)  // #FAFAF8
    static let ffWarmNeutral = Color(red: 0.961, green: 0.941, blue: 0.922)  // #F5F0EB

    // Accent
    static let ffTeal      = Color(red: 0.498, green: 0.749, blue: 0.749)    // #7FBFBF
    static let ffTealLight = Color(red: 0.878, green: 0.953, blue: 0.953)    // #E0F3F3

    // Macros
    static let ffProtein = Color(red: 0.482, green: 0.702, blue: 0.816)      // #7BB3D0
    static let ffCarbs   = Color(red: 0.910, green: 0.659, blue: 0.486)      // #E8A87C
    static let ffFat     = Color(red: 0.910, green: 0.549, blue: 0.549)      // #E88C8C

    // Text
    static let ffText1 = Color(red: 0.133, green: 0.133, blue: 0.133)        // #222222
    static let ffText2 = Color(red: 0.533, green: 0.533, blue: 0.533)        // #888888
    static let ffText3 = Color(red: 0.733, green: 0.733, blue: 0.733)        // #BBBBBB
}

// MARK: - Design Tokens

enum DS {
    static let cornerCard:   CGFloat = 20
    static let cornerPill:   CGFloat = 12
    static let paddingPage:  CGFloat = 20
    static let paddingCard:  CGFloat = 18
    static let shadowRadius: CGFloat = 12
    static let shadowOpacity: Double = 0.06
    static let shadowY:      CGFloat = 4
}

// MARK: - Card Modifiers

extension View {
    func ffCard(padding: CGFloat = DS.paddingCard, background: Color = .white) -> some View {
        self
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DS.cornerCard))
            .shadow(color: .black.opacity(DS.shadowOpacity), radius: DS.shadowRadius, y: DS.shadowY)
    }

    func ffCardNoPad(background: Color = .white) -> some View {
        self
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DS.cornerCard))
            .shadow(color: .black.opacity(DS.shadowOpacity), radius: DS.shadowRadius, y: DS.shadowY)
    }
}
