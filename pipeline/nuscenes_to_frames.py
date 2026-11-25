"""Convert nuScenes ground truth + Occ3D labels + the map expansion into renderer replay files.

Output contract: pipeline/frame_schema.md.
Run from the repo root:  .venv/Scripts/python pipeline/nuscenes_to_frames.py [--scenes scene-0061 ...]
"""
import argparse
import base64
import json
import math
from pathlib import Path

import numpy as np
from nuscenes.map_expansion.map_api import NuScenesMap
from nuscenes.nuscenes import NuScenes
from pyquaternion import Quaternion
from shapely.geometry import LineString, Polygon, box as shapely_box
from shapely.ops import unary_union

REPO = Path(__file__).resolve().parents[1]
SCHEMA = "teslarender.scene/v0"

OCC_RANGE = (-40.0, -40.0, -1.0, 40.0, 40.0, 5.4)
OCC_VOXEL = 0.4
OCC_SHAPE = (200, 200, 16)
OCC_FREE = 17
OCC_CAR = 4
OCC_CLASSES = ["others", "barrier", "bicycle", "bus", "car", "construction_vehicle", "motorcycle",
               "pedestrian", "traffic_cone", "trailer", "truck", "driveable_surface", "other_flat",
               "sidewalk", "terrain", "manmade", "vegetation", "free"]

PATH_HORIZON_S = 6.0
MAP_MARGIN_M = 60.0


def rnd(v, nd=2):
    return round(float(v), nd)


def coarse_class(category):
    if category.startswith("human.pedestrian"):
        return "ped"
    if category.startswith("vehicle.bus"):
        return "bus"
    if category in ("vehicle.truck", "vehicle.construction", "vehicle.trailer"):
        return "truck"
    if category in ("vehicle.bicycle", "vehicle.motorcycle"):
        return "bike"
    if category.startswith("vehicle."):
        return "car"
    if category == "movable_object.trafficcone":
        return "cone"
    if category == "movable_object.barrier":
        return "barrier"
    return "other"


def pose_json(rec, origin):
    t = np.asarray(rec["translation"], dtype=float) - origin
    return {"t": [rnd(v) for v in t], "q": [rnd(v, 5) for v in rec["rotation"]]}


def camera_frames(nusc, scene):
    """CAM_FRONT sample_data from the first to the last keyframe of the scene (the 12 Hz perception clock)."""
    sd = nusc.get("sample_data", nusc.get("sample", scene["first_sample_token"])["data"]["CAM_FRONT"])
    frames = [sd]
    while sd["next"]:
        sd = nusc.get("sample_data", sd["next"])
        frames.append(sd)
        if sd["is_key_frame"] and sd["sample_token"] == scene["last_sample_token"]:
            break
    return frames


def frame_boxes(nusc, sd_token, origin, track_ids, tracks, vel_cache):
    out = []
    for b in nusc.get_boxes(sd_token):
        ann = nusc.get("sample_annotation", b.token)
        inst = ann["instance_token"]
        if inst not in track_ids:
            track_ids[inst] = len(track_ids)
            tracks[track_ids[inst]] = ann["category_name"]
        if b.token not in vel_cache:
            v = nusc.box_velocity(b.token)
            vel_cache[b.token] = None if np.isnan(v[:2]).any() else [rnd(v[0]), rnd(v[1])]
        c = np.asarray(b.center) - origin
        w, l, h = b.wlh
        out.append({"id": track_ids[inst], "cls": coarse_class(ann["category_name"]),
                    "c": [rnd(c[0]), rnd(c[1]), rnd(c[2])], "s": [rnd(w), rnd(l), rnd(h)],
                    "yaw": rnd(b.orientation.yaw_pitch_roll[0], 4), "v": vel_cache[b.token]})
    return out


def future_path(i, times, ego_xy, origin):
    pts = []
    for j in range(i, len(times)):
        if times[j] - times[i] > PATH_HORIZON_S:
            break
        if (j - i) % 3 == 0:
            pts.append([rnd(ego_xy[j][0] - origin[0]), rnd(ego_xy[j][1] - origin[1])])
    return pts


def voxel_centers(flat_idx):
    i, rem = np.divmod(flat_idx, OCC_SHAPE[1] * OCC_SHAPE[2])
    j, k = np.divmod(rem, OCC_SHAPE[2])
    return np.stack([OCC_RANGE[0] + (i + 0.5) * OCC_VOXEL,
                     OCC_RANGE[1] + (j + 0.5) * OCC_VOXEL,
                     OCC_RANGE[2] + (k + 0.5) * OCC_VOXEL], axis=1)


def inside_any_box(points, boxes, margin=0.3):
    inside = np.zeros(len(points), dtype=bool)
    for b in boxes:
        d = points - b.center
        yaw = b.orientation.yaw_pitch_roll[0]
        c, s = math.cos(yaw), math.sin(yaw)
        lx = c * d[:, 0] + s * d[:, 1]
        ly = -s * d[:, 0] + c * d[:, 1]
        w, l, h = b.wlh
        inside |= (np.abs(lx) <= l / 2 + margin) & (np.abs(ly) <= w / 2 + margin) & (np.abs(d[:, 2]) <= h / 2 + margin)
    return inside


def check_occ_axes(nusc, occ):
    """Fraction of Occ3D 'car' voxels that fall inside a ground-truth car box, for (i,j)->(x,y) and for (i,j)->(y,x)."""
    hits = {"xy": 0, "yx": 0}
    total = 0
    for sem, _cam, ego, lidar_sd_token in occ.values():
        flat = np.flatnonzero(sem == OCC_CAR)
        if len(flat) == 0:
            continue
        t = np.asarray(ego["translation"])
        q_inv = Quaternion(ego["rotation"]).inverse
        cars = []
        for b in nusc.get_boxes(lidar_sd_token):
            if b.name == "vehicle.car":
                b.translate(-t)
                b.rotate(q_inv)
                cars.append(b)
        if not cars:
            continue
        pts = voxel_centers(flat)
        hits["xy"] += int(inside_any_box(pts, cars).sum())
        hits["yx"] += int(inside_any_box(pts[:, [1, 0, 2]], cars).sum())
        total += len(flat)
    if total == 0:
        return False, "no car voxels to check"
    fx, fy = hits["xy"] / total, hits["yx"] / total
    swap = fy > fx
    verdict = "OK" if max(fx, fy) >= 0.5 else "WARNING: low agreement, check occupancy placement"
    return swap, f"car voxels inside car boxes: i->x {fx:.1%}, i->y {fy:.1%} ({total} voxels) -> using {'i->y (swapped)' if swap else 'i->x'} [{verdict}]"


def pack_occ(sem, cam):
    flat = np.flatnonzero(sem != OCC_FREE)
    cls = sem.reshape(-1)[flat].astype(np.uint32)
    vis = (cam.reshape(-1)[flat] > 0).astype(np.uint32)
    packed = (flat.astype(np.uint32) << 6) | (vis << 5) | cls
    return len(flat), base64.b64encode(packed.astype("<u4").tobytes()).decode("ascii")


def flatten(geom, kind):
    if geom.is_empty:
        return []
    if isinstance(geom, kind):
        return [geom]
    out = []
    for g in getattr(geom, "geoms", []):
        out += flatten(g, kind)
    return out


def xy(coords, origin):
    return [[rnd(c[0] - origin[0]), rnd(c[1] - origin[1])] for c in coords]


def line_coords(geom, origin):
    return [xy(g.simplify(0.05).coords, origin) for g in flatten(geom, LineString) if len(g.coords) >= 2]


def polygon_coords(geom, origin):
    out = []
    for p in flatten(geom, Polygon):
        for q in flatten(p.simplify(0.05), Polygon):
            out.append({"outer": xy(q.exterior.coords, origin), "holes": [xy(h.coords, origin) for h in q.interiors]})
    return out


def export_map(nusc_map, ego_xy, origin):
    x0, y0 = ego_xy.min(axis=0) - MAP_MARGIN_M
    x1, y1 = ego_xy.max(axis=0) + MAP_MARGIN_M
    patch = shapely_box(x0, y0, x1, y1)
    recs = nusc_map.get_records_in_patch((x0, y0, x1, y1), ["drivable_area", "lane_divider", "road_divider"])
    polys = []
    for tok in recs["drivable_area"]:
        for ptok in nusc_map.get("drivable_area", tok)["polygon_tokens"]:
            p = nusc_map.extract_polygon(ptok)
            p = p if p.is_valid else p.buffer(0)
            if p.intersects(patch):
                polys.append(p)
    area = unary_union(polys) if polys else Polygon()

    def lines(layer):
        out = []
        for tok in recs[layer]:
            line = nusc_map.extract_line(nusc_map.get(layer, tok)["line_token"])
            out += line_coords(line.intersection(patch), origin)
        return out

    return {"drivable": polygon_coords(area.intersection(patch), origin),
            "road_edges": line_coords(area.boundary.intersection(patch), origin),
            "lane_dividers": lines("lane_divider"),
            "road_dividers": lines("road_divider")}


def convert_scene(nusc, scene, occ_root, maps, out_dir):
    name = scene["name"]
    location = nusc.get("log", scene["log_token"])["location"]
    cams = camera_frames(nusc, scene)
    egos = [nusc.get("ego_pose", sd["ego_pose_token"]) for sd in cams]
    origin = np.asarray(egos[0]["translation"], dtype=float)
    times = [(sd["timestamp"] - cams[0]["timestamp"]) / 1e6 for sd in cams]
    ego_xy = np.array([e["translation"][:2] for e in egos])

    occ = {}
    for sd in cams:
        if not sd["is_key_frame"]:
            continue
        sample = nusc.get("sample", sd["sample_token"])
        f = occ_root / name / sample["token"] / "labels.npz"
        if not f.exists():
            continue
        d = np.load(f)
        lidar_sd = nusc.get("sample_data", sample["data"]["LIDAR_TOP"])
        occ[sample["token"]] = (d["semantics"], d["mask_camera"], nusc.get("ego_pose", lidar_sd["ego_pose_token"]), lidar_sd["token"])
    swap, occ_report = check_occ_axes(nusc, occ) if occ else (False, "no occupancy labels found")

    track_ids, tracks, vel_cache = {}, {}, {}
    frames, n_boxes, n_vox = [], [], []
    for i, sd in enumerate(cams):
        boxes = frame_boxes(nusc, sd["token"], origin, track_ids, tracks, vel_cache)
        n_boxes.append(len(boxes))
        frame_occ = None
        if sd["is_key_frame"] and sd["sample_token"] in occ:
            sem, cam, ego, _ = occ[sd["sample_token"]]
            if swap:
                sem, cam = sem.swapaxes(0, 1), cam.swapaxes(0, 1)
            n, packed = pack_occ(np.ascontiguousarray(sem), np.ascontiguousarray(cam))
            n_vox.append(n)
            frame_occ = {"ego_pose": pose_json(ego, origin), "n": n, "packed": packed}
        frames.append({"t": rnd(times[i], 3), "key": bool(sd["is_key_frame"]), "ego_pose": pose_json(egos[i], origin),
                       "boxes": boxes, "lanes": None, "path": future_path(i, times, ego_xy, origin), "occ": frame_occ})

    if location not in maps:
        maps[location] = NuScenesMap(dataroot=str(nusc.dataroot), map_name=location)
    scene_map = export_map(maps[location], ego_xy, origin)

    doc = {"schema": SCHEMA, "scene": name, "description": scene["description"], "location": location,
           "origin": [rnd(v, 3) for v in origin], "duration": rnd(times[-1], 3),
           "occ_grid": {"range": OCC_RANGE, "voxel": OCC_VOXEL, "shape": OCC_SHAPE, "classes": OCC_CLASSES},
           "tracks": tracks, "map": scene_map, "frames": frames}
    out_file = out_dir / f"{name}.json"
    out_file.write_text(json.dumps(doc, separators=(",", ":")), encoding="utf-8")

    print(f"{name} ({location}): {len(frames)} frames over {times[-1]:.1f} s "
          f"({len(frames) / times[-1]:.1f} Hz), {len(tracks)} tracks, {np.mean(n_boxes):.0f} boxes/frame")
    if n_vox:
        print(f"  occupancy: {len(n_vox)} keyframes, {np.mean(n_vox):.0f} occupied voxels each "
              f"({np.mean(n_vox) / np.prod(OCC_SHAPE):.1%} of the grid)")
    print(f"  {occ_report}")
    print(f"  map: {len(scene_map['drivable'])} drivable polygons, {len(scene_map['road_edges'])} road edges, "
          f"{len(scene_map['lane_dividers'])} lane dividers, {len(scene_map['road_dividers'])} road dividers")
    print(f"  wrote {out_file.relative_to(REPO)} ({out_file.stat().st_size / 1e6:.1f} MB)")
    return {"scene": name, "file": out_file.name, "description": scene["description"], "location": location,
            "frames": len(frames), "duration": rnd(times[-1], 2)}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dataroot", type=Path, default=REPO / "Dataset" / "nuscenes")
    ap.add_argument("--version", default="v1.0-mini")
    ap.add_argument("--occ-root", type=Path, default=REPO / "Dataset" / "occ3d" / "gts")
    ap.add_argument("--out", type=Path, default=REPO / "renderer" / "public" / "data")
    ap.add_argument("--scenes", nargs="*", help="scene names (default: all in the split)")
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    nusc = NuScenes(version=args.version, dataroot=str(args.dataroot), verbose=False)
    scenes = [s for s in nusc.scene if not args.scenes or s["name"] in args.scenes]
    missing = set(args.scenes or []) - {s["name"] for s in scenes}
    if missing:
        raise SystemExit(f"unknown scenes: {sorted(missing)}")

    index_file = args.out / "index.json"
    index = {e["scene"]: e for e in json.loads(index_file.read_text())} if index_file.exists() else {}
    maps = {}
    for scene in scenes:
        index[scene["name"]] = convert_scene(nusc, scene, args.occ_root, maps, args.out)
    index_file.write_text(json.dumps(sorted(index.values(), key=lambda e: e["scene"]), indent=1), encoding="utf-8")
    print(f"index: {len(index)} scenes in {index_file.relative_to(REPO)}")


if __name__ == "__main__":
    main()
