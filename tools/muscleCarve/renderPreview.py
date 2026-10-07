### /// RENDER PREVIEW SVGS TO PNG ///
# drives headless edge to screenshot svg or html files - usage: renderPreview.py file width height [scale]

import subprocess
import sys
from pathlib import Path

### /// TUNING ///
edgePath = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
defaultScale = "2"     # device pixel ratio for the screenshot


def render(sourceFile, width, height, scale):
    # one screenshot next to the source file - same name with .png
    source = Path(sourceFile).resolve()
    outFile = source.with_suffix(".png")
    if outFile.exists():
        outFile.unlink()
    subprocess.run([
        edgePath,
        "--headless=new",
        "--disable-gpu",
        "--hide-scrollbars",
        "--force-device-scale-factor=" + scale,
        "--window-size=" + str(width) + "," + str(height),
        "--screenshot=" + str(outFile),
        source.as_uri(),
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    if not outFile.exists():
        raise SystemExit("no screenshot written for " + str(source))
    print("wrote", outFile, outFile.stat().st_size, "bytes")


if __name__ == "__main__":
    scale = defaultScale
    if len(sys.argv) > 4:
        scale = sys.argv[4]
    render(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), scale)
