# Upstream

This app is a fork of [Stray Scanner](https://github.com/strayrobots/scanner) by Stray Robots, taken at commit
`ec3e1dc9d33f8df2289ede6a5c59f7991d1a6bbb` (2026-04-04), under its MIT licence (`LICENSE.md`, kept unchanged).

The unmodified import is its own commit in this repository, so `git diff` against it shows every RoadCapture change.

## RoadCapture changes (TeslaRender D-011)

- **Formats:** 4K30 (ARKit 6's 4K mode) or 1440p60. 4K falls back to 1440p60 on phones without it.
- **Camera settings:**
  - focus pinned at the far end of the lens;
  - a Lock button: white balance locked, shutter at most 1/1000 s, ISO raised to keep brightness;
  - HDR off.
- **LiDAR depth is optional and off by default**, so the app also runs on iPhones without LiDAR (it used to refuse).
- **New outputs:** `frames.csv` (tracking state, exposure, lock, heat per frame), `gps.csv` and `capture_info.json`
  (see `docs/format.md`).
- **Fixes:**
  - video frames are stamped with their capture time (the old 60-tick timing played 30 fps video at double speed);
  - the recording status no longer reports success after a video error;
  - the screen stays awake while recording;
  - the preview matches the format's aspect ratio.
- **Identity:** display name RoadCapture, bundle ID `app.roadcapture.ios`, signing team `GH5YVSN865`.
