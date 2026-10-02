import Foundation

extension MuscleGroup {
    /// A guess from the movement's name, for exercises whose group was never set: spreadsheet imports leave it as
    /// Other. The first matching group wins, so "Triceps Barbell Curl" is triceps before "curl" makes it biceps and
    /// "Rear Delt Fly" is shoulders before "fly" makes it chest. English and Turkish words; Other when nothing fits.
    public static func inferred(from name: String, isCardio: Bool = false) -> MuscleGroup {
        if isCardio { return .cardio }
        let words = name.matchingKey.split { !$0.isLetter }.map(String.init)
        let joined = words.joined()
        for (group, stems) in nameStems {
            let matches = stems.contains { stem in
                stem.contains(" ")
                    ? joined.contains(stem.replacingOccurrences(of: " ", with: ""))
                    : words.contains { $0.hasPrefix(stem) }
            }
            if matches { return group }
        }
        return .other
    }

    /// Word beginnings per group, in the order they are tried. A stem with a space matches the words run together
    /// too ("rear delt" finds "Reardelt").
    private static let nameStems: [(MuscleGroup, [String])] = [
        (
            .cardio,
            ["walk", "run", "treadmill", "bike", "cycling", "elliptical", "stair", "yuruyus", "kosu", "bisiklet"]
        ),
        (.triceps, ["tricep", "pushdown", "skull", "dip", "kickback", "arka kol"]),
        (
            .shoulders,
            ["shoulder", "lateral", "rear delt", "delt", "overhead", "military", "arnold", "face pull", "omuz"]
        ),
        (.biceps, ["bicep", "curl", "hammer", "preacher", "pazu"]),
        (.chest, ["chest", "bench", "fly", "flye", "incline", "decline", "pec", "push up", "pushup", "gogus"]),
        (.back, ["pulldown", "pull up", "pullup", "chin", "row", "lat", "deadlift", "back", "shrug", "sırt"]),
        (.legs, ["squat", "leg", "lunge", "calf", "hamstring", "quad", "glute", "hip thrust", "bacak", "baldır"]),
        (.core, ["crunch", "plank", "abs", "abdominal", "sit up", "situp", "core", "oblique", "karın"]),
    ]
}
