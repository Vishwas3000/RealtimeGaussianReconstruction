# Capturing our own data with an iPhone 15 Pro Max

Synthesis written 2026-11-25. Two agents researched the question in parallel. The lead session then re-checked the
decision-relevant claims at source `[measured]` (log at the end). Nothing was installed, and nothing has been run on the
phone yet.

| File | Question |
|---|---|
| [01-iphone-15-pro-max-capture.md](01-iphone-15-pro-max-capture.md) | What iOS can capture: lens and LiDAR combinations, ARKit, calibration, existing apps, and a probe-app spec |
| [02-phone-data-for-driving-reconstruction.md](02-phone-data-for-driving-reconstruction.md) | Whether that data helps a driving reconstruction: LiDAR range, ARKit in a car, rolling shutter, heat, drivestudio loader |
| [03-probe-iphone15pro.md](03-probe-iphone15pro.md) | **Measured on the owner's iPhone 15 Pro:** which lens sets run together, at what resolution, heat cost and sync |

## Answer

**Note (2026-11-25): the phone actually used is an iPhone 15 Pro, not a 15 Pro Max.** It has the same main camera,
LiDAR and ARKit. Only the telephoto differs (3× instead of 5×), and we don't use it, so nothing below changes.
**Measured on that phone the same day:** ARKit delivers LiDAR depth in 4K30 mode, as a 256×144 map (16:9), on every
frame of a test clip.

**Build a custom app, but keep ARKit inside it.**
- **ARKit's poses are the most valuable thing the phone gives us.** ARKit tracked a 3 km city drive to 2.68 m of
  end-point error.
- **ARKit cannot share the camera.** It uses only the main lens, and no other lens can run during an AR session.
- **The other lenses and the LiDAR add little for road scenes.** Giving up the poses to get them is a bad trade.

| Stream | Use it? | Why |
|---|---|---|
| Main lens (24 mm) video | **Yes, the core input** | ARKit: 1920×1440 up to 60 fps, or 3840×2160 at 30 fps |
| ARKit poses (camera position + orientation per frame, metric) | **Yes** | The one car test is in "Measured" below. Camera-only SLAM on KITTI driving video drifts 9–25 m (ATE, a different metric) |
| GPS | Yes, as a check | Audits the scale over hundreds of metres; metre-level per fix |
| LiDAR | No | Apple: "up to 5 meters". At road distances, ARKit's depth is the ML model's guess |
| Ultra-wide (13 mm) | Later, maybe | Wider view and no OIS, but more hood and dash in frame. ARKit can't run it, so it would mean a separate app with no poses |
| Main + ultra-wide as stereo | No | Lenses 19.24 mm apart → ~1.4 px disparity at 20 m. At 20 km/h the car moves ~10× that distance between frames |
| 5× telephoto | No | ~16° view: too narrow at speed |

## Measured: ARKit in a moving car `[measured]`

- Kim et al. 2022 (arXiv 2207.06780) used an iPhone 12 Pro Max fixed to a car's front passenger seat.
- On the 3,051.61 m outdoor road loop, the end-point errors were: ARKit **2.68 m**, ARCore 140.08 m, ZED 2 409.25 m;
  T265 failed.
- The paper: "Only ARKit (red) is able to produce stable motion tracking performance even when driving a vehicle over
  60 km/h".
- This is one run on a 2021 phone. Validate it in our own car before relying on it.

## The custom multi-lens app (no ARKit) `[measured]`

- **Possible.** Apple (WWDC22): "Because the LiDAR Depth Camera uses the rear-facing wide-angle camera, the Telephoto and
  Ultra Wide cameras can be used in addition with an AVCaptureMultiCamSession." Apple's sample app "AVMultiCamPiP:
  Capturing from Multiple Cameras" shows the session setup.
- **Its costs:**
  - **No poses.** They would have to come from offline visual-inertial tracking of the logged video and IMU.
  - **Lower resolution.** Only multi-camera formats are allowed. The 2019 limit was 1920×1440 at 30 fps: "We do not
    support 12 megapixel on N cameras".
  - **No hardware sync between lenses.** The rule is "only one input per camera in a session". Hardware sync is promised
    only inside a combined (virtual) camera, and the LiDAR camera and the triple camera both contain the wide lens.
  - **Heat.** A system-pressure cost below 1.0 runs "indefinitely", 1–2 runs "up to 15 minutes" and 2–3 "up to 10
    minutes", and that is in an idle phone. Apple rates iPhones for 0–35 °C ambient, and Indian summers exceed that.
- **Unknown until a probe app runs on the phone:** which lens combinations and formats the 15 Pro Max allows (file 01,
  §9 has the spec).

## Correction to the plan `[measured]`

**drivestudio cannot simply run with LiDAR off.**
- `datasets/driving_dataset.py` line 79 asserts `self.pixel_source is not None and self.lidar_source is not None`.
- With `load_lidar: False`, lines 159–160 leave the LiDAR source as `None`, so the run should stop at that assert (code
  read, not run).
- The maintainer's reply in issue #96 says random points would be used, and that disabling LiDAR "will lead to overfitted
  Gaussians".
- **Fix for M2 and M3:** write metric depth, back-projected with the camera pose, into drivestudio's LiDAR slot
  ("pseudo-LiDAR"). That gives both the starting points and a depth loss. Recorded as a correction to D-010.

## How to use this (Claude's recommendation; logged as D-011, Proposed)

1. **Capture app:** fork Stray Scanner (MIT; records ARKit video, LiDAR depth, poses, intrinsics and IMU). Add:
   - 4K30 (or 1440p60) recording;
   - focus, exposure and white balance locked, and HDR off;
   - GPS and per-frame exposure logging.

   Leave LiDAR off except for one test.
2. **Validate first:** a 5-minute closed loop at 20–60 km/h in the owner's car. Measure the end-point error and compare
   the scale with GPS.
3. **Poses:** ARKit poses, refined by OmniRe's per-camera pose refinement. Run ViPE on the same frames as a check and
   fallback.
4. **Capture rules:**
   - daylight only;
   - phone shaded, AC on, not charging;
   - 5–10 minute clips;
   - mount close to the glass and mask the hood.
5. **The multi-lens app waits** until the one-camera M3 works. Then the probe app decides whether the ultra-wide is worth
   a second app.

## Spot-check log `[measured]`, 2026-11-25

- **Apple forums:** read through a fetch agent, because the pages load their posts with JavaScript and curl can't see
  them. Apple staff replies in 812818 (Jan 2026: "There's no supported way for you to access the ultra wide camera while
  an ARSession is running…"), 769604 (Dec 2024, the accepted answer: "There is no supported way to do this…") and 719837
  (Nov 2022: "That is not possible at this time.").
- **WWDC transcripts:**
  - 2019/249: the two-physical-camera rule (2019 devices); hardware sync of virtual-device constituents ("the middle line
    of the readout is exactly at the same clock time"); one input per camera; the system-pressure time rules; no
    12-megapixel video on N cameras.
  - 2020/10611: depth "at 60 Hz on each AR frame", in metres, with a confidence map.
  - 2022/10126: ARKit 4K mode, 3840×2160 at 30 fps, iPhone 11 and later.
  - 2022/110429: ARKit depth 256×192; LiDAR camera streaming depth up to 320×240, photo depth 768×576; the telephoto and
    ultra-wide "in addition" quote.
- **Apple Newsroom 2020:** "up to 5 meters away, works both indoors and outdoors".
- **Apple docs JSON:** the AVMultiCamPiP sample exists.
- **arXiv 2207.06780 HTML:** the table row "Outdoor Roads 2.68 140.08 × 409.25 3051.61", the >60 km/h sentence, the
  passenger-seat rig, the iPhone 12 Pro Max.
- **GitHub:** drivestudio `driving_dataset.py` lines 79 and 159–160, and issue #96's owner reply; Stray Scanner is MIT,
  last pushed 2026-04-04.

## Not verified

- **Taken from the agents' notes, not re-checked:**
  - the 30 fps cap on LiDAR-camera depth (Apple DTS);
  - the 5.3 ms rolling-shutter readout (CineD, ProRes only);
  - the 19.24 mm lens spacing (Apple's dimensional drawing);
  - the iOS 26.4–26.6 world-tracking drift bug (forum; reportedly fixed in 26.6.1);
  - the ViPE and DPV-SLAM KITTI numbers.
- **Not yet tested on the phone:** iPhone LiDAR in sunlight or through a windshield; ARKit at 60–100 km/h on rough roads;
  in-car GPS accuracy; a hot-car heat test; the 15 Pro Max's multi-camera combinations.
