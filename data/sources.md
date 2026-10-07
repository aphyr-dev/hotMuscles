# Third-party sources

Only these two sources are used. Licences checked at the source on 2026-10-07.

| What | Where it lives | Taken from | Original source | Licence |
|---|---|---|---|---|
| Exercise database (876 exercises: names, equipment, category, muscle tags) | `data/freeExerciseDb/` (not in our history) | https://github.com/yuhonas/free-exercise-db f00c92c7 (2026-09-27) | restructured from https://github.com/wrkout/exercises.json | both public domain (Unlicense) |
| Body drawings, male + female, front + back | `models/muscleMap/source/` | https://github.com/melihcolpan/MuscleMap 7dc03071 (2026-04-20), MIT, (c) 2026 Melih Colpan | the path data is copied from https://github.com/HichamELBSI/react-native-body-highlighter (assets/body*.ts), MIT, (c) 2022 ELABBASSI Hicham | MIT (both) |

Notes from the check:
- The body drawings: MuscleMap's back views match react-native-body-highlighter number for number, and its
  front views share every distinct coordinate value (MuscleMap adds sub-group detail). MuscleMap does not credit it. So both MIT
  notices apply: keep both copyright lines with anything built from the drawings (our body maps and tap shapes).
  The original author has not confirmed the drawings are their own original artwork (open question on their
  repo, issue #102, unanswered as of 2026-10-07).
- The exercise database: we keep only ids, names, equipment, category and muscle tags (turned into our
  shares) - none of its instructions text or photos. Neither upstream says where the data first came from.

To restore the exercise database on a new machine:
`git clone https://github.com/yuhonas/free-exercise-db.git data/freeExerciseDb` then
`git -C data/freeExerciseDb checkout f00c92c7`.
