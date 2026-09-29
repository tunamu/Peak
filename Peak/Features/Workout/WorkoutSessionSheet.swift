import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// The running workout. For now only its name, the timer and Discard: logging sets, pause and Finish arrive with the
/// Workout Session screen (F6).
struct WorkoutSessionSheet: View {
    let session: WorkoutSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isDiscardConfirmationShown = false

    var body: some View {
        VStack(spacing: Spacing.large) {
            VStack(spacing: Spacing.xxSmall) {
                Text(verbatim: session.title)
                    .font(.peakEmphasis)
                    .foregroundStyle(.peakTextPrimary)
                Text(
                    timerInterval: session.startedAt.addingTimeInterval(session.pausedTotal)...Date.distantFuture,
                    countsDown: false
                )
                .font(.peakSectionTitle)
                .monospacedDigit()
                .foregroundStyle(.peakTextPrimary)
                Text("Logging sets is coming soon.")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextTertiary)
            }
            .multilineTextAlignment(.center)

            GlassEffectContainer(spacing: Spacing.medium) {
                HStack(spacing: Spacing.medium) {
                    Button(role: .destructive) {
                        isDiscardConfirmationShown = true
                    } label: {
                        Text("Discard").frame(maxWidth: .infinity)
                    }
                    Button {
                        dismiss()
                    } label: {
                        Text("Close").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.peakGlass)
            }
        }
        .padding(Spacing.large)
        .fittedSheet()
        .confirmationDialog(
            "Discard this workout?", isPresented: $isDiscardConfirmationShown, titleVisibility: .visible
        ) {
            Button("Discard Workout", role: .destructive) {
                SessionRepository(context: modelContext).discard(session)
                try? modelContext.save()
                dismiss()
            }
        }
    }
}
