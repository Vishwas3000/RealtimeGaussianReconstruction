# 01: What iOS can capture on an iPhone 15 Pro Max (cameras, LiDAR, ARKit)

Researched 2026-11-25 for D-010 step M3 (reconstructing the owner's own road video). This was web research only: nothing
was installed or run, and **no probe app has been run on the phone**. Whether the data helps reconstruction is covered
in a separate file. Tags: `[primary]` = Apple docs, a WWDC transcript, a forum post by Apple staff, or the app's own
repo or store page; `[secondary]` = a third-party article, a non-Apple forum post or a search snippet;
`[UNCERTAIN]` = could not confirm; `[inference]` = my own reasoning. "Not found" means the sources say nothing.

The phone has a 48 MP Main (24 mm, ƒ/1.78), a 12 MP Ultra Wide (13 mm, ƒ/2.2, 120°), a 12 MP 5× Telephoto (120 mm,
ƒ/2.8), a LiDAR Scanner, a "High dynamic range gyro", a "High-g accelerometer" and a barometer [primary: Apple tech specs].

## 1. Bottom line

| Capture combination | Possible? | Resolution / fps | Poses? | Depth? |
|---|---|---|---|---|
| **ARKit world tracking alone** | Yes [primary] | RGB comes from the wide camera: 1920×1440 binned at up to 60 fps, or 3840×2160 at 30 fps (iPhone 11 and later); 10-bit formats go up to 4K [primary]. The phone's exact list needs the probe | **Yes**: 6-DoF per frame from visual-inertial odometry [primary]; capture apps log the position in metres [primary: app repos] | LiDAR `sceneDepth` 256×192 + confidence on every frame (60 Hz at 60 fps) [primary]. No lens-distortion data [inference, §4] |
| **ARKit + any other camera** | **No.** Apple staff said "no supported way" in 2022, 2024 and 2026 [primary] | — | — | — |
| **Wide + ultra-wide** (`AVCaptureMultiCamSession`) | Probably [inference]: spatial video streams both at once [primary]; one developer ran them as two inputs [secondary]; another failed on a 12 Pro [secondary]. The 15 Pro Max device sets: not found | Only formats flagged `isMultiCamSupported`. On iPhone XS that meant ≤1920×1440 at 30 fps unbinned or 60 fps binned [primary]. The 15 Pro Max list: not found | No (needs your own SLAM) | Only through the dual-wide virtual camera: stereo disparity (relative) depth [primary] |
| **All three rear cameras** | [UNCERTAIN]. Apple's 2019 rule was "two physical cameras at a time" (iPhone XS) [primary]; an 11 Pro Max listed sets of up to 3 cameras without saying which [secondary] | Not found | No | No |
| **One camera + LiDAR depth camera** (AVFoundation, iOS 15.4+) | Yes [primary]. The LiDAR device *is* the wide camera + LiDAR; the telephoto and ultra-wide "can be used in addition" in a multi-cam session [primary] | Video 640×480 to 4032×3024; streamed depth up to 320×240, photo depth 768×576; depth at most 30 fps [primary] | No | Yes: absolute metric depth, fused by an ML model; calibration attached [primary] |
| **Spatial video** | Yes: Camera app since iOS 17.2, developer API since iOS 18 [primary] | 1080p, 30 fps, SDR, about 130 MB per minute [primary] | No | No: a stereo pair (Main + Ultra Wide) with baseline and FOV metadata [primary] |

So [inference]: ARKit is the only path that gives poses, and it takes the camera for itself. You get one RGB stream
from the wide camera plus 256×192 LiDAR depth. Two or more cameras means AVFoundation, no poses, and an offline
SLAM front-end (D-010 already plans ViPE or MegaSaM).

## 2. Several rear cameras at once (`AVCaptureMultiCamSession`)

- **Rules Apple documents:** only formats with `isMultiCamSupported == true` may be active ("Only this limited subset
  of capture formats can run sustainably"); the preset is always `inputPriority`; one input per camera; one multi-cam
  session per app, never across apps; disabling a camera's ports stops it without interrupting the others
  [primary: docs, WWDC19 249].
- **Which sets:** `DiscoverySession.supportedMultiCamDeviceSets` returns the "sets of capture devices that you can use
  simultaneously" [primary]. Apple publishes no per-phone table. **No source gives the 15 Pro Max's sets.** What exists:
  - WWDC19 (iPhone XS/XR, iPad Pro): "six supported configs"; "you're allowed to run two physical cameras at a time";
    the dual camera counts as two [primary].
  - iPhone 11 Pro Max on iOS 13: no set had more than 3 cameras, and a 4th input threw "These devices may not be used
    simultaneously". Which three is not said, and the search included the front camera [secondary: Neos21/multi-cam].
  - A third-party summary of Apple forum Q&As (Sept 2026, about the new "iPhone Duo") quotes "At most three physical
    cameras can run together" [secondary].
  - WWDC22: with the LiDAR Depth Camera, "the Telephoto and Ultra Wide cameras can be used in addition with an
    AVCaptureMultiCamSession" [primary]. It doesn't say whether both can run at once.
  - Apps: Multicam Pro claims "triple camera recording on compatible devices" (v1.3.0) and "up to two streams of 4K"
    (v1.6.0, 2022); ContentCam found 4K30 multi-cam formats on the front, wide and ultra-wide of an iPhone 18 Pro on
    iOS 27.0.1, none at 4K60 [secondary].
- **Formats** (Apple's numbers are for iPhone XS, 2019) [primary: WWDC19]: binned 640×480 up to 1920×1440 at up to
  60 fps; 1920×1080 and 1920×1440 at 30 fps unbinned; "We do not support 12 megapixel on N cameras", though 12 MP stills
  work. A 120 fps format costs as 120 fps even when run at 60; lower it with `videoMinFrameDurationOverride`.
- **`hardwareCost`:** the share of the hardware budget in use, 0.0–1.0. Above 1.0 the session "cannot run your
  configuration" and posts `runtimeErrorNotification` [primary: docs]; it is an ISP-bandwidth limit, "all or nothing"
  [primary: WWDC19].
- **`systemPressureCost`:** above 1.0 the session "cannot run sustainably, but it may be able to run briefly", and at
  critical pressure it is interrupted [primary: docs]. WWDC19's rule of thumb: below 1, indefinitely; 1–2, up to 15 min;
  2–3, up to 10 min; above 3, "a short little bit"; lower the frame rate first [primary]. A 10–30 min drive needs a
  cost below 1 [inference].
- **Synchronisation:**
  - **Virtual-device constituents** (the dual, dual-wide or triple camera's physical cameras, streamed through hidden
    ports via `ports(for:sourceDeviceType:sourceDevicePosition:)`): same resolution and frame rate, "at a hardware
    level, they are synchronized ... the middle line of the readout is exactly at the same clock time", and exposure,
    white balance and focus move together [primary: WWDC19, said of the wide+tele dual camera]. The docs promise
    "synchronized, full-frame-rate delivery" [primary]. That this holds for dual-wide and triple on the 15 Pro Max is
    [inference].
  - **`AVCaptureDataOutputSynchronizer`** only groups samples with the same timestamp into one callback: "That thing is
    not doing the hardware synchronization" [primary: WWDC19].
  - **Cameras added as separate inputs:** no Apple statement found. Assume they run freely; measure offsets [inference].
- **Dual-wide limits** [primary: docs]: no custom exposure mode; focus and white balance lock only at their current
  values, and locked values may still change when the device switches camera.

## 3. LiDAR

**ARKit (`ARFrame.sceneDepth`, iOS 14)** [primary unless tagged]:
- Each pixel is the distance in metres from the camera plane; `confidenceMap` gives low/medium/high per pixel as 8-bit
  values (`L008`). Confidence drops on "highly reflective" or highly absorbing surfaces.
- 256×192 (WWDC22 110429); "available at 60 Hz on each AR frame" (WWDC20 10611). A forum poster measured 256×192 at
  60 FPS in a thread Apple staff answered [secondary for the measurement].
- Built by fusing the wide camera's RGB with LiDAR returns "using advanced machine learning algorithms" (WWDC20).
- `smoothedSceneDepth` is "averaged across several frames"; the window is not stated.
- Range: "up to 5 meters away, works both indoors and outdoors". Apple said this of the 2020 iPad Pro's LiDAR; no
  iPhone figure was found. Apple publishes no accuracy figure; a forum request for one got only an unsourced community
  error model [secondary].

**AVFoundation (`builtInLiDARDepthCamera`, iOS 15.4)** [primary unless tagged]:
- "A device that consists of two cameras, one LiDAR and one YUV", using the rear wide camera. Depth is
  "perspective-corrected" to the YUV frames; field of view and aspect ratio always match.
- An ML model fuses the sparse LiDAR points with the wide RGB into "absolute depth". Dual, dual-wide and triple cameras
  give only "relative, disparity-based depth".
- Video formats from 640×480 to 4032×3024 (on the 2022 phones). Depth streams at up to 320×240; 768×576 comes with
  photos; both differ slightly between 16:9 and 4:3.
- Rate: Apple DTS says "all of the formats have a 'Depth Max FPS' of 30 fps". One developer ran 1280×720 video at
  60 fps with 320×180 depth at 30 fps on an iPad Pro (6th gen) [secondary].
- Filtering is on by default, but "computer vision apps should prefer non-filtered depth"; unfiltered output drops
  low-confidence points.
- Multi-cam: the telephoto and ultra-wide can be added (§2). Whether any LiDAR format on the 15 Pro Max is flagged
  `isMultiCamSupported`: not found.

## 4. ARKit world tracking

- **Which camera:** the wide camera "delivers the images for the rendering backdrop" [primary: WWDC22 10126]. A 4K
  `ARVideoFormat` printed on a 13 Pro Max reads `captureDeviceType=AVCaptureDeviceTypeBuiltInWideAngleCamera`
  [secondary]. ARKit may also use the ultra-wide internally for "world tracking, motion capture, or person
  segmentation" [primary: WWDC22].
- **Formats:** default binned 1920×1440 at up to 60 fps, "roughly every 17 milliseconds"; 4K is 3840×2160 at 30 fps
  on iPhone 11 and later via `recommendedVideoFormatFor4KResolution` (iOS 16); HDR works only on non-binned formats and
  costs performance [primary]. Apple staff (June 2026): "10-bit (x420) pixel format and up to a resolution of 4K ...
  the highest quality video formats that can be used with ARKit"; no ProRes or Log [primary]. "Only video formats
  returned by the supportedVideoFormats function are supported" [primary: Apple staff]. The 15 Pro Max's list: not found.
- **Stills during a session:** `captureHighResolutionFrame` (iOS 16) gives "the full 12 megapixels of the wide
  camera" on an iPhone 13; iOS 26 adds a variant that takes `AVCapturePhotoSettings`; `sceneDepth` comes with
  high-resolution frames under the default settings [primary, the last from Apple staff].
- **Pose:** `ARCamera.transform`, 6-DoF per frame; world tracking "combines information from the iOS device's motion
  sensing hardware with computer vision analysis" [primary]. No Apple sentence names metres as the world unit; Stray
  Scanner and ios_logger both log ARKit positions in metres [primary: repos].
- **Intrinsics:** `ARCamera.intrinsics` is a pinhole K in pixels [primary]. It is not constant: one developer saw
  fx/fy move about 36 px (cx 1.5 px, cy 2.3 px) during a 4K/30 session [secondary]. Autofocus is on by default
  (`isAutoFocusEnabled`) [primary]; turning it off should steady K [inference].
- **Exposure:** `ARCamera.exposureDuration` and `exposureOffset` per frame (iOS 13); `ARFrame.exifData` (iOS 16)
  includes "exposure, and the date and time" [primary]. Whether ISO is in `exifData`: probe.
- **No lens distortion:** `ARFrame.capturedDepthData`, the only ARKit route to `AVCameraCalibrationData`, is
  "available only in face-based experiences ... front TrueDepth camera" [primary], so world tracking gives no
  distortion table [inference].
- **Camera settings:** `configurableCaptureDeviceForPrimaryCamera` (iOS 16) returns the `AVCaptureDevice`, so focus,
  exposure and white balance can be locked; "extreme changes can affect ARKit's features" [primary].
- **IMU (CoreMotion, separate API):** the maximum rate "is hardware-dependent but is usually at least 100 Hz";
  `CMLogItem.timestamp` counts "seconds since the device booted" [primary]. The clock behind `ARFrame.timestamp` is
  not documented (not found).
- **ARKit + other cameras: not supported.** Apple staff said so three times [primary]:
  - Nov 2022, on recording ultra-wide RGB alongside ARKit: "That is not possible at this time".
  - Dec 2024, on 48 MP ultra-wide stills during ARKit, after both a multi-cam session and a second session had failed:
    "There is no supported way to do this".
  - Jan 2026: "There's no supported way for you to access the ultra wide camera while an ARSession is running". That
    poster's repro: start an `AVCaptureSession`, then an `ARSession`, and the capture session stops [secondary].

## 5. Calibration and metadata (AVFoundation)

- **Per-frame intrinsics:** set `AVCaptureConnection.isCameraIntrinsicMatrixDeliveryEnabled` (iOS 11) before
  `startRunning()`; each video buffer then carries `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix` (3×3) [primary].
- **Lens distortion:** `AVCameraCalibrationData` holds K with its reference dimensions, the extrinsics, the pixel size
  in mm, the radial `lensDistortionLookupTable`, its inverse, and `lensDistortionCenter` [primary]. It arrives:
  - with depth, as `AVDepthData.cameraCalibrationData`, from the LiDAR depth camera or the dual-wide (which also streams
    depth, per Apple DTS) [primary];
  - with photos, only when constituent photo delivery is on and both content-aware distortion correction and the
    device's geometric distortion correction (GDC) are off [primary];
  - never for a single wide camera without depth (no route found).

  Apple DTS: the table and centre can undistort `AVCaptureVideoDataOutput` frames, with reference code in the comments
  of `AVCameraCalibrationData.h` [primary].
- **GDC:** `isGeometricDistortionCorrectionEnabled` is true by default wherever supported [primary]; it is on for the
  ultra-wide [secondary]; calibration delivery needs it off [primary].
- **Extrinsics:** `AVCaptureDevice.extrinsicMatrix(from:to:)` (iOS 13) returns `[R|t]`, t in millimetres,
  `X_to = [R|t]·X_from`. "Only physical cameras for which factory calibrations exist" provide one; virtual devices
  return nil; "Disable video stabilization if you're using the extrinsic matrix" [primary].
- **Stabilisation:** `preferredVideoStabilizationMode` defaults to off [primary]; set `.off` explicitly [inference].
- **Locks:** `setFocusModeLocked(lensPosition:)` and `setExposureModeCustom(duration:iso:)`. Each completion handler
  returns the timestamp of the first buffer with the new settings, on the device clock; convert it to
  `synchronizationClock` before comparing. Changing the exposure can change the frame duration [primary].
- **Per-frame ISO and exposure:** AVFoundation documents no per-frame field. Developers read the EXIF dictionary
  attached to each video buffer, whose values can differ from the device's `iso` and `exposureDuration` [secondary].
- **OIS:** no public switch to turn off the sensor-shift stabiliser for video was found [UNCERTAIN].

## 6. Spatial video

- **Camera app** (iOS 17.2+): "Spatial videos are captured using the Main and Ultra Wide cameras", in landscape, "in
  1080p at 30 frames per second in standard dynamic range"; "A minute of spatial video is approximately 130MB"
  [primary: Apple newsroom; the tech specs say the same].
- **Developer API** (iOS 18) [primary: WWDC24 10166]: open `builtInDualWideCamera`, choose a format with
  `isSpatialVideoCaptureSupported`, set `AVCaptureMovieFileOutput.isSpatialVideoCaptureEnabled = true`;
  `.cinematicExtendedEnhanced` stabilisation is recommended. "spatial video requires the wide and ultra wide cameras to
  be streaming simultaneously". "All of the complexity of synchronization, camera calibration, encoding, and metadata
  writing are abstracted away. You just get a fully formed spatial video file on disk". The preview shows only the wide.
- **The file:** stereo MV-HEVC plus metadata: rectilinear projection, baseline, field of view and disparity adjustment
  [primary]. The wide/ultra-wide differences are corrected by "computational photography" [primary], so the second eye
  is processed, not raw [inference]. Both eyes can be decoded later as tagged buffers [primary: Apple's macOS 14
  sample], using `kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs` [secondary].
- **Verdict:** a file, not two live streams. Live stereo frames with per-frame calibration: not found. For raw,
  synchronised wide + ultra-wide frames with calibration, stream the dual-wide's constituent ports in a multi-cam
  session (§2) [inference].

## 7. Existing capture apps

| App | Records | Format | Rate | Licence / price | >1 rear camera? |
|---|---|---|---|---|---|
| **Stray Scanner** | ARKit RGB, LiDAR depth + confidence, per-frame pose + intrinsics, IMU [primary] | `rgb.mp4` (HEVC) at ARKit's default format, since the app sets no `videoFormat`; depth 256×192 16-bit PNG in mm; confidence PNG 0/1/2; `odometry.csv` (time, xyz in m, quaternion, fx fy cx cy); `imu.csv` (m/s², rad/s) [primary: docs + code] | saves at 60/30/15/5/1 fps; asks CoreMotion for 1200 Hz, which is capped to the hardware maximum [primary] | MIT, free; 164★, last push 2026-04-04 [primary] | No |
| **Record3D** | LiDAR (or FaceID) "3D videos"; streams per-frame 6-DoF pose + intrinsics (v1.6.8 notes) [primary: store page] | custom `.r3d`; exports EXR depth + JPG, PLY, glTF/FBX/OBJ/Alembic, RGBD mp4, spatial or side-by-side video; USB streaming (LGPL-2.1 library), lossy Wi-Fi [primary] | not stated | free for 3 videos; in-app purchases $3.99 Basic, $4.99 Full, $2.99 Wi-Fi & RGBD [primary] | No |
| **NeRFCapture** | ARKit posed images, plus depth on LiDAR phones [primary] | zip in Instant-NGP's format, or live over CycloneDDS [primary] | not stated | MIT; App Store; last push 2023-12-11 [primary] | No |
| **Spectacular Rec** | "video and IMU sensor data"; manual focus and exposure-time recording since v1.2.0 (2024-03-22); poses are computed later by `sai-cli` [primary] | folder of `data.jsonl` + video; the format allows `data2`/`data3` for multi-camera rigs [primary] | not stated | free; the SDK and CLI are free for non-commercial use [primary] | Not stated for iPhone |
| **Polycam raw data** | LiDAR or Room captures with Developer mode on: keyframe images, a camera JSON per keyframe (fx, fy, cx, cy, width, height, 4×4 pose, blur_score), depth, confidence [primary: nerfstudio reader; secondary: layout] | zip | keyframes only [secondary] | price not checked | No |
| **ios_logger** | ARKit video, pose (m, quaternion), per-frame intrinsics, accelerometer/gyro/magnetometer, GPS; no LiDAR [primary] | text files + m4v | not stated | no licence; last push 2020-09-07 [primary] | No |

- None of these records more than one rear camera, and none uses `AVCaptureMultiCamSession` [inference from their docs
  and code].
- Stray Scanner's optional `distortion/` folder reads `capturedDepthData`, which Apple says is nil outside face
  tracking, so expect it to be empty [inference].
- nerfstudio's docs say Polycam's poses are "globally optimized which make them more robust to drift" [primary].

## 8. Recommended capture recipe

**Now (M3, one forward camera)** [inference, built on §3–§5]:
1. ARKit world tracking with `recommendedVideoFormatFor4KResolution` (3840×2160 at 30 fps). Fall back to 1920×1440 at
   60 fps if motion blur or tracking loss hurts.
2. `frameSemantics = [.sceneDepth]`, raw depth + confidence. Not smoothed depth: it averages frames while the car moves.
   Treat depth beyond about 5 m as unknown.
3. Once the road view settles, lock the camera through `configurableCaptureDeviceForPrimaryCamera`: focus locked with
   `isAutoFocusEnabled = false`; a custom short exposure with fixed ISO, chosen on site; white balance locked;
   `videoHDRAllowed = false`.
4. Log per frame: timestamp, image (HEVC), `transform`, `intrinsics` (it still moves), `exposureDuration`, `exifData`,
   tracking state, depth + confidence. Also log CoreMotion at its maximum rate, and CoreLocation fixes so D-010's GPS
   speed can check the scale.
5. Fork Stray Scanner (MIT) instead of starting from zero. It lacks 4K, the locks, EXIF and GPS.

**Later (more than one camera):** ARKit cannot do this, so switch to `AVCaptureMultiCamSession`:
- Cameras: the LiDAR depth camera (wide + depth up to 320×240 at 30 fps) + the ultra-wide, + the telephoto if a device
  set allows it; multi-cam formats at 30 fps.
- Settings: stabilisation off, GDC off; focus, exposure and white balance locked; per-frame intrinsics on. Save
  `AVCameraCalibrationData` from the depth stream and `extrinsicMatrix(from:to:)` once. Poses: offline SLAM + CoreMotion.
- Synchronised phones would need genlock, which requires an iPhone 17 Pro or later [primary: Apple Support]; the
  15 Pro Max cannot do it.

## 9. Dead ends, and the probe that settles them

**Could not confirm:**
- On the 15 Pro Max: the `supportedMultiCamDeviceSets`, the multi-cam format list and the `hardwareCost` values;
  whether all three rear cameras, or LiDAR + ultra-wide + telephoto, can run together; the ARKit format list, whether
  `sceneDepth` works in 4K, and the clock behind `ARFrame.timestamp`; the LiDAR depth formats (a 4K video format with
  depth?) and whether the depth calibration includes the distortion table.
- Whether separately added cameras are synchronised in hardware.
- Wide + ultra-wide multi-cam: it failed on an iPhone 12 Pro, and worked on an unnamed device [both secondary].
- The LiDAR range and accuracy on iPhone (Apple gives 5 m only for the iPad Pro).
- Live spatial-video streams or per-frame stereo calibration; a switch to turn OIS off for video; a per-frame ISO API
  in AVFoundation.
- `isLockedVideoFrameDurationSupported` on the 15 Pro Max (reported false on a 16 Pro running iOS 26.2 [secondary]).
- Searched with nothing found: GitHub dumps of the iPhone 15 Pro's format list, and any app or article that names the
  lenses used in a "triple" mode.

**Probe app** (one screen that writes JSON; about an hour of work [inference]):
1. Print `AVCaptureMultiCamSession.isMultiCamSupported`. Build a `DiscoverySession` over wide, ultra-wide, telephoto,
   dual, dual-wide, triple, LiDAR depth and TrueDepth with position `.unspecified`; print each
   `supportedMultiCamDeviceSets` entry as sorted `deviceType/position`.
2. For every device, print each format's dimensions, pixel format, `videoSupportedFrameRateRanges`,
   `isMultiCamSupported`, `isVideoBinned`, `isSpatialVideoCaptureSupported`, `videoFieldOfView`, and each
   `supportedDepthDataFormats` entry with its size and frame rates. Per device, print
   `isGeometricDistortionCorrectionSupported` and `constituentDevices`.
3. Commit each configuration at its largest multi-cam format at 30 fps and print `hardwareCost` and
   `systemPressureCost`: (a) wide + ultra-wide; (b) + telephoto; (c) LiDAR + ultra-wide; (d) LiDAR + ultra-wide +
   telephoto; (e) the dual-wide's constituent ports; (f) the triple camera's. Run each runnable one for 10 min, logging
   `systemPressureState`, dropped frames and per-stream PTS; the inter-camera PTS offsets show hardware sync.
4. Print `extrinsicMatrix(from:to:)` for every pair of rear physical cameras; `isCameraIntrinsicMatrixDeliverySupported`
   per connection; and from the LiDAR depth stream, `cameraCalibrationData` (K, reference dimensions,
   `lensDistortionLookupTable != nil`, `lensDistortionCenter`, `pixelSize`).
5. ARKit: print `supportedVideoFormats` (`imageResolution`, `framesPerSecond`, `captureDeviceType`,
   `isVideoHDRSupported`, `isRecommendedForHighResolutionFrameCapturing`), `recommendedVideoFormatFor4KResolution` and
   `supportsFrameSemantics(.sceneDepth)`. Run 4K + `.sceneDepth` for 60 s; log the depth size and rate, the spread of
   intrinsics with autofocus on and off, the `exifData` keys, and `ARFrame.timestamp` against
   `CMDeviceMotion.timestamp` and `ProcessInfo.systemUptime`.
6. Print `AVCaptureDeviceInput.isLockedVideoFrameDurationSupported` for the wide camera.
