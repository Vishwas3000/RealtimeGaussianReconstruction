#!/usr/bin/env python3
"""Turn a RoadCapture ARKit recording into a drivestudio scene folder, with the phone's LiDAR as the LiDAR.

The folder copies the layout of drivestudio's processed nuScenes scenes, so drivestudio's nuScenes loaders read it
unchanged, as camera 0 (CAM_FRONT, 1600x900, 16:9 like the phone's 4K):
  images/{t:03d}_0.jpg      frames, resized to 1600x900
  extrinsics/{t:03d}_0.txt  camera-to-world 4x4 from ARKit, OpenCV camera axes (x right, y down, z forward)
  intrinsics/0.txt          fx fy cx cy k1 k2 p1 p2 k3 at 1600x900; ARKit gives no lens distortion
  lidar/{t:03d}.bin         float32 (N, 4): x y z 0, LiDAR depth pixels back-projected into the camera frame
  lidar_pose/{t:03d}.txt    the same camera-to-world: the phone's LiDAR looks out of its camera
  instances/                empty: the phone gives no boxes around other cars
  dynamic_masks/*/          empty masks of moving objects; drivestudio crashes without them, even with
                            load_dynamic_mask=False (datasets/base/pixel_source.py line 464), and skips empty ones
Sky masks come next, from recon/extract_sky_masks.py. Recording format: capture/ios/docs/format.md.

  python recon/arkit_to_drivestudio.py <recording> <data_root>/000 [--stride 3] [--min_confidence 2]
"""
import argparse
import csv
import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

OUT_W, OUT_H = 1600, 900  # drivestudio's nuScenes camera-0 size (datasets/dataset_meta.py)


def quat_to_rotmat(q):
    """(x, y, z, w) quaternion, the order odometry.csv stores, to a 3x3 rotation matrix."""
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


def depth_intrinsics(K, image_w, depth_w):
    """Scale image intrinsics (fx, fy, cx, cy) to the depth map, which has the same view at a lower resolution."""
    s = depth_w / image_w
    fx, fy, cx, cy = K
    return fx * s, fy * s, (cx + 0.5) * s - 0.5, (cy + 0.5) * s - 0.5


def backproject(depth_m, mask, Kd):
    """Depth pixels (metres along the optical axis) to points in the OpenCV camera frame, shape (N, 3)."""
    fx, fy, cx, cy = Kd
    v, u = np.nonzero(mask)
    z = depth_m[v, u]
    return np.stack([(u - cx) / fx * z, (v - cy) / fy * z, z], axis=1)


def lidar_agreement(points, poses, depths, confs, Kd, min_conf, gap):
    """Relative depth error when frame t's LiDAR points are re-projected into frame t+gap, for every gap-th frame.
    It checks poses, intrinsics and depth together; occluded points make a tail, so read the median."""
    fx, fy, cx, cy = Kd
    errs = []
    for a in range(0, len(poses) - gap, gap):
        b = a + gap
        rel = np.linalg.inv(poses[b]) @ poses[a]
        q = points[a] @ rel[:3, :3].T + rel[:3, 3]
        q = q[q[:, 2] > 0.1]
        u = np.round(q[:, 0] / q[:, 2] * fx + cx).astype(int)
        v = np.round(q[:, 1] / q[:, 2] * fy + cy).astype(int)
        h, w = depths[b].shape
        inside = (u >= 0) & (u < w) & (v >= 0) & (v < h)
        u, v, z = u[inside], v[inside], q[inside, 2]
        zb = depths[b][v, u]
        ok = (confs[b][v, u] >= min_conf) & (zb > 0)
        errs.append(np.abs(z[ok] - zb[ok]) / zb[ok])
    return np.concatenate(errs) if errs else np.zeros(0)


def read_csv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f, skipinitialspace=True))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("recording", type=Path, help="a RoadCapture ARKit-mode recording folder")
    ap.add_argument("out", type=Path, help="scene folder to create, e.g. <data_root>/000")
    ap.add_argument("--stride", type=int, default=3, help="keep every Nth frame (3: 30 fps -> 10 fps, like nuScenes)")
    ap.add_argument("--min_confidence", type=int, default=2, help="ARKit depth confidence to keep: 0 low, 1 medium, 2 high")
    a = ap.parse_args()
    rec, out = a.recording, a.out

    info = json.loads((rec / "capture_info.json").read_text())
    W, H = info["width"], info["height"]
    # shortcut: 16:9 only, so drivestudio's nuScenes camera size fits; 1440p60 (4:3) needs its own dataset entry.
    if W * OUT_H != H * OUT_W:
        raise SystemExit(f"{W}x{H} is not 16:9. Record in 4K30.")
    if not info.get("depth_enabled"):
        raise SystemExit("This recording has no LiDAR depth. Record with LiDAR on.")
    if out.exists():
        raise SystemExit(f"{out} exists. Delete it first.")

    odo, frames = read_csv(rec / "odometry.csv"), read_csv(rec / "frames.csv")
    n_video = int(subprocess.run(
        ["ffprobe", "-v", "error", "-count_packets", "-select_streams", "v:0", "-show_entries",
         "stream=nb_read_packets", "-of", "csv=p=0", str(rec / "rgb.mp4")],
        capture_output=True, text=True, check=True).stdout)
    if not len(odo) == len(frames) == n_video:
        raise SystemExit(f"Frame counts differ: rgb.mp4 {n_video}, odometry.csv {len(odo)}, frames.csv {len(frames)}.")
    if [r["frame"] for r in odo] != [r["frame"] for r in frames]:
        raise SystemExit("odometry.csv and frames.csv list different frames.")

    strided = range(0, n_video, a.stride)
    no_depth = [i for i in strided if frames[i]["has_depth"] != "1"]
    lost = [i for i in strided if frames[i]["tracking_state"] != "normal"]
    keep = [i for i in strided if i not in no_depth and i not in lost]
    if len(keep) < 2:
        raise SystemExit(f"Only {len(keep)} usable frames.")

    poses = []
    for i in keep:
        T = np.eye(4)
        T[:3, :3] = quat_to_rotmat([float(odo[i][k]) for k in ("qx", "qy", "qz", "qw")])
        T[:3, 3] = [float(odo[i][k]) for k in ("x", "y", "z")]
        poses.append(T)
    Ks = np.array([[float(odo[i][k]) for k in ("fx", "fy", "cx", "cy")] for i in keep])
    K = np.median(Ks, axis=0)
    k_spread = np.abs(Ks / K - 1).max()

    masks = ("dynamic_masks/all", "dynamic_masks/human", "dynamic_masks/vehicle")
    for d in ("images", "extrinsics", "intrinsics", "lidar", "lidar_pose", "instances") + masks:
        (out / d).mkdir(parents=True)
    s = OUT_W / W
    np.savetxt(out / "intrinsics" / "0.txt", [K[0] * s, K[1] * s, K[2] * s, K[3] * s, 0, 0, 0, 0, 0])

    # Frames: decode every stride-th frame, then number the kept ones 0..T-1.
    with tempfile.TemporaryDirectory(dir=out) as tmp:
        subprocess.run(
            ["ffmpeg", "-v", "error", "-noautorotate", "-i", str(rec / "rgb.mp4"),
             "-vf", f"select=not(mod(n\\,{a.stride})),scale={OUT_W}:{OUT_H}:flags=area",
             "-fps_mode", "passthrough", "-q:v", "2", "-start_number", "0", f"{tmp}/%06d.jpg"], check=True)
        if len(list(Path(tmp).glob("*.jpg"))) != len(strided):
            raise SystemExit(f"ffmpeg wrote {len(list(Path(tmp).glob('*.jpg')))} frames, expected {len(strided)}.")
        for t, i in enumerate(keep):
            Path(tmp, f"{i // a.stride:06d}.jpg").rename(out / "images" / f"{t:03d}_0.jpg")

    points, depths, confs = [], [], []
    for t, i in enumerate(keep):
        name = f"{frames[i]['frame']}.png"
        depth = np.asarray(Image.open(rec / "depth" / name)).astype(np.float64) / 1000.0  # millimetres
        conf = np.asarray(Image.open(rec / "confidence" / name))
        if depth.shape[1] * H != depth.shape[0] * W:
            raise SystemExit(f"Depth map {depth.shape[::-1]} does not match the {W}x{H} video.")
        Kd = depth_intrinsics(K, W, depth.shape[1])
        pts = backproject(depth, (conf >= a.min_confidence) & (depth > 0), Kd)
        np.hstack([pts, np.zeros((len(pts), 1))]).astype(np.float32).tofile(out / "lidar" / f"{t:03d}.bin")
        np.savetxt(out / "extrinsics" / f"{t:03d}_0.txt", poses[t])
        np.savetxt(out / "lidar_pose" / f"{t:03d}.txt", poses[t])
        points.append(pts), depths.append(depth), confs.append(conf)

    empty = Image.new("L", (OUT_W, OUT_H))
    for t in range(len(keep)):
        for d in masks:
            empty.save(out / d / f"{t:03d}_0.png")
    (out / "instances" / "instances_info.json").write_text("{}")
    (out / "instances" / "frame_instances.json").write_text(json.dumps({str(t): [] for t in range(len(keep))}))

    z = np.concatenate([p[:, 2] for p in points])
    path = sum(np.linalg.norm(p1[:3, 3] - p0[:3, 3]) for p0, p1 in zip(poses, poses[1:]))
    fps = info.get("saved_fps", 30) / a.stride
    gap = max(1, min(round(fps), len(keep) // 4))  # about 1 s apart
    err = lidar_agreement(points, poses, depths, confs, Kd, a.min_confidence, gap)
    print(f"frames: {len(keep)} kept of {len(strided)} at {fps:g} fps "
          f"({len(no_depth)} without depth, {len(lost)} with ARKit tracking not normal)")
    print(f"camera path: {path:.1f} m; intrinsics vary by up to {k_spread * 100:.2f}% between frames")
    print(f"LiDAR points kept (confidence >= {a.min_confidence}): {len(z) / len(keep):.0f} per frame, "
          f"{len(z) / (len(keep) * depths[0].size) * 100:.0f}% of depth pixels; "
          f"depth p50 {np.median(z):.1f} m, p95 {np.percentile(z, 95):.1f} m, max {z.max():.1f} m")
    if len(err):
        print(f"LiDAR re-projected {gap} frames ahead: median error {np.median(err) * 100:.1f}%, "
              f"{(err < 0.05).mean() * 100:.0f}% of {len(err)} points within 5%")
        if np.median(err) > 0.05:
            print("WARNING: frames disagree by more than 5%. Check ARKit tracking and the recording before training.")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
