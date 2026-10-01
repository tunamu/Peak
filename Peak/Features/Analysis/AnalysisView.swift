import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// Analysis tab (C-14, ADR 0020): Performance and History, chosen with the segmented control or by swiping between
/// them. Every number is computed from the completed sessions when the screen opens (docs/ANALYSIS.md).
struct AnalysisView: View {
    enum Page: String, CaseIterable, Hashable {
        case performance, history
    }

    enum Route: Hashable {
        case movement(key: String)
        case workout(id: String)
    }

    /// Switches to the Settings tab, where data is imported.
    let openSettings: () -> Void

    @Query(
        filter: #Predicate<WorkoutSession> { $0.statusRaw == "completed" },
        sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var page: Page? = .performance
    @State private var period = AnalysisPeriod.threeMonths
    @State private var path: [Route] = []
    /// A session opened from a chart or the history, shown read-only.
    @State private var reviewed: WorkoutSession?

    var body: some View {
        let analysis = sessions.map(\.analysisSession)
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                header(isEmpty: analysis.isEmpty)
                if analysis.isEmpty {
                    emptyState
                } else {
                    pages(analysis)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.peakCanvas)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                destination(for: route, in: analysis)
            }
        }
        .sheet(item: $reviewed) { CompletedWorkoutSheet(session: $0) }
        .peakHaptic(.selection, trigger: page)
        #if DEBUG
            .onAppear(perform: applyLaunchArguments)
        #endif
    }

    // MARK: Header and pages

    private func header(isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Analysis")
                .font(.peakScreenTitle)
                .foregroundStyle(.peakTextPrimary)
                .accessibilityAddTraits(.isHeader)
            if !isEmpty {
                Picker(
                    "Page",
                    selection: Binding(
                        get: { page ?? .performance },
                        set: { newPage in
                            withAnimation(.smooth) { page = newPage }
                        })
                ) {
                    Text("Performance").tag(Page.performance)
                    Text("History").tag(Page.history)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.top, Spacing.medium)
    }

    /// The two pages side by side, one screen wide each. Nothing inside a page scrolls sideways, so the swipe is
    /// always the pages' (ADR 0020).
    private func pages(_ analysis: [AnalysisSession]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Page.allCases, id: \.self) { page in
                    Group {
                        switch page {
                        case .performance:
                            PerformancePage(sessions: analysis, period: $period)
                        case .history:
                            HistoryPage(sessions: sessions) { reviewed = $0 }
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $page)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.peakTextSecondary)
                .accessibilityHidden(true)
            Text("Finish a workout or import your history to see your progress here.")
                .font(.peakRow)
                .foregroundStyle(.peakTextSecondary)
                .multilineTextAlignment(.center)
            Button("Import Workout Data", action: openSettings)
                .buttonStyle(.peakGlass)
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Details

    @ViewBuilder
    private func destination(for route: Route, in analysis: [AnalysisSession]) -> some View {
        switch route {
        case .movement(let key):
            if let movement = PerformanceAnalysis.movements(in: analysis).first(where: { $0.key == key }) {
                MovementDetailView(movement: movement, open: open)
            }
        case .workout(let id):
            if let workout = PerformanceAnalysis.workouts(in: analysis).first(where: { $0.id == id }) {
                WorkoutDetailView(workout: workout, open: open)
            }
        }
    }

    private func open(_ sessionID: UUID) {
        reviewed = sessions.first { $0.id == sessionID }
    }

    #if DEBUG
        /// Screenshot helpers: `-PeakAnalysisPage history`, `-PeakAnalysisMovement "Lat Pulldown"`.
        private func applyLaunchArguments() {
            let defaults = UserDefaults.standard
            if let forced = defaults.string(forKey: "PeakAnalysisPage").flatMap(Page.init(rawValue:)) {
                page = forced
            }
            if let name = defaults.string(forKey: "PeakAnalysisMovement") {
                path = [.movement(key: name.matchingKey)]
            }
        }
    #endif
}

#if DEBUG
    #Preview {
        AnalysisView {}
            .previewEnvironment()
    }
#endif
