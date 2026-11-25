# 03: what the iPhone 15 Pro's cameras can do together (measured)

Run on 2026-11-25 by RoadCapture's camera probe (`capture/ios/StrayScanner/Helpers/CameraProbe.swift`), on the owner's
iPhone 15 Pro (`iPhone16,1`, iOS 27.2.1), via `devicectl` with the `-probe` launch argument. Everything here is
`[measured]` on that phone unless tagged. The raw report (495 KB) is local only: `capture/data/probe/camera_probe_20261125-201000.json`.

**Method.**
- Every rear-lens set iOS reports in `supportedMultiCamDeviceSets` was tested, plus each combined (virtual) camera alone.
- For each, the largest 8-bit 30 fps multi-camera format per lens was picked, then the biggest stream was shrunk until
  the session's `hardwareCost` was ≤ 1.
- Each set then streamed for 3 s, recording the frame rates and the median time offset between each lens's frames and
  the first lens's nearest frame.
- The phone was already at thermal state "fair" when it started.

## Lens sets iOS allows together (rear only)

| Kind | Sets |
|---|---|
| Combined cameras (lenses hardware-synchronised) | `dual` (wide + tele), `dualWide` (wide + ultra-wide), `triple` (all three) |
| Two separate lenses | wide + ultra-wide, wide + tele, ultra-wide + tele, LiDAR + ultra-wide, LiDAR + tele |
| Three separate lenses | wide + ultra-wide + tele, LiDAR + ultra-wide + tele |

The LiDAR camera *is* the wide lens plus depth, so "LiDAR + ultra-wide + tele" means all three lenses plus depth.

## Measured, per set

**Heat cost** is `systemPressureCost`. Apple's WWDC19 rule for an otherwise idle phone: below 1 runs indefinitely,
1–2 up to 15 min, 2–3 up to 10 min, above 3 only briefly.

| Set | Largest 30 fps format that fits | Hardware cost | Heat cost | Time offset between lenses |
|---|---|---|---|---|
| **dualWide** (wide + ultra-wide, combined) | 3840×2160 each | 0.50 | 0.68 | **0.11 ms (synchronised)** |
| dual (wide + tele, combined) | 3840×2160 each | 0.50 | 0.69 | 0.29 ms (synchronised) |
| **triple** (all three, combined) | 1920×1080 each | 0.75 | 1.71 | **0.21 / 0.37 ms (synchronised)** |
| wide + ultra-wide (separate) | 3840×2160 each | 0.50 | 0.68 | 8.4 ms (free-running) |
| wide + tele (separate) | 3840×2160 each | 0.50 | 0.69 | 16.0 ms |
| ultra-wide + tele (separate) | 3840×2160 each | 0.50 | 0.71 | 10.5 ms |
| **LiDAR + ultra-wide** (separate) | 3840×2160 each, depth at 29 fps | 0.50 | **0.38** | 9.3 ms |
| LiDAR + tele (separate) | 3840×2160 each, depth at 28 fps | 0.50 | 0.38 | 12.9 ms |
| wide + ultra-wide + tele (separate) | 1920×1080 / 1920×1440 / 1920×1080 | 0.82 | **4.06** | 6.1 / 9.2 ms |
| LiDAR + ultra-wide + tele (separate) | 1920×1080 / 1920×1440 / 1920×1080, depth at 28 fps | 0.82 | 2.39 | 12.3 / 0.35 ms |

- **Frame rates:** every stream delivered 30 fps over the 3 s run.
- **Per-frame intrinsics:** delivery (`isCameraIntrinsicMatrixDeliverySupported`) is supported on every lens in every set.
- **Offsets:** "free-running" offsets are a steady phase within a session, so each frame still carries its own exact
  timestamp. The 0.35 ms LiDAR-to-ultra-wide offset in the last row is probably a chance phase alignment: the same pair
  ran 9.3 ms apart on its own `[inference]`.

## Factory calibration between lenses

| Pair | Translation (mm) | Distance |
|---|---|---|
| wide → ultra-wide | (19.2, 0.0, 1.2) | **19.3 mm** |
| wide → tele | (9.6, −18.0, 0.4) | 20.4 mm |
| ultra-wide → tele | (−9.6, −18.0, −0.8) | 20.4 mm |

That matches the 19.24 mm read from the 15 Pro Max drawing (02 §5). So the stereo conclusion stands: the pair adds about
1.4 px of disparity at 20 m, which is useless for street depth.

## ARKit on this phone

- **Formats:** 3840×2160 at 24, 25 or 30 fps; 1920×1440, 1920×1080 and 1280×720 at 30 or 60 fps. All come from the
  wide lens.
- **Recommended 4K format:** 3840×2160 at 30 fps. Scene depth is supported.

## What it means for D-012 `[inference]`

- **Best two-lens set: `dualWide`.** Wide and ultra-wide at full 4K, hardware-synchronised, heat cost 0.68
  (sustainable). It loses LiDAR, because the LiDAR camera also needs the wide lens.
- **All three lenses: `triple`.** Synchronised, but only at 1080p, and a heat cost of 1.71 (up to about 15 min in an
  idle phone, less in a hot car).
- **All three lenses plus LiDAR is possible:** LiDAR + ultra-wide + tele, at 1080p/1440p, heat cost 2.39 (up to about
  10 min), with lenses not synchronised.
- **LiDAR + ultra-wide** at 4K + 4K with depth has the lowest heat cost (0.38), but its lenses are not synchronised.
- **Caveat:** the probe ran each set for only 3 s. The heat costs are Apple's estimates, not a test in a hot car.
