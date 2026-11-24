"""Reproducible arithmetic behind research/11-realtime-compute-budget.md.

Every input is a measured number from research/07-10 (source in the comment). Every output is derived.
Run: python3 research/compute_budget.py
"""
from math import log

def exponent(cost_ratio, size_ratio):
    """Time grows as size**a; returns a."""
    return log(cost_ratio) / log(size_ratio)

def interp_gpus(curve, needed):
    """Linear interpolation on a (gpus, throughput) curve."""
    for (g0, t0), (g1, t1) in zip(curve, curve[1:]):
        if t0 <= needed <= t1:
            return g0 + (needed - t0) * (g1 - g0) / (t1 - t0)
    return None

print("== 1. How reconstruction time grows with input size (07)")
exps = {
    "BTimer views 4->12 (20->150 ms)": exponent(150 / 20, 3),
    "BTimer pixels 256^2->512^2 (0.15->1.55 s)": exponent(1.55 / 0.15, 4),
    "VGGT frames 10->100 (0.14->3.12 s)": exponent(3.12 / 0.14, 10),
    "VGGT frames 100->200 (3.12->8.75 s)": exponent(8.75 / 3.12, 2),
    "AnySplat views 3->16 (0.171->0.767 s)": exponent(0.767 / 0.171, 16 / 3),
    "DepthSplat views 2->6 (0.083->0.132 s)": exponent(0.132 / 0.083, 3),
    "EVolSplat4D pixels x9 (1.29->1.88 s, voxel)": exponent(1.88 / 1.29, 9),
}
for k, v in exps.items():
    print(f"  {k}: a = {v:.2f}")
A_LO, A_HI = 1.0, 1.83  # linear .. worst full-attention case seen

print("\n== 2. Tesla-like live reconstruction: VGD 6 cams x 352x640, 0.26 s on A100 bf16 (07)")
vgd = 0.26
px_vgd = 352 * 640 / 1e6
for a in (A_LO, 1.34, A_HI):
    print(f"  8 cams, same res, a={a:.2f}: {vgd * (8 / 6) ** a:.2f} s on A100")
t8_lo, t8_hi = vgd * (8 / 6) ** A_LO, vgd * (8 / 6) ** A_HI
for mp in (0.5, 1.0):
    lo = t8_lo * (mp / px_vgd) ** 1.34
    hi = t8_hi * (mp / px_vgd) ** 1.68
    print(f"  8 cams at {mp} MP each (pixel a=1.34..1.68): {lo:.1f}-{hi:.1f} s on A100")
print(f"  per-pixel Gaussians, 8 x 352x640: {8 * 352 * 640 / 1e6:.2f} M")

# Dense FP16/BF16 tensor TFLOPS (10). Peak-ratio scaling is optimistic for big GPUs at batch 1.
TFLOPS = {"A100": 312, "H100": 989.5, "B200": 2250, "RTX 4090": 165.2}
print("  peak-ratio scaling of the 8-cam same-res time:")
for dev, tf in TFLOPS.items():
    s = TFLOPS["A100"] / tf
    print(f"    {dev}: {t8_lo * s:.2f}-{t8_hi * s:.2f} s  ({1 / (t8_hi * s):.1f}-{1 / (t8_lo * s):.1f} updates/s)")
print("  H100 at a realistic 2-3x A100 (not the 3.2x peak):",
      f"{t8_lo / 3:.2f}-{t8_hi / 2:.2f} s")
# M5: Apple gives only '>4x M4 peak GPU AI compute'; M4 FP32 ~3.8-4.3 TF (10). Precision unstated -> UNCERTAIN.
for m5 in (8, 17):
    s = TFLOPS["A100"] / m5
    print(f"  Apple M5 if ~{m5} TFLOPS usable: {t8_lo * s:.1f}-{t8_hi * s:.1f} s per update")

print("\n== 3. Drawing splats (08, 10)")
sg_ms = 1000 / 135                 # Street Gaussians, 1066x1600, RTX 4090
sg_mp = 1066 * 1600 / 1e6
print(f"  Street Gaussians: {sg_ms:.2f} ms per {sg_mp:.2f} MP view on a 4090")
print(f"  8 views: {8 * sg_ms:.1f} ms -> {1000 / (8 * sg_ms):.1f} fps for all 8")
for fps in (24, 30):
    print(f"  budget per view for 8 x {fps} fps: {1000 / (8 * fps):.2f} ms")
print(f"  same scene at 1.0 MP (cost ~ pixels): {sg_ms / sg_mp:.2f} ms")
prune = 7.478 / 1.11               # Speedy-Splat 13-scene average speed-up
print(f"  with Speedy-Splat-style pruning (x{prune:.1f}): {sg_ms / sg_mp / prune:.2f} ms per 1 MP view")

# M4 Max, browser WebGPU, 1298x962: 20 M -> 98 fps, 35 M -> 76 fps (PlayCanvas, 08). Fit t = t0 + n/k.
t20, t35 = 1000 / 98, 1000 / 76
k = (35e6 - 20e6) / ((t35 - t20) / 1000)      # splats per second
t0 = t20 - 20e6 / k * 1000                     # fixed ms per frame
print(f"  M4 Max fit: t = {t0:.1f} ms + n / {k / 1e9:.1f} G splats/s"
      f"  (check 10 M: {1000 / (t0 + 10e6 / k * 1000):.0f} fps vs 124 measured)")
# M5 (10 GPU cores, 153 GB/s) vs M4 Max (32-40 cores, 410-546 GB/s): 0.25-0.37x. Two bounds:
for name, scale_t0 in (("fixed cost does not scale", False), ("fixed cost scales with GPU", True)):
    for r in (0.25, 0.37):
        t = (t0 / r if scale_t0 else t0) + 2e6 / (k * r) * 1000
        print(f"  M5 est. ({name}, ratio {r}): 2 M splats -> {1000 / t:.0f} fps")

print("\n== 4. World simulator: OmniDreams-MV, 4 views 704x1280, GB300 (09)")
curve = [(1, 4 * 12), (4, 4 * 48), (8, 4 * 74), (16, 4 * 105)]  # (GPUs, camera-frames/s)
need = 8 * 24
print(f"  Tesla claim: {need} camera-frames/s; OmniDreams curve: {curve}")
for a in (A_LO, 1.34, A_HI):
    eq = need * 2 ** (a - 1)   # cost per camera-frame grows when views double 4 -> 8
    g = interp_gpus(curve, eq)
    print(f"  view-scaling a={a:.2f}: needs {eq:.0f} 4-view-equivalent frames/s -> ~{g:.1f} GB300")
for g in (4, 11):
    print(f"  {g} GB300 = {g * 2.25:.0f}-{g * 2.5:.0f} PFLOPS dense FP16 peak")
print(f"  GB300 vs RTX 4090 dense FP16: {2250 / 165.2:.0f}-{2500 / 165.2:.0f}x")
print(f"  OmniDreams-SV 68 fps (1 GB300) scaled to a 4090 by peak: {68 * 165.2 / 2500:.1f}-{68 * 165.2 / 2250:.1f} fps, one camera")

print("\n== 5. Tesla car computers vs A100 (10; AI4/AI5 are unofficial)")
a100_int8 = 624
for name, tops in (("HW3 board (official)", 144), ("AI4 est. low", 100), ("AI4 est. high", 150),
                   ("AI5 ~8x AI4 low", 800), ("AI5 ~8x AI4 high", 1200)):
    print(f"  {name}: {tops} INT8 TOPS = {tops / a100_int8:.2f}x A100 dense INT8")

print("\n== 6. Low-quality settings (same anchors, same assumptions)")
# Lower input resolution: reconstruction time ~ pixels**a, a = 1.34-1.68 (section 1).
A100_PER = {"A100": 1.0, "RTX 4090": 312 / 165.2}      # 4090 between 1x and peak-ratio 1.89x slower
for w, h in ((224, 400), (160, 240)):
    r = w * h / 1e6 / px_vgd
    lo, hi = t8_lo * r ** 1.68, t8_hi * r ** 1.34
    print(f"  8 cams at {w}x{h} ({w * h / 1e6:.3f} MP, {r:.2f}x VGD pixels):"
          f" A100 {lo:.3f}-{hi:.3f} s; 4090 {lo:.3f}-{hi * A100_PER['RTX 4090']:.3f} s"
          f" ({1 / (hi * A100_PER['RTX 4090']):.0f}-{1 / lo:.0f} updates/s);"
          f" M5 {lo * 312 / 17:.1f}-{hi * 312 / 8:.1f} s;"
          f" per-pixel Gaussians {8 * w * h / 1e6:.2f} M")
print("  check vs Omni-Scene measured 6 x 224x400 = 0.088 s (GPU n.r.): 8 cams ->",
      f"{0.088 * (8 / 6) ** A_LO:.3f}-{0.088 * (8 / 6) ** A_HI:.3f} s")
print("  floor: VGGT backbone 1 frame = 0.04 s on H100; fixed overheads stop gains below ~20-40 ms")

# Fewer Gaussians: drawing. Speedy-Splat 0.28 M -> 1.11 ms on an RTX A5000 (slower than a 4090).
print(f"  4090 drawing ~0.3 M Gaussians: <= 1.11 ms per view (measured on slower A5000) -> 8 views <= {8 * 1.11:.1f} ms")
for n in (0.3e6, 0.7e6):
    for name, scale_t0 in (("t0 fixed", False), ("t0 scales", True)):
        fps = [1000 / ((t0 / r if scale_t0 else t0) + n / (k * r) * 1000) for r in (0.25, 0.37)]
        print(f"  M5 drawing {n / 1e6:.1f} M splats ({name}): {min(fps):.0f}-{max(fps):.0f} fps")

# Memory per Gaussian: 3 pos + 3 scale + 4 quat + 1 opacity + SH colour (3 x (deg+1)^2).
for deg in (3, 1, 0):
    floats = 11 + 3 * (deg + 1) ** 2
    print(f"  SH degree {deg}: {floats} floats = {floats * 4} B fp32 / {floats * 2} B fp16;"
          f" 1 M Gaussians = {floats * 4:.0f} MB fp32")

# World sim, one more (rough) step: OmniDreams-SV scaled to a 4090 = 4.5-5.0 fps at 704x1280 (section 4).
r = (352 * 640) / (704 * 1280)
lo, hi = 4.5 / r ** 1.0, 5.0 / r ** 1.68
print(f"  world sim on a 4090 at 352x640 (1/4 pixels, a=1.0-1.68): {lo:.0f}-{hi:.0f} fps for ONE camera;"
      f" 8 cams x 24 fps needs 192 -> {192 / hi:.1f}-{192 / lo:.1f}x short")

print("\n== 7. RTX 5070 Ti 16 GB (owner's card)")
# NVIDIA 5070 family page (2026-11-24): 8,960 CUDA cores, 2.45 GHz boost, 1,406 AI TOPS (sparse FP4), 16 GB GDDR7, 256-bit, 300 W.
fp32 = 8960 * 2 * 2.45 / 1000                 # TFLOPS
fp16_acc32 = 1406 / 2 / 2 / 2 / 2             # sparse FP4 -> dense FP4 -> FP8 -> FP16(acc16) -> FP16(acc32), same chain as the 5090 whitepaper
bw = 256 / 8 * 28                             # GB/s, assumes 28 Gbps GDDR7 (speed not on NVIDIA's page)
print(f"  FP32 {fp32:.1f} TF; dense FP16 {fp16_acc32:.1f} TF (FP32 acc) / {fp16_acc32 * 2:.1f} (FP16 acc); ~{bw:.0f} GB/s")
print(f"  vs RTX 4090: FP32 {fp32 / 82.6:.2f}x, tensor {fp16_acc32 / 165.2:.2f}x, bandwidth {bw / 1008:.2f}x")
draw = 0.65 * 82.6 / fp32 + 0.35 * 1008 / bw   # splat drawing, rule of thumb from research/10
net_lo, net_hi = 1008 / bw, 165.2 / fp16_acc32  # network inference: bandwidth-bound .. tensor-bound
print(f"  splat drawing ~{draw:.2f}x slower than a 4090; networks {net_lo:.2f}-{net_hi:.2f}x slower")
print(f"  Street Gaussians view (1.7 MP): {sg_ms * draw:.1f} ms -> {1000 / (sg_ms * draw):.0f} fps;"
      f" 8 views at 1 MP: {8 * sg_ms / sg_mp * draw:.0f} ms -> {1000 / (8 * sg_ms / sg_mp * draw):.0f} fps;"
      f" pruned: {8 * sg_ms / sg_mp / prune * draw:.1f} ms -> {1000 / (8 * sg_ms / sg_mp / prune * draw):.0f} fps")
for label, lo4, hi4 in (("352x640", t8_lo, t8_hi * 312 / 165.2),
                        ("224x400", t8_lo * (224 * 400 / 1e6 / px_vgd) ** 1.68, t8_hi * (224 * 400 / 1e6 / px_vgd) ** 1.34 * 312 / 165.2),
                        ("160x240", t8_lo * (160 * 240 / 1e6 / px_vgd) ** 1.68, t8_hi * (160 * 240 / 1e6 / px_vgd) ** 1.34 * 312 / 165.2)):
    lo, hi = lo4 * net_lo, hi4 * net_hi
    print(f"  live reconstruction, 8 cams at {label}: {lo:.3f}-{hi:.3f} s ({1 / hi:.1f}-{1 / lo:.0f} updates/s)")
print(f"  world sim, one camera: 704x1280 {4.5 / net_hi:.1f}-{5.0 / net_lo:.1f} fps; 352x640 {18 / net_hi:.0f}-{51 / net_lo:.0f} fps")
