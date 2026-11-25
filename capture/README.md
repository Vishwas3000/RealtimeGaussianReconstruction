# RoadCapture: recording our own road video

Decision D-011 ([docs/DECISIONS.md](../docs/DECISIONS.md)). An iPhone app that records the main camera with ARKit's
per-frame position in metres, plus GPS, motion sensors and per-frame exposure, for roadmap step M3. It is a fork of
Stray Scanner (MIT). What changed: [ios/UPSTREAM.md](ios/UPSTREAM.md). Output files: [ios/docs/format.md](ios/docs/format.md).
Why it is built this way: [research/capture/](../research/capture/README.md).

**Status (2026-11-25):** builds and signs on the Mac (Xcode 26.2). Installed and launched on the owner's iPhone 15 Pro
(iOS 27.2.1).

## Install

1. On the phone, turn on Developer Mode, which iOS 16+ requires for apps run from Xcode: Settings → Privacy & Security
   → Developer Mode.
2. On the Mac, open `capture/ios/StrayScanner.xcworkspace` in Xcode. Open the workspace, not the `.xcodeproj`.
3. Choose the **StrayScanner** scheme and your iPhone, then Run (⌘R). Signing is preset to your personal team
   (`GH5YVSN865`).
4. On first launch, allow Camera, and Location "While Using the App".

## Mount the phone

- **Landscape, lying on its long side.** The app's screen stays in portrait, but the video is always recorded in the
  sensor's landscape orientation. A phone standing upright records the road sideways, with a narrow view. The checker
  reports how each recording came out.
- **Position:** close to the glass, inside the wiper sweep, level, and aimed at the horizon.
- **Keep the hood and dashboard out of frame** as far as possible. A dark cloth on the dash cuts reflections.
- **Heat:** shade the phone, run the AC, and don't charge while recording. Apple rates iPhones for 0–35 °C.

## Record

| Control | What it does |
|---|---|
| **4K30 / 1440p60** | Switches the format (not while recording). 4K30 is the default. Try 1440p60 if you see motion blur or tracking trouble |
| **Lock** | Tap once the road view has settled. White balance locks, and the shutter drops to at most 1/1000 s against motion blur (ISO rises to make up). Tap again to return to auto. Daylight only: at night 1/1000 s is too dark |
| **LiDAR off / on** | Off by default, because it only reaches about 5 m. Shown only on iPhones with LiDAR |
| **fps** | Saves every Nth frame. Leave it at the camera rate (30 or 60) |
| Status line | Format, ARKit tracking, GPS accuracy and heat. Before driving off, wait for `tracking normal` and a GPS fix better than ±10 m |

Record clips of 5–10 minutes, stopping and starting new ones rather than doing one long run, because of heat.

## First test: a 5-minute closed loop

1. Park at a spot you can find exactly again, such as a parking-bay line.
2. Start recording and drive a 2–5 km loop at 20–60 km/h.
3. Stop at the same spot, facing the same way, and stop recording.
4. Copy the recording to the Mac and run the checker (below).

**What good looks like.** For reference, one published test (Kim et al. 2022) measured ARKit 2.68 m off after a
3,051 m drive, about 0.1 %.
- The start-to-end error is under about 1 % of the path.
- The ARKit/GPS scale is within 5 % of 1.000.
- Tracking is `normal` on more than 95 % of frames.
- No frames are missing, and heat never reaches "serious".

## Copy recordings off the phone

Each recording is a folder named by a short hash.
- **Finder:** select the phone, then Files → RoadCapture, and drag the folder out.
- **Files app:** On My iPhone → RoadCapture.

Put recordings in `capture/data/`. That folder is git-ignored.

## Check a recording

```sh
python3 capture/tools/check_capture.py capture/data/<folder>          # add --json for machine-readable output
python3 -m unittest discover -s capture/tools                         # the checker's own tests
```

- It needs Python 3.8 or later and nothing else, on macOS or Windows (`py` instead of `python3` on Windows).
- It reports the frame rate and dropped frames, how the phone was mounted (upright, upside down or sideways, and its
  tilt), ARKit tracking health, heat, the start-to-end error, and ARKit's scale against GPS.
- It exits with 1 when something needs attention.

## Privacy

`gps.csv` is where you drove, and the video shows faces and number plates. Keep recordings out of this public
repository, and blur faces and plates before sharing anything (research/market/04-legal-india.md).

## Known limits

- **The first road recording** will show whether everything below holds.
- **The mount check rests on two readings of the code:** that Stray Scanner's odometry quaternions use OpenCV camera
  axes (from its `q_AC` flip), and that ARKit's world y axis points up. The first real recording should come out
  "upright" when the phone is mounted correctly.
- **4K with LiDAR:** whether ARKit delivers depth in 4K mode on your phone is unknown. `has_depth` in `frames.csv` will
  show it.
- **No lens distortion:** ARKit gives none for the rear camera (research/capture/01 §4). Per-frame intrinsics are
  pinhole only.
- **Lock in dim light** can push ISO high and add noise.
- **Focus and Lock:** untested is whether the far-focus setting and the Lock hold under ARKit's own camera management on
  every iOS version. The `exposure_duration` column shows whether the Lock held.
