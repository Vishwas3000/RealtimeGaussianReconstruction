# Replay file contract (`teslarender.scene/v0`)

The one interface between "something that understands the world" (ground truth now, perception models later) and the
renderer (D-005). One JSON file per scene, written to `renderer/public/data/<scene>.json`, plus
`renderer/public/data/index.json` listing the scenes.

## Coordinates

- **World frame** = nuScenes global frame minus `origin` (the first ego position of the scene), metres, z up.
  Subtracting the origin keeps numbers small for the GPU.
- Every position in a frame is in the world frame, **except** occupancy, which is a grid in the ego frame of its own
  `occ.ego_pose` (that is how Occ3D defines it).
- Quaternions are `[w, x, y, z]` (nuScenes order).
- Perception models output ego-frame results; their writer must move them into the world frame with `ego_pose`
  before writing, so the renderer never needs to know where a frame came from.

## Scene header

| Field | Meaning |
|---|---|
| `schema` | `"teslarender.scene/v0"` |
| `scene`, `description`, `location` | nuScenes scene name, its description, map name |
| `origin` | `[x, y, z]` global position subtracted from everything |
| `duration` | seconds from first to last frame |
| `occ_grid` | grid definition and class names (see Occupancy) |
| `tracks` | `{track_id: nuScenes category}` for every track in the scene |
| `map` | static map near the drive: `drivable` polygons `{outer, holes}`, and `lane_dividers`, `road_dividers`, `road_edges` polylines, all `[[x, y], ...]` |
| `frames` | list of frames, ascending `t` |

## Frame

| Field | Meaning |
|---|---|
| `t` | seconds since the first frame |
| `key` | true on annotated 2 Hz keyframes |
| `ego_pose` | `{t: [x, y, z], q: [w, x, y, z]}`, rear-axle centre of the ego car |
| `boxes` | `[{id, cls, c: [x, y, z], s: [w, l, h], yaw, v: [vx, vy] or null}]`; `id` is stable for a track's whole life; `cls` is one of `car truck bus bike ped cone barrier other`; `c` is the box centre |
| `lanes` | `null` for ground truth (the map is static and lives in the header); per-frame polylines from a lane model later |
| `path` | the planned path as `[[x, y], ...]`; for ground truth it is the ego's real next 6 s |
| `occ` | `null`, or on keyframes `{ego_pose, n, packed}` (see below). The renderer keeps the latest one until the next arrives |

Frames come at the camera rate (12 Hz, the `CAM_FRONT` clock). Ground-truth boxes between 2 Hz keyframes are the
devkit's linear interpolation, so replay exercises the same 12 Hz → 60 fps path a live model would.

## Occupancy

Occ3D-nuScenes: 200 × 200 × 16 voxels of 0.4 m covering x, y ∈ [−40, 40] m and z ∈ [−1, 5.4] m in the ego frame.
Classes 0–16 follow nuScenes-lidarseg (`occ_grid.classes`); 17 = free and is never written.

`packed` is base64 of little-endian `uint32` values, one per occupied voxel:
`(flat_idx << 6) | (camera_visible << 5) | class`, where `flat_idx = (i * 200 + j) * 16 + k` and voxel `(i, j, k)` has
its centre at `(−40 + 0.4 (i + 0.5), −40 + 0.4 (j + 0.5), −1 + 0.4 (k + 0.5))`. `camera_visible` is Occ3D's
`mask_camera`. The converter checks the axis order against the boxes before writing (see its output).
