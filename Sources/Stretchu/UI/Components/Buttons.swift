import SwiftUI

/// Primary button: height 28, radius 7, system accent color.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Color.accentColor.opacity(configuration.isPressed ? 0.75 : 1)))
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))
    }
}

/// Secondary button: height 28, radius 7, 14 % white fill.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Color.white.opacity(configuration.isPressed ? 0.22 : 0.14)))
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))
    }
}

/// Destructive action (giving up a cycle): red outline, never a red fill.
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.red.opacity(configuration.isPressed ? 0.7 : 1))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
            .overlay(RoundedRectangle(cornerRadius: Radius.control).stroke(Color.red.opacity(0.8), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))
    }
}

/// Discreet action: text only, 50 % opacity ("Skip", "Another one").
struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.8 : 0.55))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(minHeight: 28, maxHeight: 28)
            .contentShape(Rectangle())
    }
}

/// Menu action row: 26 pt, radius 6, full accent color for the main action.
struct MenuRowButtonStyle: ButtonStyle {
    var isPrimary = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(isPrimary ? Color.white : Color.white.opacity(0.88))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(
                isPrimary ? Color.accentColor.opacity(configuration.isPressed ? 0.75 : 1)
                          : Color.white.opacity(configuration.isPressed ? 0.12 : 0)))
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))
    }
}

extension ButtonStyle where Self == TextButtonStyle {
    static var text: TextButtonStyle { TextButtonStyle() }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Panel typography: title 14 semibold, caption 11.5 at 55 %, tabular digits.
extension View {
    func panelTitle() -> some View {
        font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
    }

    /// 11.5 pt caption without the one-line limit (panel body).
    func freeCaption() -> some View {
        font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.55))
    }

    func panelCaption() -> some View {
        font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.55)).lineLimit(1)
    }
}
