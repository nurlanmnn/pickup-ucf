import SwiftUI

/// Keyboard controls rendered as an in-layout accessory instead of a system
/// keyboard toolbar. `safeAreaInset` reserves this bar's height, preventing it
/// from floating over composers or bottom action bars on newer iOS versions.
/// Source: https://developer.apple.com/videos/play/wwdc2021/10021/
private struct FormKeyboardAccessory: View {
    var canGoPrevious: Bool = false
    var canGoNext: Bool = false
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: Spacing.m) {
                if showsFieldNavigation {
                    Button("Previous", action: onPrevious)
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(!canGoPrevious)
                        .accessibilityLabel("Previous field")
                    Button("Next", action: onNext)
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(!canGoNext)
                        .accessibilityLabel("Next field")
                }

                Spacer(minLength: Spacing.m)

                Button("Done", action: onDone)
                    .frame(minWidth: 44, minHeight: 44)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Done")
            }
            .padding(.horizontal, Spacing.m)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .background(.ultraThinMaterial)
        .tint(AppColor.gold)
    }

    private var showsFieldNavigation: Bool {
        canGoPrevious || canGoNext
    }
}

private struct FormKeyboardAccessoryModifier: ViewModifier {
    let isPresented: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onDone: () -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isPresented {
                    FormKeyboardAccessory(
                        canGoPrevious: canGoPrevious,
                        canGoNext: canGoNext,
                        onPrevious: onPrevious,
                        onNext: onNext,
                        onDone: onDone
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: isPresented)
    }
}

extension View {
    func formKeyboardAccessory(
        isPresented: Bool,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        onPrevious: @escaping () -> Void = {},
        onNext: @escaping () -> Void = {},
        onDone: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            FormKeyboardAccessoryModifier(
                isPresented: isPresented,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                onPrevious: onPrevious,
                onNext: onNext,
                onDone: onDone
            )
        )
    }
}
