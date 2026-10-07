# hotMuscles

A heatmap-based workout tracker. Log your sets and watch the muscles you've trained light up on a body,
so you can see at a glance what's been worked this week and what's been skipped.

Made in Godot 4.3 for Android (it also builds for Windows).

<img src="docs/architecture/img/screenWeek.png" alt="hotMuscles home screen" width="260">

## Download and try it

You don't need any of the code to try it. Grab the file for your device:

| Device | Download | Size |
|---|---|---|
| **Android phone** | [hotMuscles.apk](https://github.com/aphyr-dev/hotMuscles/releases/latest/download/hotMuscles.apk) | ~25 MB |
| **Windows PC** | [hotMuscles-windows.exe](https://github.com/aphyr-dev/hotMuscles/releases/latest/download/hotMuscles-windows.exe) | ~82 MB |

Older versions and notes are on the [Releases page](https://github.com/aphyr-dev/hotMuscles/releases).

**Installing on Android:** open the link on your phone and tap the downloaded file. The app isn't on the
Play Store, so Android will ask you to allow installs from your browser first (a one-time switch), and Play
Protect may say it doesn't recognise the app: tap **Install anyway**.

**Running on Windows:** just double-click the exe; there's nothing to install. Windows may show "Windows
protected your PC" because the file isn't signed: click **More info**, then **Run anyway**.

Everything stays on your device. The app works offline and never sends anything anywhere.

## How it's built

A tour of the app's insides: [docs/hotMusclesArchitecture_v2.pdf](docs/hotMusclesArchitecture_v2.pdf)

## Licence: MIT

Do whatever you want with it: use it, change it, ship it, sell it. No permission needed. The one
condition (that's what MIT means) is to keep the [LICENSE](LICENSE) file with any copy, because it
also carries the credit lines for the body drawings below. The exercise list is public domain.

## Credits

- **Body drawings**: from [react-native-body-highlighter](https://github.com/HichamELBSI/react-native-body-highlighter)
  by ELABBASSI Hicham (MIT), taken via [MuscleMap](https://github.com/melihcolpan/MuscleMap) by Melih Colpan (MIT).
- **Exercise list**: [free-exercise-db](https://github.com/yuhonas/free-exercise-db), built on
  [wrkout/exercises.json](https://github.com/wrkout/exercises.json). Both public domain.

More detail in [data/sources.md](data/sources.md).
