#!/usr/bin/env python3
"""Turn a RoadCapture ARKit recording into a drivestudio scene folder, with the phone's LiDAR as the LiDAR.

The folder copies the layout of drivestudio's processed nuScenes scenes, so drivestudio's nuScenes loaders read it
unchanged, as camera 0 (CAM_FRONT, 1600x900):
  images/{t:03d}_0.jpg      frames at 1600x900 (a 4:3 1440p60 recording is squeezed to fit), each redrawn for the
                            one camera in intrinsics/0.txt, because ARKit's focal length moves with autofocus
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


def scale_intrinsics(K, sx, sy):
    """Intrinsics (fx, fy, cx, cy) of the same view resampled by sx across and sy down; pixel centres at integers."""
    fx, fy, cx, cy = K
    return fx * sx, fy * sy, (cx + 0.5) * sx - 0.5, (cy + 0.5) * sy - 0.5


def shared_intrinsics(Ks, w, h):
    """One camera every frame can be redrawn for without running off its edges: the median, zoomed in just enough
    for the frame that saw the least. Ks: (N, 4) per-frame fx, fy, cx, cy of w x h images."""
    med = np.median(Ks, axis=0)
    edge = np.array([w, h]) - 0.5
    room = np.minimum((Ks[:, 2:] + 0.5) / (med[2:] + 0.5), (edge - Ks[:, 2:]) / (edge - med[2:]))
    zoom = max(1.0, (Ks[:, :2] / med[:2] / room).max())
    return np.array([med[0] * zoom, med[1] * zoom, med[2], med[3]])


def resample_coeffs(K_frame, K_out):
    """Pillow AFFINE coefficients that redraw a frame taken with K_frame as if taken with K_out.
    Pillow puts pixel centres at +0.5; these intrinsics put them at integers."""
    ax, ay = K_frame[0] / K_out[0], K_frame[1] / K_out[1]
    bx, by = K_frame[2] - ax * K_out[2], K_frame[3] - ay * K_out[3]
    return ax, 0.0, bx + 0.5 - 0.5 * ax, 0.0, ay, by + 0.5 - 0.5 * ay


def backproject(depth_m, mask, Kd):
    """Depth pixels (metres along the optical axis) to points in the OpenCV camera frame, shape (N, 3)."""
    fx, fy, cx, cy = Kd
    v, u = np.nonzero(mask)
    z = depth_m[v, u]
    return np.stack([(u - cx) / fx * z, (v - cy) / fy * z, z], axis=1)


def lidar_agreement(points, poses, depths, confs, Kds, min_conf, gap):
    """Relative depth error when frame t's LiDAR points are re-projected into frame t+gap, for every gap-th frame.
    Kds: each frame's depth-map intrinsics. It checks poses, intrinsics and depth together; occluded points make a
    tail, so read the median."""
    errs = []
    for a in range(0, len(poses) - gap, gap):
        b = a + gap
        fx, fy, cx, cy = Kds[b]
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
    K_img = np.array([scale_intrinsics(k, OUT_W / W, OUT_H / H) for k in Ks])  # 4:3 is squeezed: x, y scale apart
    K_out = shared_intrinsics(K_img, OUT_W, OUT_H)
    focus_spread = np.abs(Ks[:, 0] / np.median(Ks[:, 0]) - 1).max()

    masks = ("dynamic_masks/all", "dynamic_masks/human", "dynamic_masks/vehicle")
    for d in ("images", "extrinsics", "intrinsics", "lidar", "lidar_pose", "instances") + masks:
        (out / d).mkdir(parents=True)
    np.savetxt(out / "intrinsics" / "0.txt", [*K_out, 0, 0, 0, 0, 0])

    # Frames: decode every stride-th frame, then redraw the kept ones for K_out, numbered 0..T-1.
    with tempfile.TemporaryDirectory(dir=out) as tmp:
        subprocess.run(
            ["ffmpeg", "-v", "error", "-noautorotate", "-i", str(rec / "rgb.mp4"),
             "-vf", f"select=not(mod(n\\,{a.stride})),scale={OUT_W}:{OUT_H}:flags=area",
             "-fps_mode", "passthrough", "-start_number", "0", f"{tmp}/%06d.png"], check=True)
        n_png = len(list(Path(tmp).glob("*.png")))
        if n_png != len(strided):
            raise SystemExit(f"ffmpeg wrote {n_png} frames, expected {len(strided)}.")
        for t, i in enumerate(keep):
            with Image.open(Path(tmp, f"{i // a.stride:06d}.png")) as im:
                im.convert("RGB").transform((OUT_W, OUT_H), Image.Transform.AFFINE, resample_coeffs(K_img[t], K_out),
                                            Image.Resampling.BICUBIC).save(out / "images" / f"{t:03d}_0.jpg", quality=95)

    points, depths, confs, Kds = [], [], [], []
    for t, i in enumerate(keep):
        name = f"{frames[i]['frame']}.png"
        depth = np.asarray(Image.open(rec / "depth" / name)).astype(np.float64) / 1000.0  # millimetres
        conf = np.asarray(Image.open(rec / "confidence" / name))
        if depth.shape[1] * H != depth.shape[0] * W:
            raise SystemExit(f"Depth map {depth.shape[::-1]} does not match the {W}x{H} video.")
        Kd = scale_intrinsics(Ks[t], depth.shape[1] / W, depth.shape[0] / H)  # this frame's own focal length
        pts = backproject(depth, (conf >= a.min_confidence) & (depth > 0), Kd)
        np.hstack([pts, np.zeros((len(pts), 1))]).astype(np.float32).tofile(out / "lidar" / f"{t:03d}.bin")
        np.savetxt(out / "extrinsics" / f"{t:03d}_0.txt", poses[t])
        np.savetxt(out / "lidar_pose" / f"{t:03d}.txt", poses[t])
        points.append(pts), depths.append(depth), confs.append(conf), Kds.append(Kd)

    empty = Image.new("L", (OUT_W, OUT_H))
    for t in range(len(keep)):
        for d in masks:
            empty.save(out / d / f"{t:03d}_0.png")
    (out / "instances" / "instances_info.json").write_text("{}")
    (out / "instances" / "frame_instances.json").write_text(json.dumps({str(t): [] for t in range(len(keep))}))

    z = np.concatenate([p[:, 2] for p in points])
    path = sum(np.linalg.norm(p1[:3, 3] - p0[:3, 3]) for p0, p1 in zip(poses, poses[1:]))
    ts = [float(r["timestamp"]) for r in odo]
    fps = (len(ts) - 1) / (ts[-1] - ts[0]) / a.stride  # measured: "60 fps" with LiDAR on delivers about 30
    gap = max(1, min(round(fps), len(keep) // 4))  # about 1 s apart
    err = lidar_agreement(points, poses, depths, confs, Kds, a.min_confidence, gap)
    print(f"frames: {len(keep)} kept of {len(strided)} at {fps:.1f} fps "
          f"({len(no_depth)} without depth, {len(lost)} with ARKit tracking not normal)")
    print(f"camera path: {path:.1f} m; focal length varies by up to {focus_spread * 100:.2f}% between frames; "
          f"frames redrawn for one camera, zoomed in {(K_out[0] / np.median(K_img[:, 0]) - 1) * 100:.1f}%")
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
