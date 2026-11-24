# 01: Industry. AV, ADAS and robotics jobs in India that fit this roadmap

Researched 2026-11-24 in a light web pass. I fetched the companies' own job systems where they are public: the Greenhouse,
Lever, Ashby, Workday, SmartRecruiters, Keka, Zoho Recruit, Eightfold and Mercedes-Benz job APIs. I used search snippets
everywhere else. I did not apply, log in or contact anyone.
Tags: **[primary]** means I read the posting through the company's own job system today and it was open.
**[secondary]** means a search snippet or a job aggregator. **[UNCERTAIN]** means I could not open or confirm the source.
No posting in this file states a salary.

## TL;DR
- **Yes, but "Research Engineer" is a rare title in Indian AV and robotics.** I verified 27 live, relevant roles at 13 companies
  at the source. Most are perception, ADAS-algorithm or platform engineering jobs that ask for 3–8+ years. The research-flavoured
  ones are Bosch BGSW "Research Engineer – Generative AI and Computer Vision", NVIDIA "Applied Research in Robotics", Valeo's
  AD-algorithm research role in Chennai, CynLr "Research Engineer – MTS" and Perceptyne "Robotics Research Engineer".
- **Closest to this roadmap:**
  - Skild AI: CV AI & ML Engineer (3D scene understanding, Isaac Sim).
  - Aeva: Senior Perception Engineer (occupancy grids, point clouds, 3D geometry).
  - NVIDIA: DriveAV, AV Platform, and robotics on the PVA accelerator.
  - Perceptyne: Computer Vision Engineer (stereo, depth, pose).
  - Aptiv: ADAS algorithm role (fusion, geometric transforms).
- **The roadmap's frontier topics barely appear in Indian postings.**
  - Gaussian splatting or NeRF: only one posting names it, and it is NVIDIA's audio-focused, PhD + 10-year role.
  - BEV: no posting names it.
  - Occupancy: only as "occupancy grids" (Aeva).
  - Feed-forward reconstruction and dynamic-scene reconstruction: none.
  - World models: only KPIT ("world foundation models"), and only on aggregators [secondary].
- **What gets you hired is stages 4, 5, 9 and 1.** Across the 24 postings whose text I read, the most requested skills were
  C/C++ (13), Python (12), real-time or embedded optimisation (10), deep learning for vision (9), multi-sensor integration
  (8) and sensor fusion or tracking (6). Stages 2, 6, 7 and 8 set you apart. They do not get you in the door.
- **Most Indian startups on the list could not be verified.** Minus Zero, Swaayatt, drivebuddyAI, Ola/Krutrim, Ather and
  Addverb have no public applicant-tracking system, block scripts, or have known postings that return 404. Several
  research-style postings found by search are already closed, at MBRDI, ZF, GM, Harman and Qualcomm (see the last section).

## Live roles (all open on 2026-11-24)
R = research-flavoured, E = engineering. "Posted" is the system's publish or start date.

| Company | Role | City | R/E | Key requirements (from the posting) | Posted | Link | Tag |
|---|---|---|---|---|---|---|---|
| NVIDIA | Senior Software Engineer, DriveAV – Autonomous Vehicles | Bengaluru | E | BS/MS + 5 y; integrate ACC/AEB/APA on production platforms; static vs online calibration; log/replay + KPI validation; plus camera/radar/lidar and how perception, planning and control fit together | 2026-04-14 | [JR2016077](https://nvidia.wd5.myworkdayjobs.com/NVIDIAExternalCareerSite/job/India-Bengaluru/Senior-Software-Engineer--DriveAV---Autonomous-Vehicles_JR2016077) | [primary] |
| NVIDIA | Senior Software Engineer – Applied Research in Robotics | Bengaluru | R/E | BS/MS/PhD + 5 y robotics/CV/perception; C/C++; map algorithms onto the PVA vision accelerator (VLIW/SIMD); memory/DMA/real-time; Linux/QNX; ROS 2; plus CUDA, Jetson/DRIVE | 2026-07-23 | [JR2021411](https://nvidia.wd5.myworkdayjobs.com/NVIDIAExternalCareerSite/job/India-Bengaluru/Senior-Software-Engineer---Applied-Research-in-Robotics_JR2021411) | [primary] |
| NVIDIA | Senior System Software Engineer – AV Platform | Pune / Bengaluru | E | BS/MS + 5 y; C++/C/Python; Linux/QNX/ROS/RTOS; integrate cameras, LIDAR, RADAR, GPS, IMU, CAN; performance; AV/robotics/CV background | 2026-11-19 | [JR2029641](https://nvidia.wd5.myworkdayjobs.com/NVIDIAExternalCareerSite/job/India-Pune/Senior-System-Software-Engineer---AV-Platform_JR2029641) | [primary] |
| NVIDIA | Senior Test Developer – Automotive Simulation Testing & Failure-Triage Lead | Pune / Bengaluru | E | B.Tech + 8–12 y; HIL/SIL and simulation testing; L2–L4 validation across perception, localization, planning; Python; git bisection | 2026-09-11 | [JR2022975](https://nvidia.wd5.myworkdayjobs.com/NVIDIAExternalCareerSite/job/India-Pune/Senior-Test-Developer---Automotive-Simulation-Testing---Failure-Triage-Lead_JR2022975-1) | [primary] |
| NVIDIA | Senior Deep Learning Research Engineer – Multimedia GPU (audio focus; adjacent) | Bengaluru / Pune | R | PhD + 10 y; diffusion, GANs, transformers, VAEs, "NeRFs / 3D Gaussian Splatting"; distributed training; edge deployment | 2026-06-27 | [JR2020216](https://nvidia.wd5.myworkdayjobs.com/NVIDIAExternalCareerSite/job/India-Bengaluru/Senior-Deep-Learning-Research-Engineer---Multimedia-GPU-team_JR2020216) | [primary] |
| NVIDIA | Senior System Software Engineer, Deep Learning Accelerator (adjacent) | Bengaluru | E | BS/MS + 12 y low-level systems; C; threads and virtual memory; multithreaded debugging | 2026-08-10 | [JR2014631](https://nvidia.wd5.myworkdayjobs.com/NVIDIAExternalCareerSite/job/India-Bengaluru/Senior-System-Software-Engineer--Deep-Learning-Accelerator-_JR2014631) | [primary] |
| Waymo | Senior Software Engineer, Compute Software | Bengaluru | E | BS/MS + 5 y; modern C++; HIL test harnesses; runtime for custom silicon; Linux, Python/Bash, CI/CD; reports to a Staff ML Compiler Engineer | 2026-09-03 | [8173977](https://careers.withwaymo.com/jobs?gh_jid=8173977) | [primary] |
| Waymo | Technical Specialist – ML Data (adjacent) | Hyderabad | E | 6 y in ML-data annotation, taxonomy or labelling ops; turns ML needs into labelling policy and golden datasets | 2026-09-22 | [8221724](https://careers.withwaymo.com/jobs?gh_jid=8221724) | [primary] |
| Aeva | Senior Perception Engineer | Bengaluru | E | MS/PhD + 3 y real-time perception; detection, clustering, **occupancy grids**, data association, tracking; Kalman/Bayesian; fusion with LiDAR/IMU/GNSS/camera; point clouds and meshes; linear algebra and 3D geometry; C++ | 2026-10-12 | [Lever](https://jobs.lever.co/aeva/142f731c-7de5-4978-8d64-33e1132f5570) | [primary] |
| Aeva | Senior LiDAR Algorithms Engineer | Bengaluru | E | LiDAR DSP, detection, ranging, calibration, point clouds; clustering, tracking and detection on LiDAR data | 2026-06-09 | [Lever](https://jobs.lever.co/aeva/1084b26f-5c62-4ba5-8e0d-c1888471959c) | [primary] |
| Skild AI | Computer Vision AI & ML Engineer | Bengaluru | R/E | "Applied research with hands-on engineering"; detection, segmentation, tracking, **3D scene understanding**; PyTorch/TF/JAX; 3D geometry; RGB-D/LiDAR/stereo fusion; Isaac Sim / Gazebo / Blender | 2025-12-11 (updated 2026-06-30) | [GH 5031480008](https://job-boards.greenhouse.io/skildai-careers/jobs/5031480008) | [primary] |
| Skild AI | Camera Systems Software Engineer – India | Bengaluru | E | Camera bring-up on NVIDIA Tegra; drivers; calibration; synchronisation and timestamps; low-latency pipelines | 2026-06-15 | [GH 5263541008](https://job-boards.greenhouse.io/skildai-careers/jobs/5263541008) | [primary] |
| Bosch (BGSW) | Research Engineer – Generative AI and Computer Vision (industrial inspection; 2 postings) | Bengaluru | R | PhD/MS/MTech (IIT/IIIT/IISc-level) + 3 y; PyTorch; ViT/DETR; **diffusion/GAN/VAE synthetic data**; detection/segmentation | 2026-10-15 and 2026-07-27 | [SR 744000155700095](https://jobs.smartrecruiters.com/BoschGroup/744000155700095-research-engineer-generative-ai-and-computer-vision) | [primary] |
| Bosch (BGSW) | Applied Computer Vision Engineer – Data Driven Development (ADAS perception data) | Bengaluru | E | BE + 6–10 y; Azure ML pipelines over millions of images; PyTorch/TF train/eval; Databricks/Ray; Docker; plus ADAS/AD, TensorRT/ONNX, C++ | 2026-09-17 | [SR 744000150051588](https://jobs.smartrecruiters.com/BoschGroup/744000150051588-applied-computer-vision-engineer-data-driven-development) | [primary] |
| Aptiv | Technical Engineer – Software, Algorithm (C++ & ADAS), 6–14 y | Bengaluru | E | Perception algorithms (fusion, state estimation, prediction) in C++/Python; tracking filters, data association; **coordinate systems, geometric transforms**, numerical methods | 2026-11-19 | [J000706541](https://aptiv.wd5.myworkdayjobs.com/APTIV_CAREERS/job/Bangalore-India/Technical-Engineer---Software---Algorithm--C-----ADAS----6--14-Yrs_J000706541) | [primary] |
| Aptiv | Advanced Software Engineer – C++ Simulation | Bengaluru | E | 6–9 y (4 y C++); re-simulation of ADAS algorithms on large datasets; HPC/cloud Linux; triage of AI/ML perception | 2026-11-10 | [J000704017](https://aptiv.wd5.myworkdayjobs.com/APTIV_CAREERS/job/Bangalore-India/Advanced-Software-Engineer--C---Simulation_J000704017) | [primary] |
| Mercedes-Benz R&D India | Senior Engineer for AD SW Algo2 | Bengaluru | E | Requirements not retrieved: the job page renders client-side; title and dates came from the job API | 2026-11-24 (closes 12-24) | [MER00048NQ](https://jobs.mercedes-benz.com/senior-engineer-for-ad-sw-algo2-241692-MER00048NQ) | [primary] |
| Mercedes-Benz R&D India | AI/ML Engineer | Bengaluru | E | Not retrieved (as above) | 2026-11-20 | [MER0004AL6](https://jobs.mercedes-benz.com/ai-ml-engineer-247844-MER0004AL6) | [primary] |
| Mercedes-Benz R&D India | Senior Engineer AD Driving Functions | Bengaluru | E | Not retrieved (as above) | 2026-11-11 | [MER0004ABH](https://jobs.mercedes-benz.com/senior-engineer-ad-driving-functions-246142-MER0004ABH) | [primary] |
| Valeo India | "Discipline Engineer" (URL slug: Artificial-Intelligence-Engineer) | Chennai | R | "Research, develop, benchmark … state of the art algorithms for autonomous driving"; new vision sensors; DL frameworks; embedded targets; patents; no years stated | Started 2026-06-05 (requisition dated 2025-10-06) | [REQ2025063830](https://valeo.wd3.myworkdayjobs.com/valeo_jobs/job/Chennai/Artificial-Intelligence-Engineer_REQ2025063830) | [primary] |
| Valeo India | Software Architect (vision ADAS on automotive SoC) | Chennai | E | SoC software architecture; real-time; ISO 26262; vision ADAS, CV, C++; "state-of-the-art research into deep learning & Computer vision" | 2026-04-03 | [REQ2025068260](https://valeo.wd3.myworkdayjobs.com/valeo_jobs/job/Chennai/Software-Architect_REQ2025068260) | [primary] |
| LightMetrics | Software Engineer – AI | Bengaluru | R/E | Image/video experience required; production C++; OpenCV; TF/PyTorch; plus profiling and optimisation | 2026-09-16 | [lightmetrics.ai](https://www.lightmetrics.ai/career/software-engineer---ai) | [primary] |
| CynLr | Research Engineer – Member of Technical Staff ("Algorithm Research") | Bengaluru | R | Tracks: CV + physics of light/optics; HPC/GPU (architecture, compilers, OS); ML/RL; controls. PhD to UG all considered; "Not Jugaad" | 2026-08-11 | [Ashby](https://jobs.ashbyhq.com/cynlr/f87863a4-5c5b-49fa-807e-a8bd9f6de18b) | [primary] |
| Perceptyne | Computer Vision Engineer — L3/L4 (humanoid robots) | Hyderabad | E | 5 y; calibration, RGB/stereo/depth, 2D/3D detection, **pose estimation, registration**, visual servoing, sensor fusion, real-time pipelines | 2026-10-09 | [Keka 164320](https://perceptyne.keka.com/careers/jobdetails/164320) | [primary] |
| Perceptyne | Robotics Research Engineer (L4) — Physical AI & Robot Learning | Hyderabad | R | 5 y; evaluate, fine-tune and deploy robot-learning models on real robots; compare against classical CV and planning | 2026-10-12 | [Keka 164339](https://perceptyne.keka.com/careers/jobdetails/164339) | [primary] |
| Qualcomm India | Lead Engineer, Senior – Computer Vision (mobile multimedia; adjacent) | Bengaluru | R/E | MS + 6 y; CV, DL, signal processing; fixed-point C/C++ models for hardware | 2026-07-14 | [446719658549](https://careers.qualcomm.com/careers/job/446719658549) | [primary] |
| ZF (Capricore India) | Specialist – Algorithm & Functions for ADAS/AD (hands-free driving) | Hyderabad | E | 5 y ADAS/AD algorithms in C; camera/radar/DMS; lane change, vehicle dynamics; simulation tests | 2026-11-11 | [Req 90589](https://jobs.zf.com/job/Hyderabad-Specialist-Algorithm-&-Functions-for-ADASAD%29-TG-500032/1428575133/) | [primary] |
| KPIT | AI/ML, Robotics and Computer Vision with ADAS (C++/Python) Experts | Bengaluru | R/E | Snippet: "world foundation models for scene understanding, motion prediction"; 4 y AD or real-time perception; PyTorch | Unknown | [foundit](https://www.foundit.in/job/ai-ml-robotics-and-computer-vision-with-adas-c-python-experts-kpit-engineering-bengaluru-bangalore-61671422) | [secondary] |
| KPIT | C++ AI/ML System Development Experts | Bengaluru / Pune | E | Snippet: 8–12 y; end-to-end perception-to-control models; camera/radar/LiDAR | Unknown | [foundit](https://www.foundit.in/job/c-ai-ml-system-development-experts-kpit-bengaluru-bangalore-47696926) | [secondary] |
| RNTBCI | Senior Engineer – ADAS | Chennai | E | Snippet only | 2026-01-09 per hirist | [hirist](https://www.hirist.tech/j/renault-nissan-technology-and-business-centre-senior-engineer-adas-1599481) | [secondary] |

## Skills most often requested
Counts are over the **24 [primary] postings whose text I read**. The three MBRDI rows have no text. One posting can count
under several skills.

| Skill (as the postings phrase it) | Postings | Roadmap stage |
|---|---|---|
| C/C++ (incl. plain C) | 13 | 9 real-time systems |
| Python | 12 | 4 deep-learning toolkit |
| Real-time or embedded performance (RTOS/QNX, accelerators, profiling, fixed point, low latency) | 10 | 9 |
| Deep learning for vision (PyTorch/TF; CNNs, transformers, detection, segmentation) | 9 | 4 |
| Multi-sensor hardware: camera, LiDAR, radar, IMU integration | 8 | 1 + 5 |
| Sensor fusion, state estimation, tracking, data association (Kalman/Bayesian) | 6 | 5 BEV/occupancy perception |
| 3D geometry: coordinate transforms, point clouds, stereo/depth, pose, registration | 5 | 1 camera geometry |
| Simulation, re-simulation, HIL/SIL testing | 5 | not in roadmap (closest: 8, 9) |
| Camera or sensor calibration and time sync | 4 | 1 |
| ML data pipelines, labelling, synthetic data | 4 | 4 / 8 |
| ROS / ROS 2 | 3 | 9 |
| Model deployment (TensorRT/ONNX, edge) | 3 | 9 |
| Generative models (diffusion/GAN/VAE) | 2 | 8 world models |
| NeRF / 3D Gaussian splatting | 1 | 2 Gaussian splatting |
| Occupancy grids | 1 | 5 |
| BEV; dynamic scene reconstruction; feed-forward 3D reconstruction; game-engine rendering | 0 | 5, 6, 7, 3 |

Degrees and experience:
- Only one posting requires a PhD (NVIDIA multimedia).
- Aeva, Bosch research and Qualcomm prefer an MS or PhD.
- The rest accept a BE or BS.
- The lowest stated experience is 3 years (Aeva, Bosch research).
- CynLr, Valeo AI and LightMetrics state no minimum.

## Companies checked with no relevant opening today
- **Applied Intuition** [primary]: 3 Bangalore roles (Firmware Engineer, Electrical Integration Engineer, Firmware Validation
  Engineer). All are vehicle systems; none are perception.
- **Netradyne** [primary]: 24 Bengaluru roles. The only ML role is Senior Staff ML Engineer, which is cloud ML/GenAI and 8+ years,
  not vision.
- **Ati Motors (now atirobotics.ai)** [primary]: Lab Technician (Bangalore) and Field Robotics Technician (US) only.
- **Ultraviolette** [primary]: 33 roles. None are ADAS or perception.
- **Aumovio (ex-Continental Automotive)** [primary]: 28 India roles in CAE simulation, IC design, plant work and UX test.
- **Mobileye** [primary]: the only India role is ADAS Strategic Account Manager (Mumbai).
- **Wayve, Waabi, Nuro, Motional, Kodiak** [primary]: no India locations.
- **ZF** [primary]: besides the row above, Research Scientist – AI/ML (Chennai, Req 87869). It is generic GenAI/RL work,
  8+ years, not vision.
- **Qualcomm** [primary]: no automated-driving perception roles in today's India search. There are camera-ISP, XR-AI and
  BSP roles.
- **GM** [primary + UNCERTAIN]: the GM Workday board has 1 India role (HR tech). search-careers.gm.com blocks scripts.
- **Uber India** [secondary]: AV Labs ML roles are in Sunnyvale. Bangalore ML roles are in Eats and Applied AI.
- **Tata Elxsi** [primary, titles only]: the official list shows generic "ADAS Engineers/Leads" and "Technical Project
  Delivery Manager – Edge AI & Computer Vision", with no detail text.
- **Mahindra, Tata Motors, Hyundai Motor India Engineering** [secondary]: no relevant posting found in searches.
  - Tata Technologies has an "HD Map & SLAM" engineer role in Pune, but it is not Tata Motors.
  - BMW TechWorks India appeared once in search ("Senior ML Perception Engineer") [UNCERTAIN].
- **Harman** [UNCERTAIN]: every jobsearch.harman.com detail URL I tried returns 404, and the Workday "HARMAN" site has 0 jobs.
- **Minus Zero** [UNCERTAIN]: minuszero.ai/careers returns 404. Aggregators show a "Director of ML Software" role and
  embedded/AI-intern roles, undated.
- **Swaayatt Robots** [UNCERTAIN]: the site is a script-only single-page app. Aggregator mytat.org lists Research Scientist
  (ML / RL / Motion Planning) roles, undated, with applications to career@swaayatt.com.
- **drivebuddyAI** [UNCERTAIN]: its careers link points only to LinkedIn.
- **Ola Electric / Krutrim** [UNCERTAIN]: Ola's TurboHire board is app-only. Searches found no Krutrim CV or AV roles,
  only an undated aggregator "Calibration Engineer" covering camera, radar, IMU and LiDAR.
- **Ather Energy** [UNCERTAIN]: the careers page returns 403.
- **Addverb** [UNCERTAIN]: listings load dynamically. The "Computer Vision Researcher" and "Robot AI Researcher" pages
  found by search now return 404.

## Dead ends: postings found by search that are closed
- **MBRDI "Engineer – Deep Learning/AI" (T9 Research Engineer, perception algorithms; 230505-MER00043FS):** redirects to
  "nicht-mehr-verfuegbar" (no longer available). So do "Digital Twin AI" (MER000439U) and "AI Engineer" (MER0003VMI).
- **ZF Hyderabad:** "ADAS Data Science & Machine Learning Engineer" and "ADAS Vehicle Simulation & Virtual Environment
  Engineer" both say "position has been filled".
- **GM Bengaluru:** "Autonomous Tech – Simulation Engineer" (Isaac Sim, OpenCV, PyTorch) was removed on 2025-10-18
  (Built In mirror).
- **Qualcomm Bangalore:** none of these is in today's Qualcomm search:
  - "Classical Algorithm Engineer for Camera-LiDAR multimodal perception".
  - "Deep Learning Engineer for Automated Driving Perception", which an aggregator marks expired.
  - "Auto AI Systems Engineer", which no longer accepts applications.
- **Harman:** "Principal Perception Systems Engineer" (24665) and "Principal Engineer AI/ML" (26534) return 404.
  Aggregator copies date from January 2025.
- **APIs that failed:**
  - Uber's old job-search API has been removed ("Missing RPC handler"), and jobs.uber.com blocks scripts.
  - Qualcomm's v2 API now says "Not authorized". The newer `pcsx` endpoint works.
  - foundit.in returns 403, so the KPIT rows stay [secondary].
