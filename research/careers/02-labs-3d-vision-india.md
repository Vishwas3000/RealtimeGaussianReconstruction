# 02: Labs, 3D/generative-vision companies and academia. Research roles in India that fit this roadmap

Researched 2026-11-24 in a light web pass. I read postings through each employer's own job system where it is public:
Greenhouse, Ashby, Workable, Recruitee, Workday (India location facet), Eightfold PCSX (Qualcomm, Microsoft), amazon.jobs,
Google Careers page data, institute pages, IIT Delhi's IRD JSON API and LinkedIn's public guest page. I used search snippets
everywhere else. I did not apply, log in or contact anyone. File [01](01-industry-av-india.md) covers AV/ADAS/robotics
industry; 6 rows below also appear there (marked "also in 01").
Tags: **[primary]** = posting read at the source today and open. **[secondary]** = search snippet or aggregator.
**[UNCERTAIN]** = could not open or confirm. Salaries appear only where the posting states them (academia only).

## TL;DR
- **Yes, but few research roles sit in this exact field.** I found 22 live postings or standing calls at 13 organisations.
  Only Sony Research India's CV Research Engineer/Scientist asks for both camera geometry (multi-view, calibration, bundle
  adjustment) and generative video. MultiSet AI's visual-localisation scientist role lists 3DGS/COLMAP as a plus.
- **The roadmap's headline topics barely appear in Indian postings.** Gaussian splatting or NeRF is named in 2 of 22.
  BEV/occupancy, feed-forward reconstruction and "world model" are named in 0. Employers ask for model training (13 of 22),
  real-time/edge deployment (13) and camera geometry, calibration or SLAM (7).
- **A PhD and papers gate the research titles, not the engineering ones.** A PhD is strictly required in 1 posting, plus
  TiHAN's postdoc track. First-author top-venue papers are mandatory in 1 (Sony) and one route of two in 1 (Origin).
  16 of 22 accept a bachelor's or state no degree, but 8 want 5+ years.
- **The way in without a PhD or years of experience is academic pre-doc and project roles.** Options: CVIT Research
  Fellow/Engineer (standing call), IISc VAL Project Assistant (₹25–45k/month), TiHAN JRAF (₹18–22k) and the IITH 3D-digital-twin
  JRF (₹37k, may convert to a PhD). No industry posting here states pay.
- **The big labs have nothing in this field today.** Google DeepMind India, MSR India and Adobe Research India have no
  vision/3D opening. Samsung SRI-B has only a general pool. I could not verify Meta, TCS Research, Krutrim, Flipkart or Avataar.

## Live roles (open as of 2026-11-24)
R = research, R/E = research engineering, E = engineering.

| Organisation | Role | City | Type | Key requirements | Posted / deadline | Link | Tag |
|---|---|---|---|---|---|---|---|
| Sony Research India | Research Engineer / Scientist, Computer Vision | Bengaluru (remote in India) | R | PhD + 0–4 y or MS + 3–6 y; **first-author CVPR/ICCV/ECCV/NeurIPS papers mandatory**; diffusion, flow matching, video generation; detection/tracking; multi-view geometry, camera models, calibration, bundle adjustment; PyTorch multi-GPU | ~2026-11-17 ("1 week ago") | [LinkedIn 4491127369](https://www.linkedin.com/jobs/view/4491127369/), linked from [sonyresearchindia.com/careers](https://www.sonyresearchindia.com/careers/) | [primary] |
| MultiSet AI | Senior Research Scientist, Vision Transformers & Feed-Forward Networks | Bengaluru (hybrid) | R | MS/PhD or equivalent; 5+ y applied research with one model shipped; ViTs trained from scratch; visual localisation, SLAM, SfM, retrieval; distillation/quantisation, CoreML/LiteRT; nice to have: 3DGS or COLMAP, papers | undated, listed today | [multiset.ai](https://multiset.ai/open-roles/senior-research-scientist-vision-transformers) | [primary] |
| Qualcomm | Graphics Research Engineer – Staff (Adreno graphics research) | Bengaluru | R/E | BE + 4 y / MS + 3 y / PhD + 2 y (one block says 8+ y; prefers MS + 7 y); ray tracing, mesh shading, anti-aliasing, super-resolution; Vulkan/DirectX/GLES; RenderDoc, Nsight | 2026-11-12 | [446715027966](https://careers.qualcomm.com/careers/job/446715027966) | [primary] |
| Qualcomm | Staff Engineer – Perception System Validation (XR Research) | Bengaluru | E | BE + 4 y minimum, 9+ y preferred; validate SLAM/VIO; camera–IMU calibration; linear algebra, geometry, Python; GTSAM, Ceres, OpenCV, ROS | 2026-04-09 | [446717877992](https://careers.qualcomm.com/careers/job/446717877992) | [primary] |
| Qualcomm | XR Software Engineer (all levels) | Bengaluru | E | BE + 2–10 y / MS + 1–9 y; modern C++ (11–20); ship CV algorithms in XR products; CPU/GPU/DSP; graphics pipeline | 2026-09-11 | [446721052756](https://careers.qualcomm.com/careers/job/446721052756) | [primary] |
| Qualcomm | R&D Engineer / Senior R&D Engineer, XR AI Software & Systems | Bengaluru | R/E | BE + 2–3 y / MS + 1–2 y / PhD; PyTorch, ExecuTorch, ONNX; quantise, prune and optimise CV/LLM/LVM graphs for wearables | 2026-09-09 / 2026-10-12 | [446715899384](https://careers.qualcomm.com/careers/job/446715899384), [446721205700](https://careers.qualcomm.com/careers/job/446721205700) | [primary] |
| Qualcomm | Lead Engineer, Senior – Computer Vision (multimedia) | Bengaluru | R/E | MS + 6 y; CV, DL, signal processing; fixed-point C/C++ models for hardware (also in 01) | 2026-07-14 | [446719658549](https://careers.qualcomm.com/careers/job/446719658549) | [primary] |
| NVIDIA | Senior Software Engineer – Applied Research in Robotics | Bengaluru | R/E | BS/MS/PhD + 5 y; perception, sensor fusion; C/C++; map camera/LiDAR/IMU workloads onto the PVA accelerator (also in 01) | 2026-07-23 | [JR2021411](https://nvidia.wd5.myworkdayjobs.com/NVIDIAExternalCareerSite/job/India-Bengaluru/Senior-Software-Engineer---Applied-Research-in-Robotics_JR2021411) | [primary] |
| NVIDIA | Senior Deep Learning Research Engineer – Multimedia GPU (audio-first) | Bengaluru / Pune | R | **PhD + 10 y**; diffusion, transformers, VAEs, "NeRFs / 3D Gaussian Splatting"; distributed training; edge deployment (also in 01) | 2026-06-27 | [JR2020216](https://nvidia.wd5.myworkdayjobs.com/NVIDIAExternalCareerSite/job/India-Bengaluru/Senior-Deep-Learning-Research-Engineer---Multimedia-GPU-team_JR2020216) | [primary] |
| Skild AI | Computer Vision AI & ML Engineer | Bengaluru | R/E | PyTorch/TF/JAX; detection, segmentation, tracking, 3D scene understanding; 3D geometry, RGB-D/LiDAR/stereo fusion; Isaac Sim, Blender (also in 01) | first 2025-12-11, updated 2026-06-30 | [GH 5031480008](https://job-boards.greenhouse.io/skildai-careers/jobs/5031480008) | [primary] |
| Skild AI | Camera Systems Software Engineer – India | Bengaluru | E | BS/MS + 5 y embedded cameras; MIPI/GMSL; calibration, sync, timestamps; low-latency pipelines on Tegra (also in 01) | 2026-06-15 | [GH 5263541008](https://job-boards.greenhouse.io/skildai-careers/jobs/5263541008) | [primary] |
| Origin (ex-10xConstruction) | Lead Perception Engineer | Bengaluru | E | 5+ y; real-time 3D perception from LiDAR, IMU, stereo, RGB; target-based, targetless and online calibration; SLAM basics; C++, PyTorch, TensorRT | 2026-10-23 | [Workable 299BD1EDC8](https://apply.workable.com/j/299BD1EDC8) | [primary] |
| Origin | Lead AI Engineer (AI Research team) | Bengaluru | R/E | 8+ y, or PhD/MS **with strong publications**; diffusion (DDPM/LDM/ControlNet) for photoreal simulation; VLM/VLA; INT8, TensorRT, ONNX; CUDA | 2026-10-30 | [Workable FDDAECC690](https://apply.workable.com/j/FDDAECC690) | [primary] |
| CynLr | Research Engineer – Member of Technical Staff | Bengaluru | R | PhD/postdoc down to UG/PG; tracks include CV + optics and HPC/GPU; joint research with IISc and EPFL; "Not paper focused" (also in 01) | 2026-08-11 | [Ashby](https://jobs.ashbyhq.com/cynlr/f87863a4-5c5b-49fa-807e-a8bd9f6de18b) | [primary] |
| Amazon | Applied Scientist, Alexa Edge AI | Bengaluru | R/E | PhD, or MS + 3 y; CV, audio and multimodal models for edge and cloud; pruning, quantisation, distillation | 2026-05-27 (2nd req. 2026-10-09) | [10432009](https://www.amazon.jobs/en/jobs/10432009/applied-scientist-alexa-edge-ai), [10575107](https://www.amazon.jobs/en/jobs/10575107/applied-scientist-alexa-edge-ai) | [primary] |
| Amazon | Applied Scientist II, Grocery Retail & In-Store Experience | Bengaluru | R/E | 2+ y ML; CV for product identification and shelf perception; research to production; latency profiling | 2026-10-09 | [10575126](https://www.amazon.jobs/en/jobs/10575126/applied-scientist-ii-grocery-retail-in-store-experience-graise) | [primary] |
| Glance (InMobi) | SDE IV – GPU Engineer | Bengaluru | E | 5+ y; CUDA, Triton, C++; inference runtimes for Stable Diffusion, multimodal transformers and video-generation models; NCCL | first 2025-10-09, still listed | [GH 7213752](https://job-boards.greenhouse.io/glance/jobs/7213752) | [primary] |
| Samsung R&D Institute Bangalore | "Careers @ SRI-B" talent pool (Vision CoE: computational imaging, multi-frame, stabilisation, restoration; XR) | Bengaluru | R/E | general pool; no role-specific description | open until 2027-06-30 | [Workday R114583](https://sec.wd3.myworkdayjobs.com/Samsung_Careers/job/Phoenix-Building-Bangalore-India/Careers---SRI-B_R114583) | [primary] |
| IIIT Hyderabad, CVIT (Prof. C. V. Jawahar) | Research Engineer / Jr Engineer; Research Fellow (pre-doc, 1–2 y) | Hyderabad (on-site) | R/E, R | strong programming; recent graduates welcome as RF; apply by email with the role number | standing call, undated | [join page](https://faculty.iiit.ac.in/~jawahar/join.html) | [primary] |
| IISc, Vision & AI Lab (Prof. R. Venkatesh Babu) | Project Assistant, CV/DL | Bengaluru | R | B.Tech/M.Tech (final-year OK); linear algebra, probability, DL coursework; Python, C++, PyTorch; expected to aim at top-tier papers; **₹25,000–45,000/month**, at least 8 months | standing call, undated | [openings](https://val.cds.iisc.ac.in/openings.html) | [primary] |
| IIT Hyderabad, TiHAN (autonomous navigation hub) | Junior / Senior Research Assistant Fellow (AI/ML track); Post-Doctoral Fellow | Hyderabad | R | JRAF: B.Tech ≥ 60 % + 1–2 y, **₹18–22k/month**; SRAF: B.Tech + 4–5 y or M.Tech + 2–3 y, **₹32–35k**; PDF: PhD, 0–3 y, **₹60k**; sensor fusion, real-time AI, ROS | posted 2025-12-30, rolling | [careers](https://tihan.iith.ac.in/careers.html) | [primary] |
| IIT Hyderabad, Centre for Geo-Digital Twins | JRF ×6, 3D digital twin of Hyderabad's core urban region | Hyderabad | R | Bachelor's/Master's (GIS, CS, design…), 0–3 y; QA of LiDAR, oblique photogrammetry and LoD 2–4 city models; **₹37,000/month**; may convert to a PhD | posted 2026-01-19, rolling (reviewed every 15 days) | [PDF](https://iith.ac.in/assets/files/careers/staff/advertisement_hmda_project_design_department_iith_2026.pdf) | [primary] |
| Unmannd Autonomy | Lead – Perception (defence UAVs) | Bengaluru | E | vision/LiDAR/radar fusion, SLAM, 3D reconstruction; team lead | "posted 6+ months ago", apply button live | [Accel board](https://jobs.accel.com/companies/unmannd-autonomy/jobs/72909395-lead-perception-uavs) | [secondary] |
| Bhatiyani Astute Intelligence | 3D Reconstruction & Generative AI Engineer (jewellery) | Bengaluru | R/E | 2–5 y; multi-view and single-view 3D; text/image-to-3D; NeRF/3DGS; watertight meshes | 2026-04-04 on an aggregator | [getmereferred](https://getmereferred.com/in/job-listing/3d-reconstruction-generative-ai-engineer-bhatiyani-astute-intelligence-inkabengaluru-2-to-5-years-experience-a3191639-3f65-4416-94fa-a7babaf7a6fa) | [secondary] |

## What these employers ask for (counts over the 22 [primary] rows, my reading of each posting)
- **Degree.** A PhD is strictly required in 1 row (NVIDIA multimedia), plus TiHAN's postdoc track. PhD *or* MS + years is
  required in 5 rows (Sony, MultiSet, Origin Lead AI, Amazon Alexa, Qualcomm CV lead). 16 accept a bachelor's or state no degree.
- **Publications.** Mandatory in 1 row (Sony: first-author CVPR/ICCV/ECCV/NeurIPS/ICML/ICLR or TPAMI/TIP/IJCV). One of two
  routes in 1 row (Origin Lead AI). A plus or an expected output in 5 rows (MultiSet, CVIT RF, IISc VAL, TiHAN PDF, IITH JRF).
  Explicitly "not paper focused" in 1 (CynLr). Not mentioned in 14.
- **Experience (stated minimum).** 0–2 y or final-year welcome: 7 rows (Sony with a PhD, Qualcomm XR SW, CynLr, CVIT,
  IISc VAL, TiHAN JRAF, IITH JRF). 2–4 y: 5 rows (Qualcomm graphics, perception validation and XR AI; Amazon ×2). 5+ y: 8 rows.
  Not stated: 2 rows (Skild CV, SRI-B pool).
- **Skills.** C/C++ is named in 11 rows. PyTorch is named in 7. CUDA, TensorRT, ONNX, CoreML or a vendor accelerator is named
  in 6. Multi-GPU or distributed training is named in 5. Linear algebra, probability or optimisation is named in 4. ROS is named in 4.

| Roadmap stage | Rows (of 22) | Which |
|---|---|---|
| 1 Camera geometry (calibration, SLAM, SfM, multi-view) | 7 | Sony, MultiSet, Qualcomm perception validation, Skild CV, Skild camera, Origin perception, IITH digital twin |
| 2 Gaussian splatting / NeRF | 2 | MultiSet (nice to have), NVIDIA multimedia (listed among generative methods) |
| 3 Real-time graphics | 2 | Qualcomm graphics research (ray tracing, Vulkan/DirectX), Qualcomm XR SW (graphics pipeline) |
| 4 Deep-learning toolkit (training models) | 13 | Sony, MultiSet, Qualcomm XR AI, Qualcomm CV, NVIDIA multimedia, Skild CV, Origin ×2, Amazon ×2, CVIT, IISc VAL, TiHAN |
| 5 BEV/occupancy and 3D perception | 5 (0 name BEV or occupancy) | Skild CV, Origin perception, NVIDIA robotics, TiHAN, Qualcomm perception validation |
| 6 Dynamic scene reconstruction | 0 | The nearest is the IITH digital twin, which is a static, survey-grade city model |
| 7 Feed-forward reconstruction | 0 | MultiSet's "feed-forward" means transformer MLP blocks and pose regression, not feed-forward splats |
| 8 Generative / world models | 4 generative, 0 "world model" | Sony (video generation), Origin (diffusion simulation, VLA), NVIDIA multimedia, Glance (serving video models) |
| 9 Real-time systems (edge, quantisation, GPU runtimes) | 13 | Sony, MultiSet, Qualcomm XR AI, Qualcomm CV, NVIDIA robotics, Skild ×2, Origin ×2, Amazon ×2, Glance, TiHAN |

Reading: stages 1, 4 and 9 get people hired in India today. Stages 2, 6, 7 and 8 are where the field is heading, and
in India they are mostly a differentiator on a CV, not a job title.

## Organisations checked with no relevant opening
- **Google / Google DeepMind (India)**: I parsed 124 India results across 11 queries. DeepMind India has a Post-Doctoral
  Researcher role (PhD, HCI research, Bengaluru) and Gemini-app software engineer roles (LLM). "Student Researcher, 2027" is
  for enrolled students; CV is among its listed areas. No vision/3D role. [primary]
- **Microsoft Research India**: a Senior Researcher role (AI/ML; PhD mandatory; 3 letters; 2026-11-04), not vision-specific.
  The Research Fellow and Postdoc openings (2026-08-20) are in the FoSSE team (code migration, PL, RL post-training).
  The "applied scientist" query was rate-limited (HTTP 429). [primary]
- **Adobe Research (Bengaluru) / MDSR (Noida)**: I read all 49 India listings. The only research ones are MDSR's Research
  Scientist IV (NLP/marketing) and a 2027 Research PhD Intern role (current PhD students only). [primary]
- **NVIDIA**: I read all 232 India listings. Beyond the two above, the nearest are AI DevTech Engineer (Bengaluru; MS/PhD + 2 y;
  GPU deep-learning optimisation) and DRIVE/AV roles (see 01). The NuRec, Cosmos and "Interactive World Models" roles are in
  the US and China. [primary]
- **Qualcomm** also has GPU Architecture & AI/ML Engineer for IIT/NIT freshers (0–3 y, 2026-11-04). It is adjacent to stage
  3/9 and is hardware-side. [primary]
- **Amazon**: 47 India hits; only the 2 above are CV. **Samsung SRI-B**: its other 36 Workday listings are semiconductor
  roles. **Glance**: its other scientist roles are recommender systems. [primary]
- **Sarvam AI**: 39 Ashby roles, none in vision. The adjacent stage-9 roles are Performance Engineer, Inference / Kernels
  (Bengaluru, 2026-08-10). [primary] **Lenskart**: 86 Recruitee offers. Its "AR/AI Engineer" is a 3D-artist job
  (Blender/Maya, 1–3 y). [primary]
- **Meta India** (careers site not scriptable; search found no India CV research posting), **TCS Research** (tcs.com 403;
  only US "AI Researcher" listings), **Krutrim** (careers pages 404; undated aggregator listings only), **Flipkart**
  (only aggregator CV/AR listings), **Avataar** (careers page 404; Outscal/Wellfound listings, some from 2024): [UNCERTAIN].
- **IIIT Hyderabad** central R&D page: every 2026 ad is closed (the last ended 2026-08-31). The INAI site did not resolve.
  CDIT has a healthcare-AI Research Scientist role (PhD). **IISc** central project page: 2 of 11 ads are open, neither in vision.
  The ARTPARK careers page is "being rebuilt", and vcl.iisc.ac.in did not resolve.
- **IIT Delhi** IRD API: 626 ads, 10 open, none in vision. The nearest is AI for NAFLD diagnosis (EE, closes 2026-11-30).
  IHFC has only an F&A role. **IIT Bombay**: the IRCC search is a SAP WebDynpro app that I could not script. BharatGen points
  to LinkedIn. A "Computer Vision and Estimation Engineer" (drone project, May 2026) appears only on aggregators [UNCERTAIN].
  **IIT Madras**: both careers portals are JS apps. CoERS "Computer Vision Engineer" is undated and GIS-heavy (1–2 y),
  a low fit.

## Dead ends
- **Sarvam "Researcher, Vision" (Bengaluru)**: the Khosla job board says it is no longer accepting applications, and the
  Ashby page is 404.
- **Sony Research India**: the "Multimodal AI Consultant" role is closed on LinkedIn. Its "Senior Research Engineer" role is
  open but is for recommender systems.
- **IIIT-H CVIT ANRF PM-ECRG Project Associate-I + Postdoc**: closed 2026-07-15.
- **IITH CSE RA (DL/CV/XAI)**: B.Tech ≥ 70 %, ₹25,000/month, could convert to MTech/PhD; closed 2026-07-31.
- **IITH CSE RA-I (CV surveillance)**: PhD + 5 y, ₹58,000 + HRA; the April 2026 ad is no longer listed.
- **IITH "AI Medical Imaging Engineer"** (ultrasound CV): closes today, 2026-11-24.
- **IIT Madras Postdoc, Computer Vision (3D vision)**: closed 2026-09-24 [secondary]. **IIT Mandi iHub Computer Vision
  Engineer** (calibration, triangulation, 3D reconstruction): apply-by date was 2026-07-12, and its PDF is now 404 [secondary].
- **Krutrim's "Multimodal and Vision AI Research Engineer/Scientist"** was in Palo Alto (2025) [secondary].
  **DeepMind's Greenhouse board** (`deepmind`) returns 404; its roles are on Google Careers.
- **Method trap**: Workday shows multi-city roles as "N Locations" and returns `total` only on page 1. Filter by the tenant's
  India location facet, not a city keyword. A city-keyword search missed NVIDIA's multimedia role at first.
