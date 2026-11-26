
# Data Specification

This document describes the data format recorded by the app.

The collected datasets are each contained in a folder, named after a random hash, for example `71de12f9`. A dataset folder has the following directory structure:

```
capture_info.json    (RoadCapture)
camera_matrix.csv
odometry.csv
frames.csv           (RoadCapture)
gps.csv              (RoadCapture)
imu.csv
depth/               (only when LiDAR is on)
  - 000000.png
  - 000001.png
  - ...
confidence/          (only when LiDAR is on)
  - 000000.png
  - 000001.png
  - ...
distortion/          (optional, present when lens distortion data is available)
  - 000000.bin
  - 000001.bin
  - ...
rgb.mp4
```

**Clock.** Every `timestamp` column, in every CSV, is in seconds on the phone's system uptime clock (the clock
behind `ARFrame.timestamp` and Core Motion). So rows from different files can be matched by time.

**Frame order.** `rgb.mp4`, `odometry.csv`, `frames.csv` and `depth/` hold the same frames in the same order: the
Nth video frame is the row whose `frame` is N. Frames the phone could not encode in time are dropped from all of them
together, which shows up as a gap in `timestamp`.

`rgb.mp4` is an HEVC encoded video, which contains the recorded data from the iPhone's camera. RoadCapture records
3840×2160 at 30 fps (4K30) or 1920×1440 at 60 fps (1440p60), at about 0.2 bit per pixel, and stamps each frame with
its capture time, so playback speed is correct at either rate.

The `depth/` directory contains the depth maps. One `.png` file per rgb frame. Each of these is a 16 bit grayscale png image. They are 256×192 in 4:3 formats such as 1440p60, and 256×144 in 16:9 4K30 (measured on an iPhone 15 Pro, iOS 27.2.1). The values are the measured depth in millimeters, for that pixel position. In [OpenCV](https://docs.opencv.org/4.5.5/), these can be read with `cv2.imread(depth_frame_path, -1)`.

The `confidence/` directory contains confidence maps corresponding to each depth map. They are grayscale png files encoding 192 x 256 element matrices. The values are either 0, 1 or 2. A higher value means a higher confidence.

The `camera_matrix.csv` is a 3 x 3 matrix containing the [camera intrinsic parameters](https://en.wikipedia.org/wiki/Camera_resectioning#Intrinsic_parameters) from the final recorded frame. This file is kept for backwards compatibility; for per-frame intrinsics use the `fx`, `fy`, `cx`, `cy` columns in `odometry.csv`.

The `odometry.csv` file contains the camera pose and intrinsics for each frame. The first line is a header. The meaning of the fields are:

| Field | <div style="width: 500px">Meaning</div> |
|---|---|
| timestamp | Timestamp in seconds |
| frame | Frame number to which this pose corresponds to e.g. `000005` |
| x | x coordinate in meters from when the session was started |
| y | y coordinate in meters from when the session was started |
| z | z coordinate in meters from when the session was started |
| qx | x component of quaternion representing camera pose rotation |
| qy | y component of quaternion representing camera pose rotation |
| qz | z component of quaternion representing camera pose rotation |
| qw | w component of quaternion representing camera pose rotation |
| fx | Horizontal focal length in pixels |
| fy | Vertical focal length in pixels |
| cx | Principal point x coordinate in pixels |
| cy | Principal point y coordinate in pixels |
| distortion_center_x | x coordinate of the lens distortion center in pixels (empty if unavailable) |
| distortion_center_y | y coordinate of the lens distortion center in pixels (empty if unavailable) |

The `distortion/` directory contains per-frame lens distortion lookup tables, present only when the device exposes calibration data. Each `.bin` file is a raw array of little-endian `float32` values mapping radial distance from the distortion center to a correction factor. The number of entries is `file_size_in_bytes / 4`. The filenames correspond to the `frame` field in `odometry.csv`.

The `imu.csv` file contains timestamps, linear acceleration readings and angular rotation readings. The first line is a header. The meaning of the fields are:

| Field | <div style="width: 500px">Meaning</div> |
|---|---|
| timestamp | Timestamp in seconds |
| a\_x | Acceleration in g (Core Motion's unit) in x direction |
| a\_y | Acceleration in g (Core Motion's unit) in y direction |
| a\_z | Acceleration in g (Core Motion's unit) in z direction |
| alpha\_x | Rotation in rad/s around the x-axis |
| alpha\_y | Rotation in rad/s around the y-axis |
| alpha\_z | Rotation in rad/s around the z-axis |


## Added by RoadCapture

`frames.csv` has one row per saved frame, in the same order as `odometry.csv`:

| Field | Meaning |
|---|---|
| timestamp, frame | As in `odometry.csv` |
| tracking_state | `normal`, `limited` or `not_available` (ARKit's world tracking) |
| tracking_reason | When limited: `initializing`, `excessive_motion`, `insufficient_features` or `relocalizing` |
| exposure_duration | `ARCamera.exposureDuration`, seconds |
| exposure_offset | `ARCamera.exposureOffset`, EV |
| exif_exposure_time, exif_iso, exif_brightness | From `ARFrame.exifData` (iOS 16+); empty when absent |
| camera_locked | 1 after the Lock button was pressed (white balance locked, shutter ≤ 1/1000 s) |
| thermal_state | `ProcessInfo.thermalState`: 0 nominal, 1 fair, 2 serious, 3 critical |
| has_depth | 1 when this frame has LiDAR depth |

`gps.csv` has one row per Core Location fix while recording:

| Field | Meaning |
|---|---|
| timestamp | Uptime-clock seconds (the fix's wall-clock time moved onto the uptime clock) |
| unix_time | The fix's own time, seconds since 1970 |
| latitude, longitude | Degrees (WGS84) |
| altitude | Metres |
| horizontal_accuracy, vertical_accuracy | Metres; negative means invalid |
| speed, speed_accuracy | m/s; negative means invalid |
| course, course_accuracy | Degrees from true north; negative means invalid |

`capture_info.json` records the app version, device model, iOS version, capture mode, image size, camera and saved
frame rates, whether LiDAR depth was on, and whether the camera was locked when recording started.

**Privacy.** `gps.csv` is where you drove, and the video shows faces and number plates. Don't commit recordings to a
public repository.

**IMU units (RoadCapture correction).** The upstream table said m/s², but the code writes Core Motion's raw
accelerometer values, which are in g. A phone at rest reads |a| ≈ 1.0: 1.003 was measured on a real recording. Multiply
by 9.80665 for m/s². The motion sensors run at 100 Hz on the iPhone 15 Pro, measured.

## Multi-lens recordings (RoadCapture, D-014)

Made with the **Multi-lens** button. There is no ARKit, so no `odometry.csv` and no depth. Camera positions are computed
afterwards from the videos plus `imu.csv`.

```
capture_info.json    mode "multi-lens", preset, lenses, size, factory extrinsics between lenses, settings
wide.mp4             one HEVC video per lens, ~0.2 bit/pixel
wide.csv             one row per frame in that video
ultraWide.mp4
ultraWide.csv
tele.mp4, tele.csv   only with the "3 lenses · 1080p" preset
imu.csv              same format as above (g, rad/s), 100 Hz
gps.csv              same format as above
```

| Preset | Lenses | Size | Sync between lenses (probe) |
|---|---|---|---|
| 2 lenses · 4K (default) | wide, ultraWide | 3840×2160, 30 fps | hardware, 0.11 ms |
| 3 lenses · 1080p | wide, ultraWide, tele | 1920×1080, 30 fps | hardware, 0.2–0.4 ms |

`<lens>.csv` columns:

| Field | Meaning |
|---|---|
| timestamp | The frame's capture time (sample-buffer PTS), seconds on the host/uptime clock, the same clock as `imu.csv` and `gps.csv` |
| frame | Index of the frame in `<lens>.mp4` (frames the encoder couldn't take are dropped from both) |
| fx, fy, cx, cy | That frame's intrinsics in pixels (`kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix`) |
| exposure_time, iso | From the frame's EXIF attachment |
| thermal_state | 0 nominal … 3 critical |

**Timing.** Each `<lens>.mp4` starts at that lens's first frame, so frame N plays at `timestamp[N] - timestamp[0]`. Match
frames across lenses by `timestamp`, not by index.

**Camera settings.**
- Auto focus, exposure and white balance. The longest shutter auto exposure may use is a setting:
  - **≤1/1000** (default) for daylight driving;
  - **≤1/250** for overcast or dusk;
  - **Auto** for night and indoor tests.

  At 1/1000 s indoors, ISO pins at its ceiling (2000 wide, 3200 ultra-wide, measured) and frames come out nearly
  black. **Lock** freezes all three. `capture_info.json` records `shutter_cap`.
- All lenses share one start time and one stop time, so synchronised lenses keep exactly the same frames (measured:
  248/248, first and last frames 0.11 ms apart).
- Video stabilisation is off.
- Apple's geometric distortion correction is left **on**, so frames are close to pinhole and match the per-frame
  intrinsics. `capture_info.json` records `gdc_enabled`.
- `extrinsics` in `capture_info.json` is the factory rotation and translation (mm) between each pair of lenses.
