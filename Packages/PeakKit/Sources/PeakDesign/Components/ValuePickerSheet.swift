import SwiftUI

/// A sheet that changes one setting with a wheel picker: current value, "New Goal" picker, Reset and Update.
/// Used by the step goal, water goal and rep goal sheets (S-02, S-03, S-04).
///
/// Reset saves `defaultValue`; Update saves the picked value. Both close the sheet.
public struct ValuePickerSheet<Value: Hashable>: View {
    public struct Titles {
        let title: LocalizedStringKey
        let pickerLabel: LocalizedStringKey
        let reset: LocalizedStringKey
        let update: LocalizedStringKey
        let footnote: LocalizedStringKey?

        /// - Parameters:
        ///   - title: What is being changed, such as "Daily Step Goal".
        ///   - pickerLabel: The label above the picker, such as "New Goal".
        ///   - footnote: An explanation under the current value, such as how progressive overload works.
        public init(
            _ title: LocalizedStringKey,
            pickerLabel: LocalizedStringKey,
            reset: LocalizedStringKey,
            update: LocalizedStringKey,
            footnote: LocalizedStringKey? = nil
        ) {
            self.title = title
            self.pickerLabel = pickerLabel
            self.reset = reset
            self.update = update
            self.footnote = footnote
        }
    }

    private let titles: Titles
    private let current: Value
    private let defaultValue: Value
    private let options: [Value]
    private let format: (Value) -> String
    private let onSave: (Value) -> Void

    @State private var selection: Value
    @Environment(\.dismiss) private var dismiss

    public init(
        titles: Titles,
        current: Value,
        defaultValue: Value,
        options: [Value],
        format: @escaping (Value) -> String,
        onSave: @escaping (Value) -> Void
    ) {
        self.titles = titles
        self.current = current
        self.defaultValue = defaultValue
        self.options = options
        self.format = format
        self.onSave = onSave
        _selection = State(initialValue: current)
    }

    public var body: some View {
        VStack(spacing: Spacing.medium) {
            VStack(spacing: Spacing.xxSmall) {
                Text(titles.title)
                    .font(.peakCardLabel)
                    .foregroundStyle(.peakTextSecondary)
                Text(verbatim: format(current))
                    .font(.peakCardValue)
                    .monospacedDigit()
                    .foregroundStyle(.peakTextPrimary)
            }
            .accessibilityElement(children: .combine)

            if let footnote = titles.footnote {
                Text(footnote)
                    .font(.peakRow)
                    .foregroundStyle(.peakTextSecondary)
            }

            VStack(spacing: 0) {
                Text(titles.pickerLabel)
                    .font(.peakCardLabel)
                    .foregroundStyle(.peakTextSecondary)
                    .accessibilityHidden(true)
                Picker(selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(verbatim: format(option))
                            .monospacedDigit()
                            .tag(option)
                    }
                } label: {
                    Text(titles.pickerLabel)
                }
                .wheelPickerStyle()
            }

            GlassEffectContainer(spacing: Spacing.medium) {
                HStack(spacing: Spacing.medium) {
                    Button(role: .destructive) {
                        save(defaultValue)
                    } label: {
                        Text(titles.reset).frame(maxWidth: .infinity)
                    }
                    .disabled(current == defaultValue)

                    Button(role: .confirm) {
                        save(selection)
                    } label: {
                        Text(titles.update).frame(maxWidth: .infinity)
                    }
                    .disabled(selection == current)
                }
                .buttonStyle(.peakGlass)
            }
        }
        .multilineTextAlignment(.center)
        .padding(Spacing.large)
        .fittedSheet()
    }

    private func save(_ value: Value) {
        onSave(value)
        dismiss()
    }
}

extension View {
    // The wheel style exists only on iOS; the package also builds on a Mac host for `swift test`.
    fileprivate func wheelPickerStyle() -> some View {
        #if os(iOS)
            pickerStyle(.wheel)
        #else
            self
        #endif
    }
}
