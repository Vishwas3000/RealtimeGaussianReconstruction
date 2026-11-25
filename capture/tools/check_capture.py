#!/usr/bin/env python3
"""Check a RoadCapture recording before using it (TeslaRender D-013).

Reports the frame rate and dropped frames, ARKit tracking health, heat, the start-to-end error of
the ARKit trajectory (meaningful when you drive a closed loop), and ARKit's scale against GPS.

    python check_capture.py path/to/<recording folder>
    python check_capture.py path/to/<recording folder> --json

Exits with 1 when something needs attention. Standard library only, so it runs the same on macOS
and Windows.
"""
from __future__ import annotations

import argparse
import bisect
import csv
import json
import math
import statistics
from pathlib import Path

EARTH_RADIUS_M = 6_371_008.8
THERMAL_NAMES = ["nominal", "fair", "serious", "critical"]


def read_csv(path: Path) -> list[dict[str, str]]:
    """Rows of a ', '-separated RoadCapture CSV, or [] if the file is missing."""
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as f:
        return [
            {k.strip(): (v or "").strip() for k, v in row.items() if k is not None}
            for row in csv.DictReader(f, skipinitialspace=True)
        ]


def to_float(value: str | None) -> float | None:
    try:
        x = float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None
    return x if math.isfinite(x) else None


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_RADIUS_M * math.asin(math.sqrt(a))


def interpolate(times: list[float], values: list[tuple], t: float) -> tuple | None:
    """Linear interpolation of 3-vectors at time t; None outside the recorded span."""
    if not times or t < times[0] or t > times[-1]:
        return None
    i = bisect.bisect_left(times, t)
    if times[i] == t:
        return values[i]
    t0, t1 = times[i - 1], times[i]
    w = (t - t0) / (t1 - t0)
    a, b = values[i - 1], values[i]
    return tuple(a[k] + w * (b[k] - a[k]) for k in range(3))


def horizontal_m(a: tuple, b: tuple) -> float:
    """Distance in ARKit's x-z plane; ARKit's y axis points up, against gravity."""
    return math.hypot(b[0] - a[0], b[2] - a[2])


def mount_orientation(odometry_rows: list[dict[str, str]]) -> dict:
    """How the phone was mounted, from the poses.

    odometry.csv quaternions are camera-to-world with OpenCV camera axes (x right, y down, z forward in the image:
    Stray Scanner applies a 180° flip about x to ARKit's camera), and ARKit's world y axis points up.
    """
    down_up, right_up, forward_up = [], [], []
    for r in odometry_rows:
        q = [to_float(r.get(k)) for k in ("qx", "qy", "qz", "qw")]
        if None in q:
            continue
        x, y, z, w = q
        down_up.append(1 - 2 * (x * x + z * z))          # world-up part of the image's "down" axis
        right_up.append(abs(2 * (x * y + z * w)))        # world-up part of the image's "right" axis
        forward_up.append(2 * (y * z - x * w))           # world-up part of the viewing direction
    if not down_up:
        return {}
    d, s = statistics.median(down_up), statistics.median(right_up)
    if d < -0.7:
        mount = "upright"
    elif d > 0.7:
        mount = "upside down"
    elif s > 0.7:
        mount = "sideways"
    else:
        mount = "tilted"
    tilt = math.degrees(math.asin(max(-1.0, min(1.0, statistics.median(forward_up)))))
    return {"mount": mount, "camera_tilt_deg": tilt}


def analyse(folder: Path, gps_max_accuracy_m: float = 20.0, window_s: float = 5.0,
            min_gps_step_m: float = 5.0) -> dict:
    rows = []
    for r in read_csv(folder / "odometry.csv"):
        t, x, y, z = (to_float(r.get(k)) for k in ("timestamp", "x", "y", "z"))
        if None not in (t, x, y, z):
            rows.append((t, (x, y, z)))
    if len(rows) < 2:
        raise SystemExit(f"{folder}: odometry.csv is missing or has fewer than 2 usable rows")
    rows.sort()
    times = [t for t, _ in rows]
    pos = [p for _, p in rows]

    duration = times[-1] - times[0]
    dts = [b - a for a, b in zip(times, times[1:])]
    median_dt = statistics.median(dts)
    gaps = [dt for dt in dts if median_dt > 0 and dt > 1.5 * median_dt]
    path = sum(math.dist(a, b) for a, b in zip(pos, pos[1:]))
    loop = math.dist(pos[0], pos[-1])
    report: dict = {
        "frames": len(rows),
        "duration_s": duration,
        "fps": (len(rows) - 1) / duration if duration > 0 else None,
        "gaps": len(gaps),
        "missing_frames": sum(max(0, round(dt / median_dt) - 1) for dt in gaps),
        "path_length_m": path,
        "loop_error_m": loop,
        "loop_error_pct": 100 * loop / path if path > 0 else None,
    }

    report.update(mount_orientation(read_csv(folder / "odometry.csv")))

    frames = read_csv(folder / "frames.csv")  # absent in plain Stray Scanner recordings
    if frames:
        states = [r.get("tracking_state", "") for r in frames]
        report["tracking_normal_pct"] = 100 * states.count("normal") / len(states)
        problems: dict[str, int] = {}
        for r in frames:
            if r.get("tracking_state") != "normal":
                key = r.get("tracking_reason") or r.get("tracking_state") or "unknown"
                problems[key] = problems.get(key, 0) + 1
        report["tracking_problems"] = problems
        thermal = [int(v) for v in (r.get("thermal_state", "") for r in frames) if v.isdigit()]
        report["max_thermal_state"] = max(thermal) if thermal else None
        exposures = [x for x in (to_float(r.get("exposure_duration")) for r in frames) if x]
        if exposures:
            report["exposure_s_min_max"] = [min(exposures), max(exposures)]

    gps = []
    for r in read_csv(folder / "gps.csv"):
        t, lat, lon, acc = (to_float(r.get(k)) for k in ("timestamp", "latitude", "longitude", "horizontal_accuracy"))
        if None not in (t, lat, lon, acc) and 0 < acc <= gps_max_accuracy_m:
            gps.append((t, lat, lon))
    gps.sort()
    report["gps_fixes_used"] = len(gps)
    if len(gps) >= 2:
        # Compare distances over windows of a few seconds: summing fix-to-fix steps would add GPS noise as distance.
        sampled = [gps[0]]
        for g in gps[1:]:
            if g[0] - sampled[-1][0] >= window_s:
                sampled.append(g)
        arkit_m = gps_m = 0.0
        windows = 0
        for a, b in zip(sampled, sampled[1:]):
            d_gps = haversine_m(a[1], a[2], b[1], b[2])
            pa, pb = interpolate(times, pos, a[0]), interpolate(times, pos, b[0])
            if pa is None or pb is None or d_gps < min_gps_step_m:
                continue
            arkit_m += horizontal_m(pa, pb)
            gps_m += d_gps
            windows += 1
        report["gps_windows"] = windows
        report["gps_distance_m"] = gps_m
        report["scale_arkit_over_gps"] = arkit_m / gps_m if gps_m > 0 else None
        report["gps_loop_error_m"] = haversine_m(gps[0][1], gps[0][2], gps[-1][1], gps[-1][2])
    return report


def warnings_for(r: dict) -> list[str]:
    w = []
    if r.get("mount") == "sideways":
        w.append("the image is sideways: the phone was mounted upright; mount it in landscape for a wide road view")
    elif r.get("mount") == "upside down":
        w.append("the image is upside down: rotate the video 180° in processing, or turn the phone around next time")
    elif r.get("mount") == "tilted":
        w.append("the camera was rolled well off level: straighten the mount")
    if r.get("camera_tilt_deg") is not None and abs(r["camera_tilt_deg"]) > 20:
        w.append(f"the camera points {abs(r['camera_tilt_deg']):.0f}° {'down' if r['camera_tilt_deg'] < 0 else 'up'}: "
                 "aim closer to the horizon")
    if r["missing_frames"] > 0.01 * r["frames"]:
        w.append(f"{r['missing_frames']} frames missing (over 1%): the phone dropped frames; check heat and free storage")
    if r.get("tracking_normal_pct") is not None and r["tracking_normal_pct"] < 95:
        w.append(f"ARKit tracking was normal for only {r['tracking_normal_pct']:.1f}% of frames")
    if (r.get("max_thermal_state") or 0) >= 2:
        w.append(f"the phone reached '{THERMAL_NAMES[min(3, r['max_thermal_state'])]}' heat")
    scale = r.get("scale_arkit_over_gps")
    if scale is not None and abs(scale - 1) > 0.05:
        w.append(f"ARKit/GPS scale is {scale:.3f}, more than 5% off")
    if r.get("gps_fixes_used", 0) < 2:
        w.append("fewer than 2 usable GPS fixes, so the scale was not checked")
    elif r.get("scale_arkit_over_gps") is None:
        w.append("no GPS window was long enough to check the scale (drive further)")
    # Only for real drives: on a short handheld clip a few centimetres is already "over 1%".
    if (r.get("gps_loop_error_m") is not None and r["gps_loop_error_m"] < 15
            and r["path_length_m"] >= 100 and (r.get("loop_error_pct") or 0) > 1):
        w.append(f"GPS says the drive ended near its start, but ARKit's end is {r['loop_error_m']:.1f} m away "
                 f"({r['loop_error_pct']:.2f}% of the path)")
    return w


def format_report(folder: Path, r: dict) -> str:
    lines = [f"Recording: {folder}"]
    fps = f"{r['fps']:.1f} fps" if r["fps"] else "fps n/a"
    lines.append(f"Frames:    {r['frames']:,} over {r['duration_s']:.1f} s ({fps}); "
                 f"{r['gaps']} gaps, {r['missing_frames']} missing frames")
    pct = f" ({r['loop_error_pct']:.2f}% of the path)" if r["loop_error_pct"] is not None else ""
    lines.append(f"ARKit:     path {r['path_length_m']:,.1f} m; start-to-end {r['loop_error_m']:.2f} m{pct}")
    if "mount" in r:
        tilt = r["camera_tilt_deg"]
        lines.append(f"Mount:     image {r['mount']}; camera {abs(tilt):.0f}° {'down' if tilt < 0 else 'up'}")
    if "tracking_normal_pct" in r:
        problems = ", ".join(f"{k} {v}" for k, v in sorted(r["tracking_problems"].items())) or "none"
        lines.append(f"Tracking:  normal on {r['tracking_normal_pct']:.1f}% of frames; other: {problems}")
        if r.get("max_thermal_state") is not None:
            lines.append(f"Heat:      worst state {THERMAL_NAMES[min(3, r['max_thermal_state'])]}")
        if "exposure_s_min_max" in r:
            lo, hi = r["exposure_s_min_max"]
            lines.append(f"Exposure:  1/{1 / hi:.0f} s to 1/{1 / lo:.0f} s")
    if r.get("gps_fixes_used", 0) >= 2 and r.get("scale_arkit_over_gps") is not None:
        lines.append(f"GPS:       {r['gps_fixes_used']} fixes; {r['gps_distance_m']:,.1f} m over {r['gps_windows']} windows; "
                     f"ARKit/GPS scale {r['scale_arkit_over_gps']:.3f}; GPS start-to-end {r['gps_loop_error_m']:.1f} m")
    else:
        lines.append(f"GPS:       {r.get('gps_fixes_used', 0)} usable fixes")
    lines.append("Warnings:  " + ("none" if not r["warnings"] else ""))
    lines += [f"  - {w}" for w in r["warnings"]]
    return "\n".join(lines)


# --- Multi-lens recordings (D-014): no ARKit poses; one video + CSV per lens, imu.csv, gps.csv ---------------------

def frame_stats(times: list[float]) -> dict:
    times = sorted(times)
    if len(times) < 2:
        return {"frames": len(times), "duration_s": 0.0, "fps": None, "gaps": 0, "missing_frames": 0}
    dts = [b - a for a, b in zip(times, times[1:])]
    median_dt = statistics.median(dts)
    gaps = [dt for dt in dts if median_dt > 0 and dt > 1.5 * median_dt]
    duration = times[-1] - times[0]
    return {"frames": len(times), "duration_s": duration, "fps": (len(times) - 1) / duration if duration > 0 else None,
            "gaps": len(gaps), "missing_frames": sum(max(0, round(dt / median_dt) - 1) for dt in gaps)}


def nearest_gap_ms(reference: list[float], other: list[float]) -> float | None:
    """Median gap between each reference frame and the other lens's nearest frame; under 1 ms means hardware sync."""
    if not reference or not other:
        return None
    gaps = []
    for t in reference:
        i = bisect.bisect_left(other, t)
        gaps.append(min(abs(other[j] - t) for j in (i - 1, i) if 0 <= j < len(other)))
    return statistics.median(gaps) * 1000


def gps_track(folder: Path, gps_max_accuracy_m: float, window_s: float = 5.0) -> dict:
    fixes = []
    for r in read_csv(folder / "gps.csv"):
        t, lat, lon, acc = (to_float(r.get(k)) for k in ("timestamp", "latitude", "longitude", "horizontal_accuracy"))
        if None not in (t, lat, lon, acc) and 0 < acc <= gps_max_accuracy_m:
            fixes.append((t, lat, lon))
    fixes.sort()
    out: dict = {"gps_fixes_used": len(fixes)}
    if len(fixes) >= 2:
        sampled = [fixes[0]]  # every few seconds, so per-fix noise isn't summed as distance
        for g in fixes[1:]:
            if g[0] - sampled[-1][0] >= window_s:
                sampled.append(g)
        distance = sum(haversine_m(a[1], a[2], b[1], b[2]) for a, b in zip(sampled, sampled[1:]))
        span = fixes[-1][0] - fixes[0][0]
        out.update(gps_distance_m=distance, gps_mean_speed_kmh=distance / span * 3.6 if span > 0 else None,
                   gps_loop_error_m=haversine_m(fixes[0][1], fixes[0][2], fixes[-1][1], fixes[-1][2]))
    return out


def analyse_multilens(folder: Path, info: dict, gps_max_accuracy_m: float = 20.0) -> dict:
    lenses = info.get("lenses") or []
    report: dict = {"mode": "multi-lens", "preset": info.get("preset", ""), "lenses": {}}
    times: dict[str, list[float]] = {}
    thermal: list[int] = []
    exposures: list[float] = []
    for lens in lenses:
        rows = read_csv(folder / f"{lens}.csv")
        times[lens] = sorted(x for x in (to_float(r.get("timestamp")) for r in rows) if x is not None)
        stats = frame_stats(times[lens])
        stats["intrinsics_rows"] = sum(1 for r in rows if to_float(r.get("fx")))
        report["lenses"][lens] = stats
        thermal += [int(v) for v in (r.get("thermal_state", "") for r in rows) if v.isdigit()]
        exposures += [x for x in (to_float(r.get("exposure_time")) for r in rows) if x]
    if lenses:
        report["lens_offsets_ms"] = {f"{lenses[0]}-{lens}": nearest_gap_ms(times[lenses[0]], times[lens]) for lens in lenses[1:]}
    report["max_thermal_state"] = max(thermal) if thermal else None
    if exposures:
        report["exposure_s_min_max"] = [min(exposures), max(exposures)]
    imu = [x for x in (to_float(r.get("timestamp")) for r in read_csv(folder / "imu.csv")) if x is not None]
    report["imu_samples"] = len(imu)
    report["imu_rate_hz"] = (len(imu) - 1) / (imu[-1] - imu[0]) if len(imu) > 1 and imu[-1] > imu[0] else None
    report.update(gps_track(folder, gps_max_accuracy_m))
    return report


def warnings_multilens(r: dict) -> list[str]:
    w = []
    if not r["lenses"]:
        w.append("capture_info.json lists no lenses")
    for lens, s in r["lenses"].items():
        if s["frames"] < 2:
            w.append(f"{lens}: no frames recorded")
            continue
        if s["fps"] is not None and s["fps"] < 25:
            w.append(f"{lens}: only {s['fps']:.1f} fps")
        if s["missing_frames"] > 0.01 * s["frames"]:
            w.append(f"{lens}: {s['missing_frames']} frames missing (over 1%)")
        if s["intrinsics_rows"] < s["frames"]:
            w.append(f"{lens}: lens parameters missing on {s['frames'] - s['intrinsics_rows']} frames")
    for pair, ms in (r.get("lens_offsets_ms") or {}).items():
        if ms is not None and ms > 1.0:
            w.append(f"lenses {pair} are {ms:.1f} ms apart: not hardware-synchronised")
    if r.get("imu_rate_hz") is None or r["imu_rate_hz"] < 50:
        w.append("motion sensors missing or under 50 Hz: offline positions need them")
    if (r.get("max_thermal_state") or 0) >= 2:
        w.append(f"the phone reached '{THERMAL_NAMES[min(3, r['max_thermal_state'])]}' heat")
    if r.get("gps_fixes_used", 0) < 2:
        w.append("fewer than 2 usable GPS fixes")
    return w


def format_multilens(folder: Path, r: dict) -> str:
    lines = [f"Recording: {folder}", f"Mode:      multi-lens ({r['preset']})"]
    for lens, s in r["lenses"].items():
        fps = f"{s['fps']:.1f} fps" if s["fps"] else "fps n/a"
        lines.append(f"{(lens + ':'):<10} {s['frames']:,} frames over {s['duration_s']:.1f} s ({fps}); {s['gaps']} gaps, "
                     f"{s['missing_frames']} missing; lens parameters on {s['intrinsics_rows']:,}")
    offsets = ", ".join(f"{k} {v:.2f} ms" for k, v in (r.get("lens_offsets_ms") or {}).items() if v is not None)
    lines.append(f"Sync:      {offsets or 'n/a'}")
    rate = f" at {r['imu_rate_hz']:.0f} Hz" if r.get("imu_rate_hz") else ""
    lines.append(f"Motion:    {r['imu_samples']:,} samples{rate}")
    if r.get("max_thermal_state") is not None:
        lines.append(f"Heat:      worst state {THERMAL_NAMES[min(3, r['max_thermal_state'])]}")
    if "exposure_s_min_max" in r:
        lo, hi = r["exposure_s_min_max"]
        lines.append(f"Exposure:  1/{1 / hi:.0f} s to 1/{1 / lo:.0f} s")
    if r.get("gps_distance_m") is not None:
        speed = f", mean {r['gps_mean_speed_kmh']:.0f} km/h" if r.get("gps_mean_speed_kmh") is not None else ""
        lines.append(f"GPS:       {r['gps_fixes_used']} fixes; {r['gps_distance_m']:,.1f} m{speed}; start-to-end {r['gps_loop_error_m']:.1f} m")
    else:
        lines.append(f"GPS:       {r.get('gps_fixes_used', 0)} usable fixes")
    lines.append("Warnings:  " + ("none" if not r["warnings"] else ""))
    lines += [f"  - {w}" for w in r["warnings"]]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Check a RoadCapture recording (ARKit or multi-lens).")
    ap.add_argument("folder", type=Path, help="a recording folder copied off the phone")
    ap.add_argument("--json", action="store_true", help="print the report as JSON")
    ap.add_argument("--gps-max-accuracy", type=float, default=20.0, help="ignore GPS fixes worse than this many metres")
    args = ap.parse_args(argv)
    info: dict = {}
    try:
        info = json.loads((args.folder / "capture_info.json").read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    if info.get("mode") == "multi-lens":
        report = analyse_multilens(args.folder, info, gps_max_accuracy_m=args.gps_max_accuracy)
        report["warnings"] = warnings_multilens(report)
        text = format_multilens(args.folder, report)
    else:
        report = analyse(args.folder, gps_max_accuracy_m=args.gps_max_accuracy)
        report["warnings"] = warnings_for(report)
        text = format_report(args.folder, report)
    print(json.dumps(report, indent=2) if args.json else text)
    return 1 if report["warnings"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
