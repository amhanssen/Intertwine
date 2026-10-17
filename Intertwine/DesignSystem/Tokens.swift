import SwiftUI

/// Colors from the Figma "Color" variable collection.
/// Each name matches the variable's iOS code syntax in Figma, and each color set in
/// Assets.xcassets has a Light and a Dark appearance, so the app follows the phone's setting.
/// To change a color, edit design-tokens.json and run scripts/generate_colors.py.
enum Palette {
    // Backgrounds
    static let bgCanvas = Color("colorBgCanvas")
    static let bgSurface = Color("colorBgSurface")
    static let bgSunken = Color("colorBgSunken")
    static let bgAccent = Color("colorBgAccent")
    static let bgAccentPressed = Color("colorBgAccentPressed")
    static let bgAccentSubtle = Color("colorBgAccentSubtle")
    static let bgDisabled = Color("colorBgDisabled")
    static let bgSuccess = Color("colorBgSuccess")
    static let bgError = Color("colorBgError")
    static let bgWarning = Color("colorBgWarning")

    // Text
    static let textPrimary = Color("colorTextPrimary")
    static let textSecondary = Color("colorTextSecondary")
    static let textTertiary = Color("colorTextTertiary")
    static let textOnAccent = Color("colorTextOnAccent")
    static let textDisabled = Color("colorTextDisabled")
    static let textSuccess = Color("colorTextSuccess")
    static let textError = Color("colorTextError")
    static let textWarning = Color("colorTextWarning")

    // Borders
    static let borderSubtle = Color("colorBorderSubtle")
    static let borderDefault = Color("colorBorderDefault")
    static let borderFocus = Color("colorBorderFocus")
    static let borderError = Color("colorBorderError")

    // Icons
    static let iconPrimary = Color("colorIconPrimary")
    static let iconInactive = Color("colorIconInactive")
}

/// Spacing scale from the Figma "Spacing & Radius" collection (8-point grid).
enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40

    /// Left and right margin for screen content.
    static let screen: CGFloat = 24
}

/// Corner radii from the Figma "Spacing & Radius" collection.
enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

/// Type styles matching the Figma text styles.
/// Headings use the brand font (Elido). If the font isn't bundled yet, iOS falls back
/// to the system font automatically. Every style scales with Dynamic Type.
enum Typo {
    /// PostScript names of the brand heading font. Change these after adding the Elido
    /// font files to the project (see README).
    static let headingBold = "Elido-Bold"
    static let headingMedium = "Elido-Medium"

    static let largeTitle = Font.custom(headingBold, size: 34, relativeTo: .largeTitle).weight(.bold)
    static let title1 = Font.custom(headingBold, size: 28, relativeTo: .title).weight(.bold)
    static let title2 = Font.custom(headingBold, size: 22, relativeTo: .title2).weight(.bold)
    static let title3 = Font.custom(headingMedium, size: 20, relativeTo: .title3).weight(.medium)

    static let headline = Font.headline
    static let body = Font.body
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote
    static let caption = Font.caption
    static let button = Font.headline
}
