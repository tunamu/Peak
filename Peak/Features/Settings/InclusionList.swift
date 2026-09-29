import PeakDesign
import SwiftUI

/// List sections for "pick some of these, in this order": the chosen items first (drag to reorder), then the rest.
/// Used by Set Workout (movements) and Set Routine (workouts). Put it inside a `List` whose edit mode is active, so the
/// chosen section shows drag handles.
struct InclusionSections<Item: Identifiable, Trailing: View>: View {
    let chosenTitle: LocalizedStringKey
    let othersTitle: LocalizedStringKey
    /// Shown while nothing is chosen, such as "Tick the movements to include."
    let emptyHint: LocalizedStringKey
    /// Every item, in the order the "others" section shows them.
    let items: [Item]
    /// The chosen items' ids, in their order.
    @Binding var chosen: [Item.ID]
    let title: (Item) -> String
    /// Extra controls for a chosen row, such as a set stepper.
    @ViewBuilder let trailing: (Item) -> Trailing

    var body: some View {
        Section {
            if chosen.isEmpty {
                Text(emptyHint)
                    .font(.peakRow)
                    .foregroundStyle(.peakTextTertiary)
            }
            ForEach(chosenItems) { item in
                row(item, isChosen: true)
            }
            .onMove { chosen.move(fromOffsets: $0, toOffset: $1) }
        } header: {
            Text(chosenTitle)
        }

        let others = items.filter { !chosen.contains($0.id) }
        if !others.isEmpty {
            Section {
                ForEach(others) { item in
                    row(item, isChosen: false)
                }
            } header: {
                Text(othersTitle)
            }
        }
    }

    private var chosenItems: [Item] {
        chosen.compactMap { id in items.first { $0.id == id } }
    }

    private func row(_ item: Item, isChosen: Bool) -> some View {
        HStack(spacing: Spacing.small) {
            Button {
                if isChosen {
                    chosen.removeAll { $0 == item.id }
                } else {
                    chosen.append(item.id)
                }
            } label: {
                HStack(spacing: Spacing.small) {
                    Image(systemName: isChosen ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isChosen ? .peakTextPrimary : .peakTextSecondary)
                        .accessibilityHidden(true)
                    Text(verbatim: title(item))
                        .foregroundStyle(.peakTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: Metrics.minTouchTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isChosen ? .isSelected : [])

            if isChosen {
                trailing(item)
            }
        }
        .font(.peakRow)
    }
}
