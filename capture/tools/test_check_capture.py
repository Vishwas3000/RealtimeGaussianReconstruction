"""Tests for check_capture.py on a synthetic drive. Run: python -m unittest discover -s capture/tools"""
import math
import tempfile
import unittest
from pathlib import Path

import check_capture as cc

LAT0, LON0 = 12.9716, 77.5946  # any reference point; Bengaluru here
M_PER_DEG = cc.EARTH_RADIUS_M * math.pi / 180  # same sphere as the checker's haversine


UPRIGHT = (1.0, 0.0, 0.0, 0.0)  # qx, qy, qz, qw: OpenCV camera looking level, image upright (180° about x)


def pitched_down(deg):
    """UPRIGHT followed by a pitch of `deg` degrees down about the camera's x axis."""
    half = math.radians(deg) / 2
    return (math.cos(half), 0.0, 0.0, math.sin(half))


def write_capture(folder: Path, arkit_scale=1.0, drop_every=0, radius=50.0, speed=10.0, fps=30, quat=UPRIGHT):
    """One lap of a circle at constant speed: odometry and frames at `fps`, GPS at 1 Hz."""
    duration = 2 * math.pi * radius / speed
    n = int(duration * fps) + 1

    def true_xz(t):
        angle = speed * t / radius
        return radius * math.cos(angle), radius * math.sin(angle)

    odo = ["timestamp, frame, x, y, z, qx, qy, qz, qw, fx, fy, cx, cy, distortion_center_x, distortion_center_y"]
    frames = ["timestamp, frame, tracking_state, tracking_reason, exposure_duration, exposure_offset, "
              "exif_exposure_time, exif_iso, exif_brightness, camera_locked, thermal_state, has_depth"]
    q = ", ".join(str(v) for v in quat)
    saved = 0
    for i in range(n):
        if drop_every and i > 0 and i % drop_every == 0:
            continue
        t = i / fps
        x, z = true_xz(t)
        odo.append(f"{100 + t}, {saved:06d}, {x * arkit_scale}, 0.0, {z * arkit_scale}, {q}, 1500, 1500, 960, 720, , ")
        frames.append(f"{100 + t}, {saved:06d}, normal, , 0.001, 0.0, 0.001, 400, 5.0, 1, 0, 0")
        saved += 1
    gps = ["timestamp, unix_time, latitude, longitude, altitude, horizontal_accuracy, vertical_accuracy, "
           "speed, speed_accuracy, course, course_accuracy"]
    for s in range(int(duration) + 1):
        x, z = true_xz(s)
        lat = LAT0 + z / M_PER_DEG
        lon = LON0 + x / (M_PER_DEG * math.cos(math.radians(LAT0)))
        gps.append(f"{100 + s}, {1.7e9 + s}, {lat:.8f}, {lon:.8f}, 900, 3.0, 4.0, {speed}, 0.5, 0, 5")
    for name, lines in (("odometry.csv", odo), ("frames.csv", frames), ("gps.csv", gps)):
        (folder / name).write_text("\n".join(lines) + "\n", encoding="utf-8")
    return n


def write_multilens(folder: Path, lens_offset_s=0.0, seconds=20, fps=30, imu_hz=100, speed=10.0):
    """A multi-lens recording driving north in a straight line: two lenses, IMU, GPS at 1 Hz."""
    import json
    (folder / "capture_info.json").write_text(json.dumps(
        {"mode": "multi-lens", "preset": "Wide + ultra-wide, 4K", "lenses": ["wide", "ultraWide"]}), encoding="utf-8")
    header = "timestamp, frame, fx, fy, cx, cy, exposure_time, iso, thermal_state"
    for lens, offset in (("wide", 0.0), ("ultraWide", lens_offset_s)):
        rows = [header] + [f"{100 + i / fps + offset}, {i:06d}, 2800, 2800, 1920, 1080, 0.001, 200, 0"
                           for i in range(seconds * fps + 1)]
        (folder / f"{lens}.csv").write_text("\n".join(rows) + "\n", encoding="utf-8")
    imu = ["timestamp, a_x, a_y, a_z, alpha_x, alpha_y, alpha_z"] + [
        f"{100 + i / imu_hz}, 0, -1, 0, 0, 0, 0" for i in range(seconds * imu_hz + 1)]
    (folder / "imu.csv").write_text("\n".join(imu) + "\n", encoding="utf-8")
    gps = ["timestamp, unix_time, latitude, longitude, altitude, horizontal_accuracy, vertical_accuracy, "
           "speed, speed_accuracy, course, course_accuracy"] + [
        f"{100 + s}, {1.7e9 + s}, {LAT0 + speed * s / M_PER_DEG:.8f}, {LON0:.8f}, 900, 3.0, 4.0, {speed}, 0.5, 0, 5"
        for s in range(seconds + 1)]
    (folder / "gps.csv").write_text("\n".join(gps) + "\n", encoding="utf-8")


class CheckCaptureTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.folder = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def report(self):
        r = cc.analyse(self.folder)
        r["warnings"] = cc.warnings_for(r)
        return r

    def test_clean_closed_loop(self):
        write_capture(self.folder)
        r = self.report()
        self.assertAlmostEqual(r["fps"], 30, delta=0.1)
        self.assertAlmostEqual(r["path_length_m"], 2 * math.pi * 50, delta=1.0)
        self.assertLess(r["loop_error_m"], 0.5)
        self.assertAlmostEqual(r["scale_arkit_over_gps"], 1.0, delta=0.01)
        self.assertEqual(r["tracking_normal_pct"], 100)
        self.assertEqual(r["missing_frames"], 0)
        self.assertEqual(r["warnings"], [])
        self.assertIn("ARKit/GPS scale 1.00", cc.format_report(self.folder, r))

    def test_wrong_scale_is_flagged(self):
        write_capture(self.folder, arkit_scale=1.1)
        r = self.report()
        self.assertAlmostEqual(r["scale_arkit_over_gps"], 1.1, delta=0.01)
        self.assertTrue(any("scale" in w for w in r["warnings"]))

    def test_dropped_frames_are_counted(self):
        n = write_capture(self.folder, drop_every=10)
        r = self.report()
        self.assertAlmostEqual(r["missing_frames"], n // 10, delta=2)
        self.assertTrue(any("missing" in w for w in r["warnings"]))

    def test_mount_orientation(self):
        cases = [
            (UPRIGHT, "upright", None),
            ((0.0, 0.0, 0.0, 1.0), "upside down", "upside down"),        # ARKit's own camera axes: image y points up
            ((0.0, 0.0, math.sqrt(0.5), math.sqrt(0.5)), "sideways", "sideways"),  # image x along world up: portrait mount
        ]
        for quat, mount, warning in cases:
            with self.subTest(mount=mount):
                write_capture(self.folder, quat=quat)
                r = self.report()
                self.assertEqual(r["mount"], mount)
                found = any(warning in w for w in r["warnings"]) if warning else not r["warnings"]
                self.assertTrue(found, r["warnings"])

    def test_camera_tilt(self):
        write_capture(self.folder, quat=pitched_down(30))
        r = self.report()
        self.assertEqual(r["mount"], "upright")
        self.assertAlmostEqual(r["camera_tilt_deg"], -30, delta=0.5)
        self.assertTrue(any("30° down" in w for w in r["warnings"]))
        write_capture(self.folder, quat=pitched_down(8))
        self.assertFalse(self.report()["warnings"])

    def test_short_handheld_clip_has_no_loop_warning(self):
        # Numbers from the first real recording: 0.7 m of hand movement, ending 0.08 m from the start.
        r = {"frames": 146, "missing_frames": 1, "path_length_m": 0.7, "loop_error_m": 0.08,
             "loop_error_pct": 10.3, "gps_fixes_used": 2, "scale_arkit_over_gps": None, "gps_loop_error_m": 0.0}
        self.assertFalse(any("ended near its start" in w for w in cc.warnings_for(r)))
        r.update(path_length_m=2000.0, loop_error_m=40.0, loop_error_pct=2.0)
        self.assertTrue(any("ended near its start" in w for w in cc.warnings_for(r)))

    def multilens_report(self):
        import json
        info = json.loads((self.folder / "capture_info.json").read_text(encoding="utf-8"))
        r = cc.analyse_multilens(self.folder, info)
        r["warnings"] = cc.warnings_multilens(r)
        return r

    def test_multilens_in_sync(self):
        write_multilens(self.folder)
        r = self.multilens_report()
        for lens in ("wide", "ultraWide"):
            self.assertAlmostEqual(r["lenses"][lens]["fps"], 30, delta=0.1)
            self.assertEqual(r["lenses"][lens]["intrinsics_rows"], r["lenses"][lens]["frames"])
        self.assertLess(r["lens_offsets_ms"]["wide-ultraWide"], 0.01)
        self.assertAlmostEqual(r["imu_rate_hz"], 100, delta=0.5)
        self.assertAlmostEqual(r["gps_distance_m"], 200, delta=1)     # 10 m/s for 20 s
        self.assertAlmostEqual(r["gps_mean_speed_kmh"], 36, delta=0.5)
        self.assertEqual(r["warnings"], [])
        self.assertIn("multi-lens", cc.format_multilens(self.folder, r))

    def test_multilens_out_of_sync_is_flagged(self):
        write_multilens(self.folder, lens_offset_s=0.008)  # free-running lenses, like the probe's separate inputs
        r = self.multilens_report()
        self.assertAlmostEqual(r["lens_offsets_ms"]["wide-ultraWide"], 8.0, delta=0.1)
        self.assertTrue(any("not hardware-synchronised" in w for w in r["warnings"]))

    def test_plain_stray_scanner_recording_still_works(self):
        write_capture(self.folder)
        (self.folder / "frames.csv").unlink()
        (self.folder / "gps.csv").unlink()
        r = self.report()
        self.assertNotIn("tracking_normal_pct", r)
        self.assertTrue(any("GPS" in w for w in r["warnings"]))


if __name__ == "__main__":
    unittest.main()
