# Analysis

> Status: F11. The numbers are in `PeakCore/Analysis` (`PerformanceAnalysis`, tested in `PerformanceAnalysisTests`);
> the screen follows. Decision record: [ADR 0020](adr/0020-analysis-screen.md).

Every figure is computed from completed sessions when the screen opens. Nothing is stored.

## Input

`WorkoutSession.analysisSession` turns a completed session into an `AnalysisSession`: date (and whether the importer
estimated it), duration, title, template, and its movements. A movement carries its `ExerciseResult` (sets, targets),
its muscle group, and for a walk its distance and length.

A movement's sessions are tied together by its **key**: the exercise's current name as a `matchingKey`
(case, accents and spaces ignored). A renamed exercise keeps its history, and a session whose exercise is gone
matches by the name it was logged under.

## Formulas

| Figure | How |
| --- | --- |
| Estimated one-rep max | Epley: `w × (1 + r / 30)`; `w` for one rep; 0 without weight or reps |
| Best set | The set with the highest estimated one-rep max; on a tie, the most reps |
| Movement value | Best set's estimated one-rep max (kg). Bodyweight movement (no set has weight): the best set's reps. Walk: distance in km, or minutes when the distance is unknown |
| Record | A value above every earlier session's value of the movement; the first session is never one |
| Trend | Last value ÷ average of up to 3 values before it − 1. Above +2% rising (green ↑), below −2% falling (red ↓), else steady (grey —). Needs two values |
| Volume | Σ weight × reps over strength sets (`SessionStatistics.volumeKg`) |
| Done sets | Strength sets with reps |
| Target success | Movements that reached every target ÷ movements that had targets (and walks). Imported sessions have no targets, so they are not judged; without any, "–" |
| Week | The calendar's week (the locale's first weekday); weeks without a session are shown empty |
| Streak | Weeks in a row with at least one session up to this week; this week only counts once it has one, and does not break the run before it is over |
| Muscle balance | Done strength sets per muscle group ÷ all done strength sets |
| Period change | This period's total ÷ the same length before it − 1, with the trend's ±2% band |

A session where a movement has no done set (skipped) is not a point on that movement's chart.

## Periods

4 weeks (28 days), 3 months, 6 months, 1 year, or all time, each ending with today. The change arrows compare with the
period of the same length just before; all time has none.

## Muscle groups

The stored group wins. When it is Other (spreadsheet imports leave it so), `MuscleGroup.inferred(from:)` guesses from
the name, trying the groups in this order so the more specific word wins:

| Group | Words (beginnings; English and Turkish) |
| --- | --- |
| Cardio | walk, run, treadmill, bike, cycling, elliptical, stair, yürüyüş, koşu, bisiklet |
| Triceps | tricep, pushdown, skull, dip, kickback, arka kol |
| Shoulders | shoulder, lateral, rear delt, delt, overhead, military, arnold, face pull, omuz |
| Biceps | bicep, curl, hammer, preacher, pazu |
| Chest | chest, bench, fly, incline, decline, pec, push up, göğüs |
| Back | pulldown, pull up, chin, row, lat, deadlift, back, shrug, sırt |
| Legs | squat, leg, lunge, calf, hamstring, quad, glute, hip thrust, bacak, baldır |
| Core | crunch, plank, abs, abdominal, sit up, core, oblique, karın |

So "Triceps Barbell Curl" is triceps, "Rear Delt Fly" shoulders, and "Incline Dumbbell Curl" biceps. Every movement
in the author's real history gets the group its section in the log has.
