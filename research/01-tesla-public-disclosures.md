# 01 — What Tesla has publicly disclosed about FSD perception and rendering

Researched 2026-11-24. Scope: what Tesla people said on stage or wrote down, kept apart from fan lore, with
a pointer to the nearest open work for each piece (other notes in `research/` go deep on BEV/occupancy,
maps/end-to-end, world models and the renderer).

**Trust tags.** `[primary]` = read at source: YouTube auto-transcript of the official video (timestamps are
from that transcript), the author's own X post (fetched via the fxtwitter API mirror), patent text on Google
Patents, or a repo/paper verified via API. `[secondary]` = a search snippet, a news write-up, or Tesla
release-note text read through a third-party mirror (notateslaapp.com). `[UNCERTAIN]` = could not confirm.
Transcripts are auto-captions, so some words are garbled (e.g. "Abit RGB" = 8-bit RGB).

## TL;DR

- **2021–2022 is the only period with architecture-level disclosure.** AI Day 2021 gave the full pipeline:
  rectify to a virtual camera → RegNet + BiFPN → transformer into "vector space" → time- and space-based
  feature queue → spatial RNN → HydraNet heads. AI Day 2022 and CVPR 2022 added the Occupancy Network and the
  autoregressive "language of lanes". Everything after v12 (2023-11) is described at the level of goals,
  not architecture. `[primary]`
- **The in-car display renders the network's explicit outputs, but not all of them.** Karpathy: the vector
  space is "rendered in the instrument cluster" (AI Day 2021, 0:49:56). Both 2022 talks say the Occupancy
  Network was **not** shown in the customer-facing visualization. It first appeared on screen as
  High-Fidelity Park Assist (Dec 2023): "a continuous distance field … not some fixed meshes". `[primary]`
- **The renderer is reportedly Godot, with Unreal coming.** That comes from a firmware teardown by
  greentheonly (Aug 2025), not from Tesla. Unreal binaries ship in 2025.20+ on AMD Model S/X only, and are
  not active. As of 2026-11-24 I found no source saying the Unreal version has shipped.
  `[secondary]`/`[UNCERTAIN]`
- **The world model and neural simulator are real and on the record, but no architecture is given.** CVPR 2023
  showed generated video for all 8 cameras, conditioned on actions. ICCV 2025 (Ashok's own write-up)
  described a closed-loop neural world simulator that is "causal" and has run in real time: 8 cameras at
  24 fps for 6+ minutes. "Generative Gaussian Splatting" was given as about 220 ms with no initialization,
  handling dynamic objects. No paper, code or patent exists for either. `[primary]` for the claims; the
  details are undisclosed.
- **Patents add rendering detail the talks never gave.** WO2025193615A1 describes the high-fidelity
  occupancy network as predicting **signed distances per voxel**. Its "rendering protocol" stacks 2D SDF
  slices (for example 1-inch layers) or ray-casts the SDF. That is the most concrete public hint at how the
  parking 3D view is drawn. A patent shows a possible embodiment, not proof of what ships. `[primary]`

## Timeline

| Date | Event | What was disclosed (relevant to a renderer builder) | Source | Trust |
|---|---|---|---|---|
| 2021-08-19 | AI Day 2021 (Karpathy et al.) | Input is 1280×960 12-bit at ~36 Hz (0:51:55). RegNets (0:52:14) and BiFPN feed a transformer that uses output-space raster queries with positional encodings against image keys and values; "a single block" can do much of the work (1:00:13). Images are rectified into a "synthetic virtual camera" (1:01:59). A feature queue pushes on time (~27 ms) and on distance travelled, with kinematics fed in (1:04:23–1:06:52). The spatial RNN's hidden state is a 2D lattice around the car, updated where visible (1:07:11). Full pipeline recap at 1:11:20. The vector space is "rendered in the instrument cluster" (0:49:56). Auto-labelling moved to labelling "directly in vector space" on reconstructions (1:26:57). Simulation: ray tracing and procedural roads; "working on neural rendering" (1:37:54–1:39:49) | https://www.youtube.com/watch?v=j0z4FweCy4M | [primary] |
| 2022-06 | CVPR 2022 WAD keynote, Ashok Elluswamy | Occupancy Networks: "not shown in the visualization" (0:03:17). Runs "within 10 milliseconds", i.e. 100 Hz (0:09:25). Backbone is RegNets + BiFPN after normalizing intrinsics and distortion (0:09:57). 3D positional-encoding queries attend to image features, then are upsampled with deconvs (0:10:44). Cites Mescheder's Occupancy Networks. Occupancy flow is the first derivative over time (0:15:37). NeRF / Plenoxels reconstructions from fleet trips (0:20:23). Differentiable-rendering supervision of occupancy and flow on held-out views (0:23:01). Collision-avoidance implicit MLP queried by vehicle state (0:28:10) | https://www.youtube.com/watch?v=jPCV4GKX9Dw | [primary] |
| 2022-08 | FSD Beta 10.69 notes (2022.16.3.10) | "Upgraded Occupancy Network to use video instead of images from single time step … enables prediction of occupancy flow". "Deep lane guidance" fuses video features with coarse map data | https://www.notateslaapp.com/software-updates/version/2022.16.3.10/release-notes | [secondary] |
| 2022-09-30 | AI Day 2022 | Occupancy: 8 cameras give a volumetric occupancy with semantics (curb, car, pedestrian, debris) plus occupancy flow; "currently not shown in our customer-facing visualization" (1:12:23). Uses 12-bit raw photon counts, no ISP (1:13:58). Pipeline is 3D position queries → attention → odometry-aligned temporal features → deconv voxels, plus a per-voxel MLP queried at any point (1:14:25–1:15:15). Predicts a drivable surface aligned with the voxels (1:16:12). Ashok on NeRF as the "foundation model for vision" (1:17:18). Lanes: video encoder + "lane guidance module" (coarse non-HD map), then captioning-style autoregressive "language of lanes" tokens (1:27:04–1:30:12). Multi-trip reconstruction auto-labeller (1:42:08). Sim world creator: Houdini, tiles exported "for consumption by the Unreal Engine" (1:48:39, 1:52:15). Dojo | https://www.youtube.com/watch?v=ODSJsviD_SU | [primary] |
| 2023-06 | CVPR 2023 WAD keynote, Ashok | "Foundation model for autonomy": occupancy, lanes as tokens. "Purely generated video sequences" for **all 8 cameras jointly**, consistent across cameras with no 3D priors (0:14:12). Action-conditioned: keep lane vs change lane from the same past (0:15:12). "Neural network simulator" (0:16:07). Q&A asks whether it is VQ-GAN + AR: "work in progress … don't fixate on the current architecture" (0:21:03) | https://www.youtube.com/watch?v=6x-Xb_uT7ts | [primary] |
| 2023-11/12 | FSD v12 notes (2023.44.30.10) | "single end-to-end neural network trained on millions of video clips, replacing over 300k lines of explicit C++ code" (city streets) | https://www.notateslaapp.com/software-updates/version/2023.44.30.10/release-notes | [secondary] |
| 2023-12-17 | High-Fidelity Park Assist, Ashok X thread | "replaces the 2D obstacle band … with a high-resolution 3D reconstruction … an extension of our Occupancy Network". "Obstacles are modeled as a continuous distance field … not some fixed meshes, but the network's real-time prediction of the shape". Also predicts painted ground lines in 3D | https://x.com/aelluswamy/status/1736187617207787922 (+ …618944266449, …620676526153) | [primary] |
| 2024-12 → 2025 | FSD v13 notes (HW4) | "upgrades every part of the end-to-end driving network"; "36 Hz, full-resolution AI4 video inputs"; "Native AI4 inputs and neural network architectures" | https://notateslaapp.com/software-updates/version/2025.14.6/release-notes | [secondary] |
| 2025-08-08 | greentheonly firmware teardown | "the [AP viz] you see today is godot-based"; "unreal-engine based AP viz … binaries are already shipping starting from firmware 2025.20 only on amd-based s and x cars" | https://x.com/greentheonly/status/1953882658284392579 | [primary] for what he said; [secondary] as fact (not Tesla) |
| 2025-08 | Dojo shut down | Musk called Dojo 2 "an evolutionary dead end"; focus moved to AI5/AI6 | https://techcrunch.com/2025/08/11/elon-musk-confirms-shutdown-of-tesla-dojo-an-evolutionary-dead-end | [secondary] |
| 2025-10-07 | FSD v14 notes | "Added navigation and routing into the vision-based neural network"; settings adjustable "from the Autopilot visualization" | https://electrek.co/2025/10/07/tesla-fsd-v14-release-notes/ | [secondary] |
| 2025-10-20 / 24 | ICCV 2025 WDFM-AD keynote; Ashok's X article "Tesla's approach to Autonomy" | E2E inputs are cameras, kinematics, **audio**, maps and navigation, outputting controls. Back-of-envelope "~2 billion input tokens" (7 cams × 36 FPS × 5 MP × 30 s, 5×5 patches). "Interpretable intermediate tokens", one of which is **Generative Gaussian Splatting**: "~220 ms, doesn't require initialization, can model dynamic objects … jointly trained with the end-to-end AI model". A small reasoning model "already running in FSD v14.x". **Neural world simulator** "synthesizes future state given current state and next action", is "causal", and runs closed-loop. At real-time test-time compute, a person drove 6+ min with "all 8 cameras with 24 frames per second". The same model applies to Optimus | https://x.com/aelluswamy/status/1981644831790379245 ; venue: https://wdfm-ad.github.io/iccv25/ | [primary] |
| 2026-02 | ScaledML 2026 keynote, Ashok | Recap only: internal "probes" for interpretability, GGS in "hundreds of milliseconds", simulator at 36 Hz. No video found | https://www.humanoidsdaily.com/news/abundance-and-the-bitter-lesson-ashok-elluswamy-outlines-tesla-s-unified-ai-future | [secondary] |
| 2026-06-03 | CVPR 2026 | Tesla event page lists Ashok's "Building foundational models for Robotics at Tesla" (workshop talk), a Phil Duan workshop talk, and a booth "Video Generation" driving sim. **Content not found** | https://www.tesla.com/event/tesla-x-cvpr-2026 (HTTP 403 to curl; seen only via search snippet) | [secondary] |

### Patents (Tesla, Inc. assignee; title, date and abstract read on Google Patents) `[primary]`

| Number | Title (short) | Why it matters here |
|---|---|---|
| US20230057509A1 → granted US12462575B2 | Vision ML model … adjustable virtual camera | Features projected into a vector space "associated with a virtual camera at a particular height", aggregated with prior frames. Matches the AI Day 2021 rectification and feature queue |
| US20230053785A1 | … aggregation of static objects (BEV) | Features projected to BEV and aggregated over time to output static objects |
| US20260170852A1 | … lane connectivity | Backbones "fused via a transformer", aggregated "across time and/or space" → lane connectivity. Matches the lanes network |
| US20240185445A1 | AI … vision-based occupancy determination | Occupancy attribute per voxel from cameras |
| WO2024237939A2 | AI … vision-based surface determination | Surface attributes. Matches the AI Day 2022 drivable surface |
| WO2025193615A1 / WO2025193618A1 | … high-fidelity occupancy … assisted parking | Per-voxel **signed distance**. "Rendering protocol": stack 2D SDF layers (example: 1-inch slices above the road), or ray-cast and shade intersected voxels; optional mesh fitting; NeRF optional; output "ingested by a rendering engine" |
| WO2025024226A2 | Enhanced UI for parking based on occupancy ML | Occupancy network outputs per-angular-range distance → UI around a car graphic |
| US20230377348A1, CN120167069A | Sim content for training; sim rendered from ground-truth heuristics | Matches the AI Day 2022 world-creator pipeline |

## Tesla component → open equivalent (pointers only)

Every arXiv ID was checked by title: the arxiv.org/abs page, because export.arxiv.org returned HTTP 429 that day; EfficientDet was checked via the API. Repos were checked with `gh api`. All as of 2026-11-24; stars and licences rot.

| Tesla component (source) | Closest open work | Notes |
|---|---|---|
| RegNet + BiFPN backbone (AI Day 21) | RegNet arXiv 2003.13678; BiFPN in EfficientDet 1911.09070 | Off-the-shelf; torchvision ships RegNet |
| Rectify all cams to a "virtual common camera" (AI Day 21; patent '509) | No direct open equivalent found | Most open BEV models feed intrinsics and extrinsics instead `[UNCERTAIN]` |
| Multi-cam transformer: output-raster queries → image K/V (AI Day 21) | BEVFormer 2203.17270 (`fundamentalvision/BEVFormer`, ~4.7k★, Apache-2.0). Lift-Splat-Shoot 2008.05711 is the depth-lift alternative | BEVFormer is the closest match to "raster queries with positional encodings" |
| Feature queue (time + space) and spatial RNN (AI Day 21) | Temporal BEV attention (BEVFormer); StreamPETR 2303.11926 (memory queue; `exiawsh/StreamPETR`, licence NOASSERTION) | Found no open "spatial RNN on a 2D lattice" `[UNCERTAIN]` |
| HydraNet heads (AI Day 21) | Multi-head BEV stacks such as UniAD 2212.10156 (`OpenDriveLab/UniAD`, ~4.8k★, Apache-2.0) | Pattern, not a specific repo |
| Occupancy Network + semantics (CVPR 22, AI Day 22) | Occupancy Networks 1812.03828 (Ashok cites it); SurroundOcc 2303.09551 (`weiyithu/SurroundOcc`, ~1.1k★); Occ3D 2304.14365 benchmark | Tesla's 10 ms / 100 Hz is on its own accelerator |
| Occupancy flow (CVPR 22, 10.69) | Waymo Occupancy Flow Fields 2203.03875 | Waymo's input is agents, not cameras. Closer camera-only work is covered by the BEV/occupancy note |
| High-fidelity SDF occupancy (Park Assist; WO'615) | No specific open camera-to-SDF parking model verified | Rendering an SDF is classic: ray marching / marching cubes |
| NeRF reconstruction and differentiable-render supervision (CVPR 22) | NeRF 2003.08934; Plenoxels 2112.05131 (both named by Ashok); EmerNeRF 2311.02077 (driving) | |
| Lanes network / "language of lanes" (AI Day 22) | MapTR 2208.14437 (vector map, non-autoregressive; `hustvl/MapTR`, MIT); TopoNet 2304.05277 (lane topology) | An open autoregressive lane-token model is covered by the maps note |
| Sim: Houdini world creator → Unreal (AI Day 22) | CARLA 1711.03938 (Unreal-based; `carla-simulator/carla`, MIT) | |
| Video world model, 8-cam, action-conditioned (CVPR 23) | GAIA-1 2309.17080 (no official repo found); Vista 2405.17398 (`OpenDriveLab/Vista`, Apache-2.0); Cosmos 2501.03575 (`nvidia-cosmos/cosmos-predict2`) | |
| End-to-end v12+ | UniAD 2212.10156; VAD 2303.12077; `commaai/openpilot` (MIT, ~64k★, a shipping camera-only driving model) | |
| Generative Gaussian Splatting, ~220 ms feed-forward, dynamic (ICCV 25) | Feed-forward GS: pixelSplat 2312.12337, MVSplat 2403.14627; driving + dynamic: STORM 2501.00602 (`NVlabs/GaussianSTORM`). Street Gaussians 2401.01339 is the slow per-scene baseline Tesla contrasts against | |
| Neural world simulator, closed-loop, real-time (ICCV 25) | GAIA-2 2503.20523 (no official repo found); Cosmos; Vista | |
| Small reasoning model in v14 (ICCV 25) | DriveVLM 2402.12289 | Pointer only |
| In-car viz engine (Godot, reportedly) | `godotengine/godot` (MIT, ~121k★) | For dev viz: `rerun-io/rerun` (Apache-2.0). The renderer note decides |

## The in-car visualization: what is known

- **What it is.** A 3D render of the perception outputs ("vector space"), not of camera pixels. Karpathy said
  so at AI Day 2021 (0:49:56) `[primary]`. It draws vector lanes, curbs, crosswalks, vehicles by class,
  pedestrians, cones, poles and speed bumps; the planned path is coloured by accel/brake; the lead or
  in-path car is highlighted. Since FSD Beta 10.69.2, unidentified objects appear as a generic "pile of
  debris" with no true shape. Not a Tesla App: "visualizations … aren't tied one-to-one with what the car is
  capable of detecting" (https://www.notateslaapp.com/tesla-reference/636/) `[secondary]`.
- **Occupancy "blobs".** In 2022 Tesla twice said occupancy was *not* in the customer display `[primary]`.
  The high-resolution occupancy did reach the screen in Dec 2023 for parking (High-Fidelity Park Assist).
  Ashok: a distance field, with shapes that are "not some fixed meshes". The patent describes the drawing
  as stacked SDF slices or ray-cast voxels `[primary]`. Whether the *driving* view's grey debris piles come
  from the occupancy network is `[UNCERTAIN]`.
- **Engine.** Godot today, Unreal binaries staged on AMD S/X since 2025.20 (greentheonly, Aug 2025)
  `[secondary]`. Tesla job ads for "Rendering Engineer, Infotainment" list Godot, Unity and Unreal as a plus,
  per search snippets `[secondary]`. I found no Tesla statement and no confirmation that the Unreal version
  shipped `[UNCERTAIN]`.
- **After v12 (end-to-end).** What feeds the visualization once driving is a single network is
  **undisclosed**. Forum claims that "perception nets now exist only for the viz" are speculation
  `[UNCERTAIN]`. The nearest primary statement is Ashok's: the end-to-end model "can also produce
  interpretable intermediate tokens" (ICCV 2025) `[primary]`. That is consistent with auxiliary heads driving
  the display, but does not prove it.

## Dead ends (recorded so nobody repeats them)

- **"Tesla's FSD display runs on Unreal."** Not as of the last evidence. The lore mixes two things: AI Day
  2022 showed the *training simulator* exports to Unreal, and Unreal *viz* binaries are staged but inactive.
- **"The FSD display shows the occupancy network."** False for the 2022 driving view, by Tesla's own words.
  Only the parking view (Dec 2023+) is confirmed.
- **Name collision.** "Generative Gaussian Splatting" is also the title of an unrelated Meta Reality Labs paper
  (Schwarz et al., https://katjaschwarz.github.io/ggs) `[secondary]`. It is not Tesla's method.
- **Tesla GGS and world-sim details.** No paper, code, patent or slides found. Google Patents shows no Tesla
  filing on Gaussian splatting as of 2026-11-24. The "~220 ms" exists only in Ashok's X article, with no
  hardware or resolution given.
- **CVPR 2023 world-model architecture.** Asked on stage and declined (0:21:03).
- **CVPR 2026 talk content.** The tesla.com event page returns 403 to curl. I found no recording or recap.
- **ICCV 2025 recording.** No official video found. The X article is Ashok's own "abridged version".
- **Dojo.** The AI Day 2022 training-hardware content is historical: Dojo was shut down in Aug 2025.
- **Camera count.** Ashok's token arithmetic uses 7 cameras; the world-sim demo says 8. I did not try to
  reconcile them.

## Open questions

1. What representation feeds the v14 driving visualization: auxiliary heads of the end-to-end net, or a separate perception net?
2. Has the Unreal-based visualization shipped on any car? Has the occupancy/SDF render reached the driving view?
3. GGS: what Gaussian parameters it predicts, from how many frames, and on what hardware the ~220 ms was measured.
4. World simulator: diffusion or autoregressive tokens, output resolution, and the compute behind "real-time".
5. What the CVPR 2026 talks (Ashok, Phil Duan) disclosed. Worth a targeted search once recordings appear.
