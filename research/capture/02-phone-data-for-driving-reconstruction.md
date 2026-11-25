# Capture 02: is iPhone 15 Pro Max data useful for driving-scene reconstruction (M3)?

Researched 2026-11-25. Web research only: nothing was downloaded, installed or run; drivestudio's code was read on GitHub,
not executed. Question: with the phone behind the windshield at 20–100 km/h on Indian roads, can its lenses, LiDAR, ARKit
poses and GPS feed D-010's M3? Which lens/LiDAR combinations iOS allows: [01-iphone-15-pro-max-capture.md](01-iphone-15-pro-max-capture.md).
Tags: `[primary]` = paper, official doc, repo or measured test; `[secondary]` = article, forum or search snippet;
`[UNCERTAIN]` = not confirmed; `[inference]` = my reasoning or arithmetic.

## 1. Bottom line

| Data stream | Useful for M3? | Why / limits (sources in §2–§8) |
|---|---|---|
| Main camera video (24 mm, 4K) | **Yes, the core input** | Readout ~5.3 ms `[primary]`. Lock exposure and focus, turn stabilisation off, record SDR (§4) |
| ARKit world-tracking poses (VIO) | **Yes, worth trying as the pose source** | One measured car test: 2.68 m end-point error after a 3.05 km loop, at times above 60 km/h `[primary]`. Metric scale for free. A 2026 iOS drift bug `[secondary]`. ARKit's 4K mode is 16:9 at 30 fps `[primary: WWDC22]` |
| Raw video + IMU for offline VIO | Yes, as fallback and cross-check | Spectacular Rec logs video and IMU `[primary]`. Rolling-shutter and blur compensation need the same velocities `[primary]` |
| GPS (dual-frequency, incl. NavIC) | Yes, for scale and drift checks over a few hundred metres or more | Metre-level fixes, so no per-frame poses `[inference]`. No measured in-car iPhone accuracy found |
| LiDAR depth (ARKit `sceneDepth`) | **No** at 5–50 m. At most a ≤5 m scale check | Apple: "up to 5 meters" `[primary]`. Sparse dots `[primary]`. Sunlight hurts `[secondary]`. Through a windshield: untested |
| Ultra-wide (13 mm, 120°) | Later, optional | More roadside coverage, no OIS `[primary]`. But more hood and cabin, distortion, less detail `[inference]`. Outside D-009's one camera |
| Wide + ultra-wide as stereo | No | 19.24 mm baseline (from Apple's drawing, §5) → ~1.4 px disparity at 20 m `[inference]` |
| 5× telephoto (120 mm) | No | ~16° horizontal view, 5× the vibration blur in pixels `[inference]` |
| Dolby Vision HDR video | Avoid | Tone mapping varies with the scene, which breaks colour consistency across frames `[inference]` |

## 2. iPhone LiDAR outdoors (Q1)

- **Apple's wording** (iPad Pro launch, 2020-03): "The LiDAR Scanner measures the distance to surrounding objects up to 5
  meters away, works both indoors and outdoors, and operates at the photon level at nano-second speeds."
  `[primary: Apple Newsroom]`
- **What ARKit returns:** RGB and LiDAR readings "are fused together using advanced machine learning algorithms to create a
  dense depth map". It arrives at 60 Hz with low/medium/high confidence per pixel. "Highly reflective" or "high
  absorption" surfaces lower accuracy `[primary: WWDC20 10611]`. The map is 256 × 192 `[secondary: arboreal.se]`.
- **The raw sampling is sparse.**
  - iPhone 12 Pro: "8 × 8 points … diffracted into 3 × 3 grids, making a total of 576 points". That gives 7,225 points m⁻²
    at 25 cm and ~150 points m⁻² at 250 cm `[primary: Luetzenburg 2021, Sci. Rep.]`. By inverse square, ~37 m⁻² at 5 m
    `[inference]`.
  - 15 Pro: a developer counted "approximately 111 dots on the 15 Pro vs. 576 dots on the 12 Pro" with an IR camera.
    Apple staff declined to give specifications `[secondary: Apple forum 813071]`.
  - On the same replay file, the 15 Pro marks about twice as many depth pixels below "high" confidence (~10 % vs ~5 %)
    `[secondary: Apple forum 756263]`.
- **Measured accuracy.** Outdoors (iPhone 12 Pro, iPad Pro): ±1 cm on objects with sides > 10 cm, ±10 cm on a
  130 × 15 × 10 m coastal cliff; "M3C2 differences are higher in areas with increased distances"
  `[primary: Luetzenburg 2021]`. Indoors (ARKitScenes vs a Faro scanner): RMSE 0.04, AbsRel 0.02 `[primary: Ganj 2023,
  arXiv 2310.14437]`. 15 Pro Max: "reliable distance measurements up to 10 meters", but "indoors against a flat wall"
  `[secondary: arboreal.se blog test]`.
- **Sunlight:** no controlled measurement found; vendor blogs say solar infrared adds noise and advise shade `[secondary]`;
  Luetzenburg did not test it `[primary]`. **At 5–50 m** `[inference]`: beyond the dots, `sceneDepth` is only the ML guess,
  i.e. another monocular depth model at low confidence.
- **Scale at close range** `[inference]`: a few metric pixels at 1–5 m could fix one scale factor per frame for a
  monocular depth model. But behind a windshield the hood hides the nearest road; what is left in range is the dash,
  reflections and the car ahead in stop-and-go traffic. LiDAR through laminated glass: no test found `[UNCERTAIN]`; glass
  can cause wrong or phantom returns `[secondary: Polycam blog]`. PromptDA turns phone LiDAR into 4K metric depth
  `[primary: arXiv 2412.14015]`, tested only indoors (ARKitScenes, ScanNet++) `[inference]`. Verdict: one 5-minute test
  before relying on it; take scale from ARKit or GPS.

## 3. ARKit world tracking from a moving car (Q2)

**Measured.**
- **Kim et al. 2022** (arXiv 2207.06780) `[primary]`:
  - Setup: iPhone 12 Pro Max on iOS 14.7.1, poses at 60 Hz, rig "fixed to the front passenger seat".
  - Urban loop: 3,051.61 m in Seoul, at times "exceeding 60 km/h". End-point error: ARKit **2.68 m**, ARCore 140.08 m,
    ZED 2 409.25 m, RealSense T265 failed. Parking-garage loop: 446.26 m at 5–15 km/h, ARKit 0.26 m.
  - Vehicle use "is not officially supported by any of the tested VIO devices"; ARCore "occasionally fails when the speed
    of the car increases or the light variations occur abruptly"; T265 diverges at stops or "driving too fast".
  - Caveats `[inference]`: one run, one phone, 2021 software; end-point error hides mid-route error. ARKit has no public
    loop-closure switch, so the authors' "deactivate … loop closure" may not apply to it `[UNCERTAIN]`.
- **Camera-only SLAM on car video**, for contrast `[primary]`:
  - ViPE paper, first 1,024 KITTI frames (cropped to 512 × 368, intrinsics estimated). ATE: ViPE 9.2 m, MegaSaM 25.4 m,
    VGGT 23.8 m, MASt3R-SLAM 122.2 m; RDS driving set 5.0 / 9.3 / 5.7 / 21.0 m. ViPE runs at 3–5 FPS on one GPU, with
    scale "roughly in line with the real-world scale" via Metric3Dv2.
  - DPV-SLAM paper, KITTI 00–10 average ATE: DPVO 53.61 m, DPV-SLAM 53.03 m, DPV-SLAM++ 25.76 m, LDSO 22.42 m;
    DROID-SLAM fails on 02 and 09.
  - `[inference]` The metrics differ (end-point vs ATE), so not comparable 1:1. Still, the IMU removes the scale drift
    that vision alone cannot.

**Failure modes: mechanism and anecdote.**
- **Speed and shake:** "Excessive motion—too far, too fast, or shaking too vigorously—results in a blurred image or too
  much distance for tracking features between video frames" `[primary: Apple, Understanding World Tracking]`.
- **Car interior in view:** in an accelerating carrier, "visual observations of the interior reflect carrier-relative
  motion" while the IMU senses the carrier, which "can compromise conventional fusion" `[primary: NIF-VIO abstract, arXiv
  2611.13662]`; academic VIO is "not robust" to vehicle travel `[primary: arXiv 2509.26639]`. Keep hood and dash out of
  frame as far as possible `[inference]`.
- **iOS bug:** iOS 26.4 brought world-tracking drift to LiDAR iPhones, and an Apple engineer called it a "known issue"
  (June 2026). One developer says Apple told them it is fixed in 26.6.1, with some outdoor misalignment left
  `[secondary: Apple forum 827240]`. Use iOS ≥ 26.6.1.
- **Distant features, vibration, 60–100 km/h, drift over tens of km:** no measurement found.

**Alternatives.**
- **Offline VIO:** the Spectacular AI SDK is "currently not natively available for iOS". Its Spectacular Rec app "records
  video and IMU sensor data" for desktop processing; free for non-commercial use `[primary: docs, App Store]`. Its
  GNSS-VIO is pitched for ground vehicles, but documented only with a u-blox receiver and an OAK-D camera `[secondary]`.
- **GPS:** "Precision dual-frequency GPS (GPS, GLONASS, Galileo, QZSS, BeiDou, and NavIC)" `[primary: Apple spec]`; Core
  Location gives speed with a ± `speedAccuracy` in m/s `[primary]`. No in-car iPhone accuracy test found; a forum user
  reports ~3.5 m horizontal accuracy `[secondary]`. At ~3.5 m per fix, scale to ~1 % over 500 m, ~5 % over 100 m `[inference]`.

## 4. Phone video problems for 3DGS (Q3)

- **Rolling shutter.**
  - **Measured readout:** iPhone 15 Pro/Pro Max, 300 Hz strobe, Apple Log 4K ProRes HQ via the Blackmagic app: 24 mm
    5.3 ms, 13 mm 4.7 ms, 77 mm 5 ms, 120 mm 5 ms `[primary: CineD lab test]`. HEVC, 4K60 and ARKit modes were not
    measured `[UNCERTAIN]`.
  - **At road speed** `[inference]`: main camera at 4K (f ≈ 2,662 px, §5), roadside point 10 m ahead and 5 m to the side.
    At 100 km/h it moves ~3,700 px/s, giving ~20 px of top-to-bottom skew. At 20 km/h, ~4 px. A 20°/s turn adds ~5 px.
    So it matters on highways and is minor in town.
  - **Methods that model it:**
    - *Gaussian Splatting on the Move* (ECCV 2024) models rolling shutter and blur from VIO velocities. Average PSNR on its
      phone captures: 28.59 full, 27.62 without the rolling-shutter term, 26.91 for Splatfacto. It calls the iPhone's
      effect "negligible" for handheld capture. Code: SpectacularAI/3dgs-deblur, on nerfstudio `[primary: arXiv 2403.13327]`.
    - *NeuRAD* (CVPR 2024) offsets image rows by a "manually approximate[d]" shutter time. Over 20 driving sequences:
      PSNR 27.26 vs 26.77 without it, LiDAR depth error 0.030 vs 0.060 `[primary]`.
    - *gsplat*: `rasterization()` takes `rolling_shutter` and `viewmats_rs` `[primary: gsplat 1.5.3b2 API docs]`.
- **Stabilisation, focus, exposure.**
  - **OIS:** the main has sensor-shift OIS, the 5× 3D sensor-shift OIS, plus "Cinematic video stabilization" `[primary:
    Apple spec]`; the ultra-wide (iPhone 11 and later) has none `[primary: Apple vibration note]`. OIS "changes intrinsic
    camera parameters (i.e. K matrix) dynamically" `[primary: DIME-Net abstract]`. Electronic stabilisation re-warps every
    frame, so a fixed pinhole model no longer holds `[inference]`.
  - **Controls:** AVFoundation stabilisation defaults to `.off` in custom apps `[primary]`. A public switch to turn off
    OIS for video: not found `[UNCERTAIN]`. ARKit 6 exposes the `AVCaptureDevice` for manual exposure and white balance,
    and Apple warns "strong overexposure" hurts tracking `[primary: WWDC22 10126]`.
  - **Leftover drift:** OmniRe's config already has a per-image `Affine` colour module and `CamPose` pose refinement
    `[primary: drivestudio configs/omnire.yaml]`. Lock focus anyway: refocusing shifts the focal length `[inference]`.
- **HDR.** iPhone HDR video is Dolby Vision profile 8.4 on an HLG-compatible base `[secondary: snippet of Apple's DV PDF]`.
  Record SDR, or ProRes Log converted with one fixed LUT `[inference]`. In ARKit, HDR is opt-in (`videoHDRAllowed`) and
  only on non-binned formats `[primary: WWDC22]`.
- **Compression.** HEVC 4K60 ≈ 400 MB/min `[secondary]` (~63 Mbit/s measured on one Pro Max `[secondary]`); ProRes is "up
  to 30 times larger than HEVC" `[primary: Apple]`. Lossy video "gradually degrade[s] geometry and rendering quality"
  `[primary: CompSplat abstract, arXiv 2602.09816]`; no bitrate-vs-quality sweep found.
- **Practitioner guidance.** nerfstudio: "reduce motion blur", "use the manual shutter mode", "capture overlapping,
  non-blurry images" `[primary]`. Splat-tool guidance on stabilisation and HDR for video: not found.
- **Recommended settings** `[inference]`: main lens, 4K 30 fps (60 if storage allows), SDR, stabilisation off; focus locked
  at infinity, white balance locked; shutter ≤ 1/1000 s in daylight (~4 px blur for the point above); highest HEVC bitrate, or
  ProRes for short tests; daylight only.

## 5. Several lenses (Q4)

- **Specs** `[primary: Apple spec]`: main 24 mm ƒ/1.78; ultra-wide 13 mm ƒ/2.2, "120° field of view"; 5× 120 mm ƒ/2.8 tetraprism.
- **Spacing:** Apple's iPhone 15 Pro Max dimensional drawing (Detail A) puts rear cameras 1 and 2 at x = 14.17 mm,
  y = −14.17 and −33.41 mm `[primary]`: **19.24 mm** apart `[inference]`, exactly the baseline read from 15 Pro
  spatial-video metadata `[secondary: Mike Swanson blog]`. Spatial video uses the main and ultra-wide `[primary: Apple
  Newsroom]`. Camera 3 (telephoto) at (32.18, −23.79) is ~20.4 mm from both `[inference]`.
- **Focal length in pixels** `[inference]`: 24 mm-equivalent gives a 71.6° horizontal view on the 4:3 sensor. If 4K spans the
  full width: main f ≈ 1920 / tan 35.8° ≈ **2,662 px**; ultra-wide ≈ **1,442 px**; telephoto ≈ 13,300 px. Stabilisation
  crops raise these; Apple's 1080p spatial video reports 63.4° horizontal (≈ 1,554 px) `[secondary: Swanson]`.

Disparity d = f·B/Z with B = 0.01924 m, and depth error σZ = Z²·σd/(f·B) for σd = 0.25 px `[inference]`. A rectified pair is
limited by the ultra-wide, so its row is the realistic one:

| f used | d at 5 m | d at 20 m | d at 50 m | σZ at 5 / 20 / 50 m |
|---|---|---|---|---|
| 1,442 px (ultra-wide-limited) | 5.5 px | 1.4 px | 0.55 px | 0.23 m / 3.6 m / 22.5 m |
| 2,662 px (upper bound) | 10.2 px | 2.6 px | 1.0 px | 0.12 m / 1.95 m / 12.2 m |

- **Motion beats the fixed baseline** `[inference]`. At 20 km/h and 30 fps the car moves 0.185 m per frame, 9.6 × the
  lens spacing. A point 20 m ahead and 5 m to the side shifts ~6 px per frame from forward motion alone. Stereo only
  helps near the image centre (no forward parallax there) and on moving cars within ~10 m.
- **Ultra-wide.** For visual odometry, "it is advantageous to use a large FoV camera … for indoor scenes and a smaller FoV
  for urban canyon environments" `[primary: UZH RPG summary of Zhang et al., ICRA 2016]`. For reconstruction `[inference]`:
  for, it sees facades and footpaths the main camera passes too fast, and with no OIS its intrinsics stay fixed; against,
  hood, A-pillars and dash in view, strong distortion (drivestudio undistorts k1, k2, p1, p2, k3), half the pixels per
  degree. Add it only after the one-camera M3 works, as a 2-camera rig with fixed extrinsics.
- **5× telephoto:** ~16° horizontal view, so almost no overlap between frames at speed, and 5× the blur in pixels from
  the same vibration. Not useful `[inference]`.

## 6. Prior work (Q5)

| Work | Camera | Poses | What it shows |
|---|---|---|---|
| DC-Gaussian (NeurIPS 2024) | 10 own dashcam clips + 8 BDD100K, ~300 frames (10 s at 30 Hz) | COLMAP + HLoc on undistorted frames | Models windshield reflections. PSNR vs 3DGS: 29.44 vs 28.02 (BDD100K), 24.74 vs 23.73 (own clips). "not specifically designed" for dynamic scenes `[primary]` |
| RIDE-Splat (arXiv 2610.34632) | posed driving video | not stated | Separates cabin reflections, which stay "attached to the camera", from the scene `[primary: abstract]` |
| Hierarchical 3DGS (Kerbl 2024) | 5–6 GoPro HERO6 on a bike helmet, time-lapse every 0.5 s, 6–7 km/h; Wayve car data | COLMAP hierarchical mapper + per-chunk BA | km-scale streets with per-image exposure optimisation. "cars coming to a stop are not correctly identified" `[primary]` |
| NeRF-rendered views for 3DGS (arXiv 2606.09034) | 12 dashcam clips of one Shinagawa intersection | COLMAP | No quantitative evaluation `[primary]` |
| Gaussian Splatting on the Move | iPhone 15 Pro and 2 Android phones, handheld | COLMAP poses + Spectacular AI VIO velocities | Rolling-shutter and blur compensation help `[primary]` |
| ViPE | evaluated on 50 OpenDV videos, "mainly dashcam videos" | its own (metric depth in BA) | Pose engine already used by RiGS (research/papers) `[primary]` |
| VDG (arXiv 2406.18198) | RGB only | self-supervised VO, pose-free | Code "will be posted" `[primary: abstract]`, not checked `[UNCERTAIN]` |

Not found: any driving-scene splat or NeRF that uses ARKit poses or phone LiDAR, and any outdoor comparison of ARKit poses
against COLMAP.

## 7. Tooling (Q6)

- **nerfstudio `ns-process-data`**: images, video, polycam, metashape, realitycapture, record3d, odm, aria; KIRI and
  Spectacular AI (`sai-cli`) skip it `[primary: docs]`. Record3D (EXR + JPG export) "uses the iPhone's LiDAR sensors to
  calculate camera poses, so COLMAP is not needed"; Polycam's "poses are globally optimized which make them more robust to
  drift (an issue with ARKit or SLAM methods)" `[primary]`. All are object- or room-scale apps, not driving `[inference]`.
- **drivestudio custom data:** no doc for custom data; issue #96 asked "Support only-visual?" `[primary: repo, 2026-11-25]`.
  The nuScenes loader reads, per scene `[primary: datasets/nuscenes/nuscenes_sourceloader.py, base/pixel_source.py]`:
  - `images/{t:03d}_{cam}.jpg`, `sky_masks/{t:03d}_{cam}.png`, `dynamic_masks/{all,human,vehicle}/…`;
  - `intrinsics/{cam}.txt`: fx fy cx cy k1 k2 p1 p2 k3;
  - `extrinsics/{t:03d}_{cam}.txt`: 4 × 4 camera-to-world **per frame** (docs/NuScenes.md says `{cam_id}.txt`; the code
    wins), re-anchored to frame 0 of camera 0; the "OpenCV" conversion matrix is the identity;
  - `lidar_pose/{t:03d}.txt` (or `ego_pose/`), also used to count frames; `lidar/{t:03d}.bin`: float32 N × 4;
  - `instances/*.json` only when `load_objects` is on; `humanpose/smpl.pkl` only when `load_smpl` is on;
  - optionally `data/ego_masks/<dataset>/<cam>.png`, which is where a hood and dash mask goes;
  - plus a `DATASETS_CONFIG` entry (`camera_name`, `original_size`, `egocar_visible`) in `datasets/dataset_meta.py`.
- **Gotcha** `[primary: code; not run]`: `DrivingDataset.__init__` runs
  `assert self.pixel_source is not None and self.lidar_source is not None` unconditionally (~line 98 on main), and
  `load_lidar: False` makes the LiDAR source `None`, so construction should fail. That also hits D-010's M2 as written.
  The maintainer says random points are used instead, which "will lead to overfitted Gaussians"
  `[primary: issue #96, 2025-08-27]`. Default seeding is `from_lidar: num_samples: 800_000` plus 100k near and 100k far
  random points `[primary: configs/omnire.yaml]`.
- **Minimal phone loader** `[inference]`: write the clip in this nuScenes layout with one camera. In the LiDAR slot, store
  pseudo-LiDAR: metric depth back-projected into `lidar/`, with the camera pose as `lidar_pose`. That gives both the seed
  and the depth loss. ARKit's camera frame has "y-axis points upward … z-axis points toward the viewer" `[primary: Apple]`,
  so flip y and z to reach OpenCV `[inference]`.

## 8. Practical issues (Q7)

- **Heat.** Apple: use at 0–35 °C ambient; when hot, "Charging … slows or stops", "The display dims or goes black",
  "camera features might be temporarily disabled"; it names "GPS tracking or navigation in a car" in direct sunlight as a
  trigger for "Temperature: iPhone needs to cool down." `[primary: Apple 118431]`. 15 Pro 4K60 for 10 min ran 4.1 °C cooler
  after iOS 17.0.3, still "a tad hotter" than older models `[secondary: Android Authority]`; a Pro Max at 4K60 in a 29 °C
  room reached 52 °C after ~15 min `[secondary: PC Guide]`; LiDAR adds noticeably to heat `[secondary: Unity issue
  tracker]`. No hot-car test found. `[inference]` Indian summer air often exceeds 35 °C: shade the phone, run the AC, don't
  charge while recording, record 5–10 min clips, leave LiDAR off unless testing it.
- **Data rates and storage** `[inference from tagged rates]`. Phone storage is 256 GB, 512 GB or 1 TB `[primary]`.

| Stream | Rate | Per hour |
|---|---|---|
| HEVC 4K60 (~400 MB/min `[secondary]`) | ~6.7 MB/s | ~24 GB |
| ProRes 4K30 (~6 GB/min `[secondary: SanDisk]`) | ~100 MB/s | ~360 GB |
| ProRes 4K60 (needs an external drive writing ≥ 220 MB/s `[primary]`) | ~200 MB/s | ~720 GB |
| ARKit depth, float32 256 × 192 at 60 Hz, + uint8 confidence | 11.8 + 2.9 MB/s | ~53 GB before compression |

- **Mounting, glare, reflections.** Apple warns "long-term direct exposure to high-amplitude vibrations" can degrade OIS
  and closed-loop AF, and recommends "a vibration dampening mount" `[primary]`. Dashcam makers sell CPL filters "to filter
  out light reflections from surfaces such as the road or the vehicle's dashboard", removed at night
  `[secondary: BlackVue]`; a dark dash mat helps `[secondary: forum]`. DC-Gaussian and RIDE-Splat model leftover
  reflections `[primary]`. `[inference]` Mount close to the glass inside the wiper sweep, clear of the dotted frit and tint
  strips; mask the hood; clean the glass inside and out.

## 9. What this changes in M3 (proposed; not yet in docs/DECISIONS.md)

1. **Poses:** try ARKit VIO poses as the M3 pose source, with OmniRe's `CamPose` refinement on, instead of starting with a
   monocular SLAM front-end `[inference from §3]`. Run ViPE on the same frames as an independent check and fallback.
   Compare Sim(3)-aligned ATE, the scale ratio, and the end-point error on a closed loop, as in Kim et al.
2. **Scale:** comes from ARKit's IMU, audited by GPS distance over ≥ 500 m. Metric depth is still needed, but as
   drivestudio's pseudo-LiDAR seed (§7), not for scale. iPhone LiDAR plays no part in M3 geometry.
3. **Capture:** one ARKit logger (4K 30 fps or 1920 × 1440 at 60 fps, plus poses and GPS) with the §4 settings. Before the
   real drive, a 5-minute closed loop at 20–60 km/h validates ARKit in the owner's car. The ARKit-versus-Camera-app
   trade-off is in file 01.
4. **Loader:** emit drivestudio's nuScenes layout with pseudo-LiDAR, and expect `load_lidar: False` to crash (§7). This is
   roughly the same work as D-010 planned, with one more input file.
5. Still one crutch per step: dataset poses become phone VIO poses. ViPE-only poses become an "M3b" if ARKit fails.

## 10. Dead ends

- iPhone LiDAR as street geometry at 5–50 m: 5 m stated range, 111–576 dots, ML-filled beyond that.
- Wide + ultra-wide stereo for street depth: 19.24 mm gives < 1 px disparity past ~28 m at the ultra-wide's resolution
  `[inference]`.
- 5× telephoto for reconstruction; Dolby Vision HDR capture; night capture (blur) `[inference]`.
- Searched but **not found**: iPhone LiDAR sunlight-vs-range data or a through-windshield test; readout time in HEVC,
  4K60 or ARKit modes; Apple's own ProRes size per minute; ARKit drift at 60–100 km/h or over tens of km; measured in-car
  iPhone GPS accuracy; ARKit vs COLMAP poses outdoors; a hot-car thermal test; any driving splat using ARKit or phone LiDAR.
