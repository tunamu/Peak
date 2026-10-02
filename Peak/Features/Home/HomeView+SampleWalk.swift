#if DEBUG
    import PeakCore
    import SwiftData

    extension HomeView {
        /// `-PeakStartWalk YES`: throws away the running workout and starts a walk (made if missing), to see C-12.
        static func startSampleWalk(in context: ModelContext, templates: [WorkoutTemplate], rule: ProgressionRule) {
            let sessions = SessionRepository(context: context)
            if let current = try? sessions.current() {
                sessions.discard(current)
            }
            let repository = TemplateRepository(context: context)
            let template: WorkoutTemplate
            if let walking = templates.first(where: { $0.name == "Walking" }) {
                template = walking
            } else {
                guard
                    let walk = try? ExerciseRepository(context: context)
                        .findOrCreate(name: "Incline Walk", kind: .cardio),
                    let created = try? repository.create(name: "Walking", kind: .cardio)
                else { return }
                repository.setItems([(walk, 1)], of: created)
                template = created
            }
            let session = sessions.start(from: template, rule: rule)
            if let segment = session.orderedExercises.first?.orderedSegments.first {
                segment.speedKmh = 5.5
                segment.inclinePercent = 12
                segment.durationSec = 1_800
            }
            try? context.save()
        }
    }
#endif
