import SwiftUI

/// A segmented control that looks and moves like the week strip: a glass capsule with the selected segment in a pill.
/// The selected title is primary, the others secondary. Tap a segment, or grab the pill and drag it along; it swells
/// while dragged. Used where the system segmented control would not match, such as the Analysis pages.
public struct GlassSegmentedPicker<Value: Hashable>: View {
    public struct Segment {
        let value: Value
        let title: LocalizedStringKey

        public init(_ title: LocalizedStringKey, value: Value) {
            self.title = title
            self.value = value
        }
    }

    @Binding private var selection: Value
    private let segments: [Segment]

    @State private var width: CGFloat = 0
    @State private var isDragging = false

    /// Space between the capsule's edge and the pill, as in the week strip.
    private let inset: CGFloat = 4
    private static var space: String { "GlassSegmentedPicker" }

    public init(selection: Binding<Value>, segments: [Segment]) {
        _selection = selection
        self.segments = segments
    }

    public var body: some View {
        let selectedIndex = segments.firstIndex { $0.value == selection }

        HStack(spacing: 0) {
            ForEach(segments, id: \.value) { segment in
                button(for: segment)
            }
        }
        .padding(inset)
        .background(alignment: .leading) {
            // The pill, like the week strip's selected day. It slides between segments and swells while dragged.
            if let selectedIndex {
                Capsule()
                    .fill(.peakFillControl)
                    .frame(width: slot)
                    .padding(.vertical, inset)
                    .scaleEffect(isDragging ? 1.1 : 1)
                    .offset(x: inset + CGFloat(selectedIndex) * slot)
                    .animation(.smooth(duration: 0.25), value: selectedIndex)
                    .animation(.spring(duration: 0.3, bounce: 0.4), value: isDragging)
            }
        }
        .overlay(alignment: .leading) {
            // Grabbing the pill drags it along; this sits over the pill only, so the other segments stay tappable.
            if let selectedIndex {
                Capsule()
                    .fill(.clear)
                    .contentShape(.capsule)
                    .frame(width: slot)
                    .offset(x: inset + CGFloat(selectedIndex) * slot)
                    .highPriorityGesture(dragPill)
                    .accessibilityHidden(true)
            }
        }
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            width = $0
        }
        .glassEffect(.regular, in: .capsule)
        // Fixed segments cannot grow with the text: capped like the week strip, with the large content viewer on a
        // long press at accessibility sizes. Callers name it `peak.capped.*` for the accessibility audit.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
    }

    /// Width of one segment inside the capsule.
    private var slot: CGFloat {
        segments.isEmpty ? 0 : max(0, width - 2 * inset) / CGFloat(segments.count)
    }

    private var dragPill: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                isDragging = true
                guard slot > 0 else { return }
                let index = min(max(Int((value.location.x - inset) / slot), 0), segments.count - 1)
                if segments[index].value != selection {
                    selection = segments[index].value
                }
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    private func button(for segment: Segment) -> some View {
        let isSelected = segment.value == selection

        return Button {
            selection = segment.value
        } label: {
            Text(segment.title)
                .font(.peakCardValue)
                .foregroundStyle(isSelected ? .peakTextPrimary : .peakTextSecondary)
                .lineLimit(1)
                .padding(.horizontal, Spacing.xSmall)
                .frame(maxWidth: .infinity, minHeight: Metrics.minTouchTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
