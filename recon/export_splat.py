"""Export a drivestudio checkpoint as a .splat file for web viewers (SuperSplat, antimatter15's splat viewer).

  python recon/export_splat.py <run>/checkpoint_final.pth <out>.splat [--frame 0] [--max_distance 250]

What goes in: the static background, plus the cars posed as they were at --frame. Left out: people and other
deformable things (their shape needs drivestudio's deformation network) and the sky (a cube-map texture, not splats).
The format keeps one colour per splat, so view-dependent colour (spherical harmonics) is dropped.

Axes: drivestudio's world is the first front camera's OpenCV frame (x right, y down, z forward). The file is rotated
180° about x to y-up (x right, y up, z backward), so the street appears upright in SuperSplat.

.splat (antimatter15) is 32 bytes per splat: position xyz float32, scale xyz float32, RGBA uint8, rotation wxyz uint8
as q*128+128. Splats are sorted biggest and most opaque first, as antimatter15's converter does, so viewers that
stream the file draw the important ones first.
"""
import argparse
from pathlib import Path

import numpy as np

SH_C0 = 0.28209479177387814  # degree-0 spherical-harmonic constant
SPLAT = np.dtype([("pos", "<f4", 3), ("scale", "<f4", 3), ("rgba", "u1", 4), ("rot", "u1", 4)])
FLIP = np.diag([1.0, -1.0, -1.0])  # 180° about x: OpenCV camera axes -> y-up
FLIP_Q = np.array([0.0, 1.0, 0.0, 0.0])  # the same rotation as a (w, x, y, z) quaternion


def quat_mult(q1, q2):
    """Hamilton product of (w, x, y, z) quaternions, as in drivestudio's models/gaussians/basics.py."""
    w1, x1, y1, z1 = np.moveaxis(q1, -1, 0)
    w2, x2, y2, z2 = np.moveaxis(q2, -1, 0)
    return np.stack([w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
                     w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
                     w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2], axis=-1)


def quat_to_rotmat(q):
    w, x, y, z = np.moveaxis(q / np.linalg.norm(q, axis=-1, keepdims=True), -1, 0)
    return np.stack([1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y),
                     2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x),
                     2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)],
                    axis=-1).reshape(np.shape(q)[:-1] + (3, 3))


def scene_splats(models, frame):
    """Background plus the cars at `frame`, in drivestudio's world: means, log scales, quats, SH DC, opacity logits."""
    keys = ("_means", "_scales", "_quats", "_features_dc", "_opacities")
    bg = models["Background"]
    parts = [[np.asarray(bg[k]) for k in keys]]
    cars = models.get("RigidNodes")
    if cars is not None:
        ids = np.asarray(cars["points_ids"])[:, 0]
        seen = np.asarray(cars["instances_fv"])[frame][ids]  # drivestudio hides cars that aren't in this frame
        q_car = np.asarray(cars["instances_quats"])[frame][ids][seen]
        t_car = np.asarray(cars["instances_trans"])[frame][ids][seen]
        means, log_scales, quats, sh_dc, opacity = (np.asarray(cars[k])[seen] for k in keys)
        means = np.einsum("nij,nj->ni", quat_to_rotmat(q_car), means) + t_car
        quats = quat_mult(q_car / np.linalg.norm(q_car, axis=1, keepdims=True), quats)
        parts.append([means, log_scales, quats, sh_dc, opacity])
    return [np.concatenate(p) for p in zip(*parts)]


def to_records(means, log_scales, quats, sh_dc, opacity_logits):
    """Splat parameters as .splat records, biggest and most opaque first."""
    scales = np.exp(log_scales)
    opacity = 1 / (1 + np.exp(-opacity_logits))
    rgb = np.clip(0.5 + SH_C0 * sh_dc, 0, 1)
    q = quats / np.linalg.norm(quats, axis=1, keepdims=True)
    rec = np.empty(len(means), SPLAT)
    rec["pos"] = means
    rec["scale"] = scales
    rec["rgba"] = np.round(np.column_stack([rgb, opacity]) * 255).astype(np.uint8)
    rec["rot"] = np.clip(np.round(q * 128 + 128), 0, 255).astype(np.uint8)
    return rec[np.argsort(-(scales.prod(axis=1) * opacity), kind="stable")]


def from_records(rec):
    """Decode .splat records: means, scales, unit quats, rgb and opacity in 0..1."""
    q = (rec["rot"].astype(np.float64) - 128) / 128
    rgba = rec["rgba"] / 255.0
    return rec["pos"], rec["scale"], q / np.linalg.norm(q, axis=1, keepdims=True), rgba[:, :3], rgba[:, 3]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("checkpoint", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--frame", type=int, default=0, help="frame whose car positions to use (default: the first)")
    ap.add_argument("--max_distance", type=float, default=250,
                    help="drop splats farther than this from the first camera, in metres; a few strays sit km away, "
                         "and viewers zoom out to fit them")
    args = ap.parse_args()

    import torch  # only needed to read the checkpoint, so the functions above can be tested without it

    models = torch.load(args.checkpoint, map_location="cpu", weights_only=False)["models"]
    means, log_scales, quats, sh_dc, opacity = scene_splats(models, args.frame)
    near = np.linalg.norm(means, axis=1) <= args.max_distance
    rec = to_records(means[near] @ FLIP.T, log_scales[near], quat_mult(FLIP_Q, quats[near]), sh_dc[near],
                     opacity[near, 0])
    args.out.write_bytes(rec.tobytes())
    print(f"{len(rec):,} splats, {(~near).sum():,} beyond {args.max_distance:g} m dropped; "
          f"{args.out.stat().st_size / 1e6:.1f} MB -> {args.out}")


if __name__ == "__main__":
    main()
