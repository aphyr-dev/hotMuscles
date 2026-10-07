# muscleCarve - turns MuscleMap's body drawings into our muscle regions

Source: `models/muscleMap/source` (melihcolpan/MuscleMap, commit 7dc0307, MIT). Its path data is copied from
HichamELBSI/react-native-body-highlighter (MIT) - see `data/sources.md`; both notices apply.
Result: `data/muscleShapes/muscleShapes.json`, plus preview pictures in `data/muscleShapes/preview/`.

## Run order

```
python tools/muscleCarve/extractShapes.py   # reads the Swift files -> sourceShapes.json + labelled source_*.svg
python tools/muscleCarve/carve.py           # rules + cuts -> muscleShapes.json + carved*.png previews
python tools/muscleCarve/verifyShapes.py    # area and coverage checks
python tools/muscleCarve/beforeAfter.py     # beforeAfter_male.png / _female.png - MuscleMap vs ours, only changes coloured
```

`carve.py` calls Godot 4.3 headless (`polygonCut.gd`) to do the polygon cutting.

## Tweaking a cut

Every rule and cut zone sits at the top of `carve.py`. Zones are drawn in each piece's own box:
`u` 0 = outer edge -> 1 = inner edge, `v` 0 = top -> 1 = bottom. So one zone fits the left and
right side and both bodies. Change the numbers, rerun `carve.py`, and look at `carvedTorso.png` /
`carvedThighs.png`.

`inspectShapes.py` draws a zoomed, labelled crop of the source pieces when a new rule is needed.

## What was done to the source

- MuscleMap's front "sub-groups" (upper/lower chest, front delt, upper/lower abs, inner/outer quad,
  hip flexors) are blobs stamped on top of the real muscle, so they are dropped and replaced by real cuts.
- Pieces that were already separate muscles under one name get relabelled (lat vs infraspinatus vs
  teres under `upperBack`, glute max vs med under `gluteal`, the sartorius under `adductors`).
- Cuts: chest (upper / mid-lower), deltoid (front / side, rear / side), the big quad piece
  (outer / mid), back trapezius (upper / mid / lower / rhomboids). Every cut opens a seam as wide
  as MuscleMap's own gaps (`cutGap`).
- Male/female parity: the male back draws the shoulder blade as two pieces (infraspinatus plus a teres
  half-moon), the female as one. Both sexes have both muscles - it's only how the artist drew them - so
  the male pieces are fused into one rotator cuff shape (`fuseRadius`) to match her.
