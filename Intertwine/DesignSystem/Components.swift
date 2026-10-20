import SwiftUI

// MARK: - Button (Figma: Button — Style = Primary / Secondary / Tertiary)

enum ButtonKind {
    case primary, secondary, tertiary
}

/// Full-width 50pt button. Shows the Pressed state while held and the Disabled state when
/// `.disabled(true)` is applied, matching the Figma Button variants.
struct AppButtonStyle: ButtonStyle {
    var kind: ButtonKind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.button)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, Space.lg)
            .foregroundStyle(foreground)
            .background(background(pressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(isEnabled ? Palette.borderDefault : Palette.borderSubtle, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        guard isEnabled else { return Palette.textDisabled }
        return kind == .primary ? Palette.textOnAccent : Palette.textSecondary
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary:
            if !isEnabled { return Palette.bgDisabled }
            return pressed ? Palette.bgAccentPressed : Palette.bgAccent
        case .secondary:
            return pressed && isEnabled ? Palette.bgAccentSubtle : Palette.bgSurface
        case .tertiary:
            return pressed && isEnabled ? Palette.bgAccentSubtle : .clear
        }
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    static var primary: AppButtonStyle { AppButtonStyle(kind: .primary) }
    static var secondary: AppButtonStyle { AppButtonStyle(kind: .secondary) }
    static var tertiary: AppButtonStyle { AppButtonStyle(kind: .tertiary) }
}

// MARK: - Text field (Figma: Text Field)

/// Label above the field so it stays visible while typing. Shows an error message in place
/// of the helper text when `error` is set.
struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var helper: String? = nil
    var error: String? = nil
    var multiline: Bool = false
    /// Hides what's typed, for passwords.
    var secure: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label)
                .font(Typo.footnote)
                .foregroundStyle(Palette.textSecondary)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else if multiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(2...5)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(Typo.body)
            .foregroundStyle(Palette.textPrimary)
            .focused($focused)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 13)
            .frame(minHeight: 48)
            .background(Palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: (focused || error != nil) ? 2 : 1)
            }
            if let error {
                Text(error)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.textError)
            } else if let helper {
                Text(helper)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return Palette.borderError }
        return focused ? Palette.borderFocus : Palette.borderDefault
    }
}

/// A read-only or control-based field that uses the same label + box styling as `LabeledField`.
struct FieldBox<Content: View>: View {
    let label: String
    var helper: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label)
                .font(Typo.footnote)
                .foregroundStyle(Palette.textSecondary)
            HStack {
                content
            }
            .font(Typo.body)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(Palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(Palette.borderDefault, lineWidth: 1)
            }
            if let helper {
                Text(helper)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }
}

// MARK: - Status badge (Figma: Status Badge)

enum BadgeKind {
    case draft, published, needsInfo, issue
    case attending, declined, replyNeeded
    case bought, noRSVP

    var label: String {
        switch self {
        case .bought: "Bought"
        case .noRSVP: "No RSVP needed"
        case .draft: "Draft"
        case .published: "Published"
        case .needsInfo: "Needs info"
        case .issue: "Issue"
        case .attending: "Attending"
        case .declined: "Can’t go"
        case .replyNeeded: "Reply needed"
        }
    }

    var colors: (background: Color, foreground: Color) {
        switch self {
        case .draft, .declined, .noRSVP: (Palette.bgAccentSubtle, Palette.textSecondary)
        case .published, .attending, .bought: (Palette.bgSuccess, Palette.textSuccess)
        case .needsInfo, .replyNeeded: (Palette.bgWarning, Palette.textWarning)
        case .issue: (Palette.bgError, Palette.textError)
        }
    }
}

struct StatusBadge: View {
    let kind: BadgeKind

    var body: some View {
        Text(kind.label)
            .font(Typo.footnote)
            .foregroundStyle(kind.colors.foreground)
            .padding(.horizontal, Space.xs)
            .padding(.vertical, Space.xxs)
            .background(kind.colors.background, in: Capsule())
            .fixedSize()
    }
}

// MARK: - Surfaces

/// Rounded surface card with a subtle border (Figma: Information panel).
struct Panel<Content: View>: View {
    var background: Color = Palette.bgSurface
    var bordered: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            if bordered {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Palette.borderSubtle, lineWidth: 1)
            }
        }
    }
}

/// A group of list rows inside one rounded container, separated by dividers.
struct RowGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Palette.borderSubtle, lineWidth: 1)
        }
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.borderSubtle)
            .frame(height: 1)
            .padding(.leading, Space.md)
    }
}

// MARK: - List row (Figma: List Row)

struct ListRow: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: Space.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.iconPrimary)
                    .frame(width: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Typo.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.iconInactive)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

// MARK: - Event card (Figma: Event Card)

struct EventCard: View {
    let title: String
    let date: String
    let location: String
    let badge: BadgeKind
    let trailing: String
    var photo: Image? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .top, spacing: Space.sm) {
                CoverPlaceholder(photo: photo, height: 64, cornerRadius: Radius.md)
                    .frame(width: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typo.title3)
                        .foregroundStyle(Palette.textPrimary)
                    Text(date)
                        .font(Typo.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                    Text(location)
                        .font(Typo.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            HStack {
                StatusBadge(kind: badge)
                Spacer()
                Text(trailing)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(Space.md)
        .background(Palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Palette.borderSubtle, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

/// Event photo (usually `WeddingEvent.coverPhoto`), or a stand-in when there isn't one.
struct CoverPlaceholder: View {
    var photo: Image? = nil
    var height: CGFloat = 150
    var cornerRadius: CGFloat = Radius.lg

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Palette.bgAccentSubtle)
            .frame(height: height)
            .overlay {
                if let photo {
                    photo
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: height > 100 ? 28 : 18))
                        .foregroundStyle(Palette.iconInactive)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Step progress (Figma: Step Progress)

struct StepProgress: View {
    let step: Int
    let total: Int
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Step \(step) of \(total) · \(name)")
                .font(Typo.footnote)
                .foregroundStyle(Palette.textSecondary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.bgAccentSubtle)
                    Capsule().fill(Palette.bgAccent)
                        .frame(width: proxy.size.width * CGFloat(step) / CGFloat(total))
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Headers and small pieces

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var eyebrow: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            if let eyebrow {
                Text(eyebrow)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
            Text(title)
                .font(Typo.largeTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(Typo.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Typo.title3)
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Bento tile used on the couple Home screen.
struct StatTile: View {
    let value: String
    let label: String
    var large: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer(minLength: 0)
            Text(value)
                .font(large ? Typo.largeTitle : Typo.title3)
                .foregroundStyle(Palette.textPrimary)
            Text(label)
                .font(Typo.footnote)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(Palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Palette.borderSubtle, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Key–value line used in summaries ("When", "Where"…).
struct InfoLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typo.footnote)
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Large check mark used on success screens.
struct SuccessMark: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(Palette.textSuccess)
            .frame(width: 72, height: 72)
            .background(Palette.bgSuccess, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Screen scaffolding

extension View {
    /// Standard scrolling screen: canvas background and screen margins.
    func screenStyle() -> some View {
        self
            .padding(.horizontal, Space.screen)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Pins one or two buttons to the bottom of the screen (Figma: Sheet Footer).
    func pinnedFooter<Footer: View>(@ViewBuilder _ footer: () -> Footer) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Space.xxs) {
                footer()
            }
            .padding(.horizontal, Space.screen)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xs)
            .background(Palette.bgCanvas)
            .overlay(alignment: .top) {
                Rectangle().fill(Palette.borderSubtle).frame(height: 1)
            }
        }
    }
}
