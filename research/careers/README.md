# Research-engineer jobs in India for this field

Synthesis written 2026-11-24 from [01-industry-av-india.md](01-industry-av-india.md) and
[02-labs-3d-vision-india.md](02-labs-3d-vision-india.md). Every row in those files was read on the employer's own job
system that day.

The lead session re-checked 10 postings on 2026-11-24 `[measured]`:
- Through the job systems' APIs: Skild AI (Greenhouse), Aeva (Lever), CynLr (Ashby), Bosch (SmartRecruiters).
- By page fetch: Origin ×2 (Workable), Sony Research India (LinkedIn), MultiSet, Qualcomm, IISc VAL.
- All were live.
- Openings close fast, so check again before applying. No industry posting stated a salary.

## Answer

**Yes: about 40 live, relevant roles at about 20 organisations, almost all in Bengaluru, Hyderabad, Pune and Chennai.**
But the title "Research Engineer" is rare. Most roles are perception, ADAS-algorithm, 3D-vision or edge-AI
*engineering* jobs that want 3–8+ years. Research titles are gated by a PhD or first-author papers (Sony), or entered
through academic pre-doc and project posts.

## Shortlist (open on 2026-11-24)

| Organisation | Role | City | Fit with this roadmap |
|---|---|---|---|
| Sony Research India | [Research Engineer / Scientist, CV](https://www.linkedin.com/jobs/view/4491127369/) | Bengaluru / remote-India | multi-view geometry + video generation. **Needs first-author top-venue papers** |
| Skild AI | [Computer Vision AI & ML Engineer](https://job-boards.greenhouse.io/skildai-careers/jobs/5031480008) | Bengaluru | 3D scene understanding, Isaac Sim / Blender |
| Aeva | [Senior Perception Engineer](https://jobs.lever.co/aeva/142f731c-7de5-4978-8d64-33e1132f5570) | Bengaluru | occupancy grids, point clouds, 3D geometry, C++ |
| MultiSet AI | [Senior Research Scientist, ViTs & feed-forward nets](https://multiset.ai/open-roles/senior-research-scientist-vision-transformers) | Bengaluru | visual localisation / SfM. **3DGS + COLMAP named as a plus** |
| Origin | [Lead Perception Engineer](https://apply.workable.com/j/299BD1EDC8) · [Lead AI Engineer](https://apply.workable.com/j/FDDAECC690) | Bengaluru | calibration + real-time 3D perception · diffusion models for photoreal simulation |
| NVIDIA | [Applied Research in Robotics](https://nvidia.wd5.myworkdayjobs.com/NVIDIAExternalCareerSite/job/India-Bengaluru/Senior-Software-Engineer---Applied-Research-in-Robotics_JR2021411) · [AV Platform](https://nvidia.wd5.myworkdayjobs.com/NVIDIAExternalCareerSite/job/India-Pune/Senior-System-Software-Engineer---AV-Platform_JR2029641) | Bengaluru / Pune | perception on accelerators; sensor integration. 5 y |
| Bosch BGSW | [Research Engineer – GenAI & CV](https://jobs.smartrecruiters.com/BoschGroup/744000155700095-research-engineer-generative-ai-and-computer-vision) | Bengaluru | diffusion-model synthetic data, for industrial inspection rather than driving |
| CynLr | [Research Engineer – MTS](https://jobs.ashbyhq.com/cynlr/f87863a4-5c5b-49fa-807e-a8bd9f6de18b) | Bengaluru | CV + optics / GPU; takes undergrad to PhD; "not paper focused" |
| Qualcomm | [Graphics Research Engineer](https://careers.qualcomm.com/careers/job/446715027966) · [Perception validation (XR)](https://careers.qualcomm.com/careers/job/446717877992) | Bengaluru | real-time graphics · SLAM/VIO + calibration |
| Perceptyne | [Computer Vision Engineer](https://perceptyne.keka.com/careers/jobdetails/164320) | Hyderabad | stereo, depth, pose, calibration |
| Aptiv · Valeo · Mercedes-Benz R&D India · ZF | ADAS / AD algorithm roles (see 01) | Bengaluru / Chennai / Hyderabad | fusion, geometric transforms, C++ |

**Academic routes**: research experience on a stipend, often leading to papers or a PhD:
- [IIIT-H CVIT Research Fellow / Engineer](https://faculty.iiit.ac.in/~jawahar/join.html), standing call.
- [IISc Vision & AI Lab Project Assistant](https://val.cds.iisc.ac.in/openings.html), ₹25–45k/month.
- [IIT Hyderabad TiHAN](https://tihan.iith.ac.in/careers.html), ₹18–35k/month.
- IITH 3D digital twin JRF, ₹37k/month, may convert to a PhD.

## What they ask for, against the learning roadmap

| Asked for | Count (industry, of 24 / labs, of 22) | Roadmap stage |
|---|---|---|
| C/C++ | 13 / 11 | 9 |
| Python, PyTorch, training vision models | 12, 9 / 13 | 4 |
| Real-time / edge deployment (TensorRT, ONNX, CUDA, quantisation) | 10 / 13 | 9 |
| Camera / sensor integration, calibration, sync, SLAM, 3D geometry | 8 + 5 + 4 / 7 | 1 |
| Sensor fusion, tracking | 6 / — | 5 |
| Generative models (diffusion) | 2 / 4 | 8 |
| Gaussian splatting / NeRF | 1 / 2 | 2 |
| BEV, occupancy (as a name), feed-forward reconstruction, "world model" | ~0 | 5, 7, 8 |

**Reading:**
- **Stages 1, 4, 5 and 9 get people hired in India today.** Stages 2, 6, 7 and 8 make a CV stand out, but they are not job titles here yet.
- NVIDIA's NuRec, Cosmos and world-model roles are in the US and China (02).

## How to use this (Claude's recommendation)

1. **Turn the TeslaRender builds into a portfolio that matches these postings.** Each build should show measured numbers:
   - Stage 1: calibrate and sync a multi-camera rig (Skild camera systems, Origin, Qualcomm perception validation, Aptiv).
   - Stages 5 + 9: a BEV/occupancy model exported to ONNX/TensorRT, with measured latency on the 5070 Ti (NVIDIA, Aptiv, Bosch, Valeo).
   - Stages 6–7: a reconstructed Indian street, by OmniRe or feed-forward (MultiSet, Sony, Origin's simulation team).
2. **Do at least one real-time piece in C++**, such as the inference runtime or renderer core. C++ appears in about half of all postings.
3. **Pick a track.** Industry engineering roles want 3–5+ years. Research titles want papers. If you want the research
   track without a PhD, the CVIT / IISc / TiHAN pre-doc posts lead to papers.
4. **Contact startups directly.** Minus Zero, Swaayatt, drivebuddyAI and Ola/Krutrim have no readable public job board.
   Minus Zero trains on "millions of unlabelled video frames" (research/market/01), so a multi-camera Indian dataset is
   both a portfolio piece and a conversation opener with a possible employer or buyer.

## Not verified

- LinkedIn and Naukri were not searched comprehensively.
- Requirements for Mercedes-Benz R&D India's three AD roles: the page loads them client-side, so they couldn't be read.
- KPIT and RNTBCI roles: seen only on aggregators.
- Meta India, TCS Research, Krutrim, Flipkart, Avataar: careers pages unreadable.
- Salaries: none posted outside academia.
