# 10 — Hardware reference table (for scaling latencies between devices)

Collected 2026-11-24, light web research only: nothing downloaded on purpose, nothing run. NVIDIA whitepaper PDFs
were read page by page from the copy WebFetch cached. Tags: `[primary]` = vendor datasheet, whitepaper or first-party
statement (URL given); `[secondary]` = reputable third party or a search snippet of a vendor page; `[derived]` =
arithmetic on numbers from the source named in that row; `[UNCERTAIN]` = estimate, rumour or unconfirmed; `[inference]` = my own reasoning.

## TL;DR

- **NVIDIA data-center pages quote tensor numbers *with sparsity*.** Halve them to get dense: H100 SXM "1,979 FP16" = **989.5 dense**.
  GeForce cards have a second trap: FP16 with **FP32 accumulate** (what PyTorch AMP uses) runs at **half** the FP16-accumulate rate. RTX 4090 = **165.2** dense, not 330.
- **To scale 3DGS rendering between GPUs, use FP32 TFLOPS and memory bandwidth. Ignore tensor TFLOPS.** FlashGS measured the A100 **1.43× slower**
  than an RTX 3090 at rasterization, even though the A100 has 2× the bandwidth, because it has 19.5 vs 35.6 FP32 TFLOPS `[primary]`.
- **Tesla HW3 is the only Tesla computer with official specs:** 36.8 INT8 TOPS per NNA, 2 NNAs per chip, 2 chips per board ≈ 144 TOPS, 72 W board,
  15 W NNA (Hot Chips 2019 slides) `[primary]`. **HW4/AI4 has no official compute spec at all. Every AI4 TOPS figure online is an estimate.**
  For **AI5**, Tesla has given only multiples: "40× by some metrics, safely 10×" (Musk, Q3 2025 call), plus reported ~8× raw compute / 9× memory / 5× bandwidth.
- **A 16 GB MacBook means a base M1/M2/M3/M4/M5 (or M1 Pro / M2 Pro).** The 16 GB chips have 68–153 GB/s of bandwidth and roughly 2.6–4.3 FP32 TFLOPS (Apple published only M1's 2.6). Measured FP32 is
  about 60–90% of theoretical. Against an RTX 4090 that is about **7–15× less bandwidth and about 20–30× less FP32**. On M1–M4 the GPU runs FP16 at the FP32 rate `[UNCERTAIN]`.
- Marketing headline numbers mix precisions: RTX 50 "AI TOPS" = **sparse FP4**; Jetson Thor "2070 TFLOPS" = **sparse FP4**; DRIVE Thor "2000" was FP8 in 2022 and
  **FP4** later; Apple Neural Engine 38 TOPS (M4) is reportedly **INT8**, while M3's 18 was **FP16**. Blackwell Ultra (GB300) **cut INT8 and FP64**.

## Main table (per GPU / per chip; dense unless marked)

FP16 column = dense FP16/BF16 tensor TFLOPS with FP32 accumulate. The FP16-accumulate rate is in brackets where it differs.
INT8 = dense tensor TOPS. "n/p" = not published.

| Device | FP32 TFLOPS | Dense FP16/BF16 TFLOPS | Dense INT8 TOPS | Mem GB | BW GB/s | TDP W | Source + tag |
|---|---|---|---|---|---|---|---|
| A100 40GB SXM | 19.5 | 312 | 624 | 40 HBM2 | 1,555 | 400 | NVIDIA Ampere in-depth blog, Table 3 (dense/sparse pairs 312/624, 624/1248) `[primary]` |
| A100 80GB SXM (PCIe) | 19.5 | 312 | 624 | 80 HBM2e | 2,039 (1,935) | 400 (300) | nvidia.com/en-us/data-center/a100: "312 TFLOPS / 624*", * = with sparsity `[primary]` |
| H100 SXM | 67 | 989.5 | 1,979 | 80 HBM3 | 3,350 | 700 | nvidia.com/en-us/data-center/h100: 1,979 FP16 / 3,958 INT8 "*With sparsity" → ÷2 `[primary]`+`[derived]` |
| H200 SXM | 67 | 989.5 | 1,979 | 141 HBM3e | 4,800 | 700 | nvidia.com/en-us/data-center/h200, same compute as H100, sparse figures ÷2 `[primary]`+`[derived]` |
| B200 (HGX) | 75 | 2,250 | 4,500 | 180 HBM3e | 8,000 | 1,000 | nvidia.com/en-us/data-center/hgx: 8-GPU totals 36 PF FP16 / 72 POPS INT8 (sparse), 600 TF FP32 → ÷8, ÷2 `[primary]`+`[derived]`; 1,000 W from NVIDIA HGX B200 PCF summary (search snippet) `[secondary]` |
| GB200 (per Blackwell GPU) | 80 | 2,500 | 5,000 | 186 HBM3e | 8,000 | ≤1,200 | nvidia.com/en-us/data-center/gb200-nvl72: superchip (2 GPUs) 10 PF FP16, 20 POPS INT8 (sparse), 160 TF FP32, 372 GB, 16 TB/s → ÷2, ÷2 `[primary]`+`[derived]`; TGP from Blackwell Ultra blog `[primary]` |
| GB300 / Blackwell Ultra (per GPU) | 75–83 | 2,250–2,500 | **~167–188** | 288 (278 usable on NVL72) | 8,000 | ≤1,400 | Blackwell Ultra blog: 15 PF dense NVFP4, 5 PF dense FP8, 288 GB, 8 TB/s, 1,400 W `[primary]`; NVL72 page 360 PF FP16 / 24 POPS INT8 sparse ÷72 ÷2; HGX B300 3 POPS INT8 ÷8 ÷2 `[derived]` (the two pages disagree, hence the range) |
| RTX 3090 | 35.6 | 71 (142) | 284 | 24 GDDR6X | 936 | 350 | GA102 whitepaper v2, Table 9 (p.44–45) `[primary]` |
| RTX 4090 | 82.6 | 165.2 (330.3) | 660.6 | 24 GDDR6X | 1,008 | 450 | Ada whitepaper, Table 2 (p.29–31) `[primary]` |
| RTX 5090 | 104.8 | 209.5 (419) | 838 | 32 GDDR7 | 1,792 | 575 | RTX Blackwell whitepaper, Table 3 (p.46–48): FP4 1,676/3,352 `[primary]` |
| RTX 5070 Ti (owner's card) | 43.9 | 87.9 (175.8) | 351.5 (FP8) | 16 GDDR7 | ~896 | 300 | NVIDIA RTX 5070 family page, read 2026-11-24: 8,960 cores, 2.45 GHz, 1,406 AI TOPS (sparse FP4), 256-bit, 300 W `[primary]`. FP32 = cores × 2 × clock; FP16 = 1,406 halved 4× like the 5090 row; bandwidth assumes 28 Gbps `[derived]` |
| RTX A6000 | 38.7 | 154.8 | ~309.7 | 48 GDDR6 | 768 | 300 | NVIDIA A6000 datasheet: "309.7 TFLOPS" tensor (sparse) `[primary, via search snippet]`; dense = ÷2, INT8 = 2× FP16 (Ampere ratio) `[derived]` |
| RTX 6000 Ada | 91.1 | ~364 | ~728.5 | 48 GDDR6 | 960 | 300 | nvidia.com rtx-6000: "1457 AI TOPS" = "FP8 using the sparsity feature" → ÷2 = 728.5 FP8 dense, ÷2 = 364 FP16 `[primary]`+`[derived]`; 960 GB/s from datasheet snippet `[secondary]` |
| L40S | 91.6 | 362 | 733 | 48 GDDR6 | 864 | 350 | nvidia.com/en-us/data-center/l40s: "362.05 \| 733*" `[primary]` |
| Jetson AGX Orin 64GB | 5.3 | ~42.5 (GPU) | 85 GPU (+ DLA, 105 in the headline) | 64 LPDDR5 | 204.8 | 15–60 | Orin technical brief: 275 INT8 TOPS = GPU "170 Sparse" + DLA 105; "5.3 FP32 TFLOPs" `[primary]`; dense GPU = 170÷2; FP16 = INT8÷2 `[derived]`; power `[secondary]` |
| Jetson AGX Thor T5000 | ~8.1 | 258.5 | 517 | 128 LPDDR5X | 273 | 40–130 | Thor blog Table 1: "2070 (Sparse FP4)", "1035 (Dense FP4 \| Sparse FP8 \| Sparse INT8)", "517 (Dense FP8 \| Sparse FP16)" `[primary]` → FP16 = 517÷2 `[derived]`; FP32 = 2,560 cores × 2 × 1.575 GHz `[UNCERTAIN]` (not published) |
| DRIVE AGX Thor (SoC) | n/p | n/p (~250?) | "1000 INT8 TOPS" (sparsity unstated) | 64 (devkit) | n/p | n/p | developer.nvidia.com/drive/agx "1000 INT8 TOPS \| 2000 FP4" `[primary]`; it likely matches Jetson Thor's *sparse* numbers `[UNCERTAIN]` |
| Tesla HW3 (one board = 2 chips) | 2 × 0.6 (GPU) | — (NNA is INT8) | **144** board / 73.7 chip | 2 × LPDDR4 | 2 × 68 | 72 board | Hot Chips 31 slides (below) `[primary]`; GPU 600 GFLOPS + LPDDR4-4266 68 GB/s `[secondary]` |
| Tesla HW4 / AI4 | ? | ? | **~100–150 est.** | ~16 GDDR6 est. | ~384 est. | 80–100 est. | **UNOFFICIAL.** Electrek 2025-11-25 table, "best possible specs I could find" `[UNCERTAIN]` |
| Tesla AI5 | ? | ? | "~8× AI4 raw" | "9× AI4" (then cut) | "5× AI4" | ? | Musk statements only (see Tesla section) `[primary multiples]` / `[secondary]` |
| Apple M1 (8-core GPU) | 2.6 | ≈2.6 (no 2× rate) | NE 11 "TOPS" | 8/16 | 68.25 | n/p | Apple newsroom 2020-11: "2.6 teraflops", "11 trillion operations per second" `[primary]`; BW `[secondary]` |
| Apple M2 (10-core GPU) | ~3.6 | ≈3.6 | NE 15.8 | 8–24 | 100 | n/p | Apple newsroom 2022-06: "15.8 trillion", "100GB/s" `[primary]`; 3.6 TF Notebookcheck `[secondary]` |
| Apple M3 (10-core GPU) | ~3.5 | ≈3.5 | NE 18 (FP16, reported) | 8–24 | 100 | n/p | Apple support specs "100GB/s" `[primary]`; TFLOPS arXiv 2502.05317 theory `[secondary]` |
| Apple M4 (10-core GPU) | ~3.8–4.3 | ≈ same | NE 38 (INT8, reported) | 16–32 | 120 | n/p | Apple newsroom 2024-05 "38 trillion"; MacBook Air specs "120GB/s" `[primary]`; TFLOPS `[UNCERTAIN]` |
| Apple M5 (10-core GPU) | n/p | ">4× M4 peak GPU AI compute" | n/p | 16–32 | 153 | n/p | Apple newsroom 2025-10: "Neural Accelerator in each core", "153GB/s" `[primary]` |

## Sparsity / precision traps (how to normalise)

- **Sparsity (2:4 structured):** NVIDIA's data-center pages mark sparse numbers with "*"; the HGX page says "Dense is ½ sparse spec shown". The whitepapers
  print "dense/sparse" pairs. Real models are almost never 2:4 sparse, so **always use the dense number**.
- **Accumulate precision on GeForce:** 3090/4090/5090 run FP16→FP32-accumulate at half the FP16→FP16 rate (whitepaper rows). Pro and data-center parts
  (A6000, RTX 6000 Ada, L40S, A100/H100) run it at full rate. Use the FP32-accumulate number for PyTorch training/AMP.
- **FP4 "AI TOPS" back to FP16, RTX 5090:** 3,352 (sparse FP4) ÷2 → 1,676 dense FP4 ÷2 → 838 FP8 ÷2 → 419 FP16 (FP16 acc) ÷2 → **209.5** FP16 (FP32 acc) `[derived, matches Table 3]`.
- **Jetson Thor:** 2,070 sparse FP4 → 1,035 dense FP4 → 517 dense FP8 → **258.5 dense FP16**. NVIDIA staff never answered the forum thread asking how 2,070 is computed.
- **Blackwell Ultra is not "2× B200 at every precision":** dense NVFP4 rose 10 → 15 PF, while FP8 (5 PF dense) and FP16 stayed the same. INT8 fell from 72 POPS (HGX B200) to 3 POPS (HGX B300),
  and FP64 from 296 to 10 TF. **Do not assume INT8 = 2× FP16 on GB300.** Sparse NVFP4 is 20 PF on both B200 and B300, so on B300 "sparse" is not 2× dense.
- **Orin "275 TOPS"** adds GPU sparse INT8 (170) and DLA (105). Only the GPU runs general PyTorch/TensorRT layers at full flexibility.
- **DRIVE Thor:** NVIDIA's 2022 launch said "2,000 teraflops of FP8"; current pages say 1,000 INT8 TOPS / 2,000 FP4. Same chip, different precision label `[secondary]`.
- **Tesla vs NVIDIA (2019):** Tesla's "144 TOPS vs Xavier 21" counts both redundant chips. NVIDIA and Linley's Mike Demler called the comparison misleading `[secondary]`.
- **Apple Neural Engine:** precision is never stated by Apple. M4 "38 TOPS" is reported as INT8 and M3 "18" as FP16, so the real gain is small (Tom's Hardware) `[secondary]`.
  The ANE is reachable only through Core ML, not PyTorch MPS, so for MPS work use GPU FP32 numbers.

## Tesla computers

**HW3 / "FSD Computer" — Hot Chips 31 slides (Bannon, Venkataramanan, Das Sarma, Talpes, McGee), 2019** `[primary]`
URL: https://old.hotchips.org/hc31/HC31_2.3_Tesla_Hotchips_ppt_Final_0817.pdf (read slide by slide):
- Chip: "14nm FinFET CMOS, 260 mm2, 6 billions transistors, AEC Q100, 37.5 x 37.5mm FCBGA". Blocks: NNA ×2, GPU ×1, CPU ×12, ISP + H.265 encoder, safety island.
- NN accelerator: "2 Independent instances", "2Ghz+ Design", "**96x96 MACs (36.8 TOPS/NNA)**", "32MB SRAM/instance", "Hardware SIMD, ReLU & Pool units".
  Check: 9,216 MACs × 2 ops × 2.0 GHz = 36.9 TOPS `[derived]`. INT8 per the Hot Chips Q&A `[secondary]`.
- Design goals: "> 50 TOPS", "~80%" utilisation, "optimized for batchsize of one", "Sub 40W/Chip", board "Sub 100W".
- Results: board power **72 W** (HW2.5 57 W), **NNA 15 W**; **2,300 frames/s vs 110** on HW2.5 (21×); cost 0.8× HW2.5.
- Board: "Dual Redundant SOCs, Redundant Power supplies". Autonomy Day (2019-04-22) headline: **144 TOPS** per board = 2 × 72 `[secondary: VentureBeat, TechCrunch]`.
- Not on the slides, secondary only: 12 × Cortex-A72 @ 2.2 GHz; GPU ~1 GHz, **600 GFLOPS** FP32/FP16; LPDDR4-4266, **68 GB/s** per chip (CleanTechnica, WikiChip, TechPowerUp).
  I could not find a primary Autonomy Day transcript `[UNCERTAIN wording]`.

**HW4 / AI4 — no official compute spec exists. Treat every number as unverified.**
- First-party facts only: Samsung manufactures the AI4 computer, and AI4 has a "legacy GPU" and an image signal processor (Musk, Q3 2025 call) `[primary]`.
  "36 Hz, full-resolution AI4 video inputs" (FSD v13 release notes, see 01) `[secondary]`.
- Estimates: 2 SoCs, 3 NPUs per SoC at ~2.2 GHz, 20 Cortex-A72 cores, GDDR6 (~384 GB/s, 256-bit), ~16 GB, **~100–150 INT8 TOPS** per board,
  80–100 W, Samsung 7 nm "per teardowns" (greentheonly) — Electrek 2025-11-25 calls these "the best possible specs I could find" `[UNCERTAIN]`.
  Other estimates: ~121 TOPS per chip (SemiAnalysis-style math); one outlier source says ~500 TOPS `[UNCERTAIN]`.

**AI5 — multiples only, no datasheet**
- Q3 2025 call (2025-10-22), Musk: "By some metrics, the AI five chip will be 40 times better than the AI four chip"; "just to say safely, it's a 10x improvement";
  "best performance per watt, maybe by a factor of two or three"; legacy GPU and ISP "deleted"; fits "in a half reticle"; built by TSMC (Arizona) and Samsung (Texas) `[primary transcript, fool.com]`.
- Musk on X, as reported: "a single AI5 has ~5 times the useful compute of a dual SoC AI4"; ~**8× raw compute, 9× memory, 5× bandwidth**. Memory was later cut
  (reports say 144 → 72 GB, then 96 GB) because of a memory shortage `[secondary: notateslaapp, wccftech]`. Taped out at TSMC, then Samsung (Musk on X, 2026-04-15) `[secondary: Electrek]`.
  Volume production is reported anywhere from late 2026 to mid-2027 `[UNCERTAIN]`. WCCFtech's "~2,500 TOPS" is a projection `[UNCERTAIN]`.
- `[derived, UNCERTAIN]` 8× an unofficial 100–150 TOPS AI4 gives ~800–1,200 INT8 TOPS, and 5× ~384 GB/s gives ~1.9 TB/s. These numbers are no firmer than the AI4 estimate they start from.

## Apple silicon (what a 16 GB MacBook can be)

- Chips sold with 16 GB: M1, M2, M3, M4, M5 base, plus **M1 Pro and M2 Pro** (base 16 GB). M3 Pro starts at 18 GB, M4 Pro at 24 GB, and the Max chips at 32 GB+, so those are out
  `[secondary: MacRumors buyer's guide; Apple spec snippets]`. Check this Mac with **About This Mac** or `sysctl -n machdep.cpu.brand_string`.
- Bandwidth `[primary unless marked]`: M1 68.25 `[secondary]` · M1 Pro 200 · M1 Max 400 · M2 100 · M2 Pro 200 · M2 Max 400 · M3 100 · M3 Pro 150 · M3 Max 300/400 · M4 120 · M4 Pro 273 ·
  M4 Max up to 546 · M5 153 GB/s.
- GPU FP32: Apple published TFLOPS only for M1 (2.6, 8-core). Scaled per core: M1 Pro 16-core ≈ 5.2, M1 Max 32-core ≈ 10.4, M2 Pro 19-core ≈ 6.8 `[derived, UNCERTAIN]`.
  Measured FP32 with MPS (arXiv 2502.05317, base chips): M1 1.36, M2 2.24, M3 2.47, M4 2.9 TFLOPS. Measured GPU STREAM bandwidth: 60 / 91 / 92 / 100 GB/s `[secondary]`.
- FP16: on M1–M4 the GPU ALUs reportedly run FP16 at the FP32 rate, so half precision saves memory and registers but adds no FLOPS
  (Philip Turner's metal-benchmarks, relayed on forums) `[UNCERTAIN]`. M5 adds a "Neural Accelerator" (matrix unit) to each GPU core. Apple claims ">4× peak GPU compute for AI vs M4"
  and does not state the precision `[primary]`.
- Neural Engine: M1 11, M2 / M2 Pro 15.8, M3 18 (Apple: "60% faster than M1"), M4 38 TOPS. M1 Pro/Max and M4 Pro/Max newsrooms give no TOPS.

## 3DGS scaling note (why FP32 and bandwidth, not tensor cores)

- **FlashGS** (arXiv 2408.07967, RTX 3090 + A100) `[primary]`: "renderCUDA" (per-tile alpha blending) is ~60% of frame time and "computation-bound".
  Preprocess and key generation are "bandwidth-limited", and sorting is "mainly memory-bandwidth-bound". Rasterization ran **~1.43× slower on the A100 than on the 3090**,
  which the authors attribute to FP32 (19.5 vs 35.6 TFLOPS). The A100's higher bandwidth sped up sorting but did not make up the difference. Original 3DGS on a 3090: Truck 1080p 8.21 ms, MatrixCity 4K 66.55 ms.
- **GSCore** (ASPLOS 2024) `[secondary, talk slides]`: sorting + rasterization > 80% of time; 3DGS on Jetson Xavier NX ≈ 6.4 fps.
  Axis-shared rasterization (arXiv 2506.07069), Jetson Orin Nano: projection 14.2%, sorting 25.3%, rasterization 60.5% `[secondary]`.
  Jetson Orin NX: 7–17 fps on Mip-NeRF 360 `[secondary]`.
- `[inference]` Rule of thumb: t_B ≈ t_A × (0.6–0.7 × FP32_A/FP32_B + 0.3–0.4 × BW_A/BW_B), at the same resolution and Gaussian count.
  Tensor-core TFLOPS do not belong in this formula. Example, 4090 → base M4: 0.65 × 82.6/4 + 0.35 × 1008/120 ≈ 16× slower on paper. Use *measured* Apple FP32 (~2.9), and
  Metal/WebGPU ports are less tuned than CUDA, so expect worse. Use it as a prior, then replace it with the other agents' measured numbers.
- I found no published sweep of one 3DGS scene across 3090 / 4090 / A100 / A6000. FlashGS (3090 vs A100) is the only cross-GPU data point.

## Dead ends

- WebFetch cannot parse NVIDIA/Tesla PDFs (it returns compressed streams). I worked around it by reading the cached PDF pages as images.
- AnandTech's Hot Chips 31 live blog redirects to the forums (site closed). WikiChip refused the connection. No primary Autonomy Day transcript found.
- The A100 product page has only the 80 GB columns. 40 GB PCIe (250 W) was not confirmed.
- RTX A6000 and RTX 6000 Ada product pages lack bandwidth or tensor details. Their numbers come from datasheet search snippets.
- No official FP32 or dense-FP16 figure for Jetson Thor or DRIVE Thor. The NVIDIA forum thread asking how 2,070 TFLOPS is computed has no staff answer.
- Apple has stated no GPU TFLOPS since M1 and no Neural Engine precision for any chip. The M5 Neural Engine TOPS is not stated.
- No Tesla AI4 or AI5 spec sheet, no TechInsights AI4 teardown text (paywalled).
