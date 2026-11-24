# 02 — Supply and competition: Indian-road driving data

Checked 2026-11-24. This was light web research: nothing was downloaded. Trust tags: `[primary]` = I read it at the
source (dataset page, paper, company page, terms) or checked it through the arXiv or GitHub API. `[secondary]` = a
search snippet, a news story or someone's summary. `[UNCERTAIN]` = could not confirm. `[inference]` = my own
reasoning. Licences and coverage go out of date, so re-check them before quoting this to a buyer.

## TL;DR

- **Most open Indian data is front-camera 2D stills.** Examples: IDD (10k images), IDD-Detection (~46.6k) and
  DriveIndia (67k). **None of these has a published commercial licence.** IDD shows its licence only after login. TiHAN
  uses a "data usage agreement". MOTOR says "research use only".
- **Only two small academic sets have several cameras plus LiDAR.** IDD-3D has 6 cameras covering the surroundings,
  plus LiDAR, in 150 clips of 10 s each, all from daytime Hyderabad. Its download is still marked "coming soon" on
  GitHub. TiAND has 4 cameras, LiDAR and 6 radars over 150 scenes of 2–4 min, also from Hyderabad. **Neither is near
  nuScenes scale and neither is for sale.**
- **The real holders of 360° Indian imagery are large incumbents with their own fleets:** MapmyIndia RealView, Genesys
  and Tech Mahindra (whose imagery Google licenses for Street View), Ola Maps (S1 scooters with 360° cameras) and Apple
  (2026 surveys in 16 states/UTs). They hold map panoramas, not calibrated multi-camera video, and they do not sell it
  as an ML dataset. Google's terms forbid ML training on Street View.
- **Fleet-video firms have scale in India but do not resell footage.** Netradyne claims 25B+ miles analysed. drivebuddyAI
  runs six-camera units on 3,000 trucks. LightMetrics sells through telematics providers. None showed evidence of
  reselling video. The crowdsourced networks (NATIX VX360, Bee Maps, Nexar, DIMO) show **no India coverage**. Mapillary
  has Indian uploads but pays nobody and is CC BY-SA.
- **The gap:** I found no public or purchasable dataset of synchronized, calibrated 360° multi-camera video of Indian
  roads at scale. There is none for two-wheelers either, and night and monsoon data exist only as single-camera stills.
  The 2021 geospatial guidelines reserve street-view surveys for Indian entities, which keeps foreign crowdsourcers
  out. That is a possible moat for an Indian individual, and also a compliance question.

## Open and academic datasets

| Name | Year | Cameras | LiDAR | Labels | Size | Licence | Commercial? | Source + tag |
|---|---|---|---|---|---|---|---|---|
| IDD (segmentation) | 2018 | 1 front, mostly 1080p | no | 34-class pixel segmentation | ~10k images from 182 drives, Hyderabad + Bengaluru | Shown only after login. Public pages say "open dataset… for research" | **Unconfirmed, assume no** | [idd.insaan.iiit.ac.in](https://idd.insaan.iiit.ac.in/), [challenge page](https://cvit.iiit.ac.in/ncvpripg19/idd-challenge/index.html) `[primary]` |
| IDD-Detection | ~2019 | 1 front | no | 2D boxes | 46,588 images | as IDD | assume no | DriveIndia paper's summary `[secondary]` |
| IDD multimodal (primary/secondary/supplement packages) | ~2019 | front stereo, 15 fps | 16-ch LiDAR + GPS + OBD | segmentation | 20k images, 350 sequences | as IDD | assume no | IIIT INAI page via snippet `[secondary]` (page now fails DNS) |
| **IDD-3D** | 2022 (WACV'23) | **6 RGB "cover the surrounding area"** | Ouster OS1 | 3D boxes (17 classes, 10 used), track IDs, ~223k boxes | **150 clips × 10 s at 10 fps = 15.5k frames**, daytime Hyderabad only | not stated. The repo has no licence and its README says "Dataset coming soon!" (last push 2022-10-20) | unknown | [arXiv 2210.12878](https://arxiv.org/abs/2210.12878), `gh api repos/shubham1810/idd3d_kit` `[primary]`; 2025 news says it ships with IDD `[secondary]` |
| IDD-AW | 2023 (WACV'24) | 1 RGB + paired NIR | no | pixel segmentation, 30 labels | 5,000 pairs: 1.5k rain, 1.5k fog, 1k low light, 1k snow | not stated | unknown | [arXiv 2311.14459](https://arxiv.org/abs/2311.14459), [dataset page](https://mobility.iiit.ac.in/safe-seg-24/dataset.html) `[primary]` |
| IDD-X | 2024 (ICRA) | 2: front + rear | no | 697k boxes, 9k important-object tracks, 19 explanation classes | video count not stated | not stated. Code is MIT. Sign-up through india-data.org | unknown | [arXiv 2404.08561](https://arxiv.org/abs/2404.08561), [idd-x.github.io](https://idd-x.github.io) `[primary]` |
| IDD-CRS | 2025 | 1 windshield ADAS camera | no | critical-road-scenario labels | 5,400 untrimmed 1-min videos | **listed as private** on India Data | no access | 2026 survey snippet + IIIT camera-ready PDF title `[secondary]` |
| **TiAND** (TiHAN, IIT Hyderabad) | 2024 | **4 cameras** (surround not stated) | yes, + 6 radars, GNSS/IMU | object detection (format not stated) | **150 scenes × 2–4 min**, Hyderabad | "data usage agreement", via Google form | not stated | [tihan.iith.ac.in/TiAND.html](https://tihan.iith.ac.in/TiAND.html) `[primary]`; IEEE doc 10588583 `[secondary]` |
| DriveIndia (TiHAN) | 2025 (ITSC) | Basler GigE (count not stated) | no | YOLO 2D boxes, 24 classes, ~471k instances | 66,986 images, 120+ h, 3,400+ km, urban/rural/highway, fog/rain/low light | EULA form | not stated | [arXiv 2507.19912](https://arxiv.org/abs/2507.19912), TiHAN page `[primary]` |
| DAVE | 2024 | 2 wide-angle dashcams `[secondary]` | no | 13M+ boxes, 16 actor + 16 action types | ~1,231 one-minute clips `[secondary]` | not checked | ? | [arXiv 2412.20042](https://arxiv.org/abs/2412.20042) `[primary]` |
| **MOTOR** (two-wheeler) | 2026 (ICRA) | 3× GoPro Hero 10: **front, rear, helmet**, + eye tracker | no | 12 manoeuvres, legality, rider state | 1,629 sequences, 25+ h, 16 riders | HF card: "Research use only" | **no** | [arXiv 2605.22550](https://arxiv.org/abs/2605.22550), [HF card](https://huggingface.co/datasets/Voxel51/motor_two_wheel_rider) `[primary]` |
| MV2 | 2026 (ECCV) | GoPro 10s on car + scooter + drone, synchronized (counts not stated) | no | SfM poses checked by hand | 50 scenes, 12k images (2 fps) | not stated | unknown | [arXiv 2608.12442](https://arxiv.org/abs/2608.12442), [site](https://mv2-dataset.github.io/) `[primary]`; captured in India? `[UNCERTAIN]` (IIIT-H authors) |

More two-wheeler-related sets whose licences I did not check: myEye2Wheeler (Indian rider eye-tracking,
[arXiv 2502.12723](https://arxiv.org/abs/2502.12723)), and RideSafe-400 (car dashcam footage of two-wheeler
violations, [arXiv 2503.00428](https://arxiv.org/abs/2503.00428)) `[primary: existence only]`.

## Commercial collectors

| Who | What they hold | India scale | Do they sell it, and on what terms? | Source + tag |
|---|---|---|---|---|
| **MapmyIndia** (Mappls) | RealView 360° panoramas + videos; dashcams and trackers sold as "Mappls Gadgets" | at the 2022 launch: "40 crore+ geo-tagged 360° panoramas and videos", ~100k km | Sells RealView APIs "for ADAS, autonomous vehicles…". Terms for raw imagery or ML use not found. FY26 revenue ≈ ₹474 cr, of which map data + services ≈ ₹419 cr | [Autocar India 2022](https://autocarindia.com/car-news/mapmyindia-launches-mappls-realview-with-pan-india-360-deg-street-view-425218), Trendlyne/Quartr `[secondary]` |
| **Genesys International** | Street-level imagery (Google's Street View partner), 3D digital twin, HD ADAS maps | HD maps of 100k+ km of national highways (Dec 2025) | "datasets owned by Genesys and can be licensed across industries" | [Google blog Dec 2023](https://blog.google/intl/en-in/products/explore-communicate/ai-continues-to-supercharge-google-maps-for-india/) `[primary]`; [Autocar Pro](https://www.autocarpro.in/news/genesys-launches-high-definition-adas-maps-for-national-highways-130209) `[secondary]` |
| **Tech Mahindra** | collects Street View imagery for Google | with Genesys: 150k km in 10 cities at the July 2022 launch | Imagery is owned by Genesys and Tech Mahindra, not Google | Google blog `[primary]`; [Business Standard](https://business-standard.com/article/current-affairs/google-starts-street-view-in-india-with-local-partners-after-policy-change-122072700622_1.html) `[secondary]` |
| **Google Street View India** | licensed partner imagery; some 2025 imagery appears to come from Google's own cameras `[secondary]` | "over 3,000 cities and towns" (Dec 2023) | **Maps Platform ToS 3.2.3(a)(ii) bans bulk download of Street View images. 3.2.3(c)(vii) bans using Maps content "to train, test, validate or fine-tune" ML models** (terms last modified 2026-08-26) | [GMP terms](https://cloud.google.com/maps-platform/terms) `[primary, read]` |
| **Apple Maps** | vehicle, backpack and transit surveys | vehicles in 16 states/UTs, Mar–Jul 2026 (Telangana to Sep 2026); backpacks in 13 | Not sold. Blurred imagery "may be used to train" Apple models | [maps.apple.com/imagecollection/in](https://maps.apple.com/imagecollection/in) `[primary]` |
| **Ola Maps** (Krutrim) | "fleet of Ola S1's equipped with 360 cameras", so **two-wheeler 360° capture already exists** | Street View API covers ~9,895 km in and around Bengaluru | API only; terms not read | [Ola blog](https://blog.olakrutrim.com/navigating-india-the-journey-of-olamap/), [docs](https://maps.olakrutrim.com/docs/street-view) `[primary]` |
| **Netradyne** (Bengaluru R&D) | Driver•i fleet video (a 4-camera windscreen unit `[secondary]`) | "25B+ driving miles analysed" (global); India arm ≈ ₹293 cr FY25 revenue; D-450 launched in India Oct 2025 | No sign of reselling video. The footage belongs to fleet customers `[UNCERTAIN]` | [netradyne.com/in](https://netradyne.com/in), [Business Today](https://www.businesstoday.in/tech-today/news/story/ai-led-road-safety-gets-a-push-as-netradyne-launches-advanced-fleet-monitoring-tech-in-india-497397-2025-10-08) `[secondary]` |
| **LightMetrics** (Bengaluru) | RideView, a hardware-agnostic video telematics platform | deployed through telematics providers in India and 8 other countries; uploads kept up to 6 months | No sign of resale `[UNCERTAIN]` | [lightmetrics.co](https://lightmetrics.co/about-us) `[secondary]` |
| **drivebuddyAI** (Ahmedabad) | **six-camera** ADAS on heavy trucks | 3,000 trucks, may grow to 10,000; a 360° camera + radar version is "work in progress" | Data ownership and sale not stated | [Autocar Pro, 8 May 2026](https://www.autocarpro.in/news/drivebuddyai-bags-$25-million-adas-contract-for-3000-trucks-132506) `[primary]` |
| **ARAI Swayam-Go** | 2 test vehicles logging synchronized camera, LiDAR and radar | ~20–25k km | Offered as an ADAS-validation service with an "India-specific" scenario database | snippet; the article returned 403 `[secondary]` |
| **Data vendors** | FutureBeeAI: off-the-shelf Indian *in-car speech* only; video is custom collection. Shaip: generic "Dashcam Traffic Scenes", 210 images, location unstated. Ainnotate (India): "Indian traffic dataset (annotated and raw)" on an unclaimed Datarade listing. DataCluster Labs: Indian vehicle and sign images, commercial licence. TELUS Digital bought Playment (Bengaluru, 2D/3D/LiDAR annotation) in July 2021 | none showed a synchronized multi-camera Indian product | Custom collection is the norm. **No public prices found** (see dead ends) | vendor sites `[secondary]`; [Ainnotate listing](https://datarade.ai/data-products/raw-indian-traffic-videos-mp4-ainnotate) `[primary]` |

## Crowdsourced networks

| Network | What it records | India coverage | Contributor pay | Source + tag |
|---|---|---|---|---|
| **NATIX VX360** | 4 Tesla exterior cameras (front, side, rear). 141k+ h, 270k+ drivers and 247M km by Feb 2026. Buyers named: Nomadic ML; also Valeo (open multi-camera world model) | **None.** Sold in the USA, Canada, EU, UK, Norway, Switzerland, Singapore and Japan; rewards are "only available in the countries listed". India has had only ~1,000 Teslas since Sep 2025 `[secondary]` | "up to $60/month in $NATIX" (Jan 2026 rates); device $350–449 | [VX360 page](https://www.natix.network/vx360-depin-dashcam), [Feb 2026 update](https://www.natix.network/blog/progress-update-natix-network-february-2026) `[primary]`; Valeo `[secondary]` |
| NATIX Drive& (phone app) | phone dashcam | India was not on the reward-country list `[secondary]` | **Shut down**: earnings stopped 1 May 2026, the app closed 1 Jul 2026. NATIX cited what "Physical AI customers are prepared to pay for… multi-camera driving data" | [sunset post, 14 Apr 2026](https://www.natix.network/blog/closing-a-chapter-in-the-evolution-of-natix-network) `[primary]` |
| **Bee Maps** (Hivemapper) | Bee dashcam, map features | **not found.** It "can map anywhere Bee Maps is legally able to ship". Claims contributors in 100+ countries | HONEY token; USDC becomes the default from Aug 2026 "at its discretion". Bee costs $569/$469, or a $19/month plan (sources conflict) | [docs](https://docs.hivemapper.com/contribute/driving/) `[secondary]`; Business Wire returned 403 |
| Nexar | consumer and fleet dashcams | US-focused ("98% of US highway miles"); India appears only as an anecdote | not found `[UNCERTAIN]` | `[secondary]` |
| DIMO | vehicle telemetry (OBD, APIs), not camera video | not found | DIMO token, weekly | `[secondary]` |
| **Mapillary** (Meta) | any camera, street-level photos | an active Bengaluru community in 2016–18 (capture challenges, 12 donated mounts). Current India volume not found | **None**: Meta takes a licence "without compensation to you". Other users' imagery is CC BY-SA; commercial use falls under §12 | [terms, effective 2024-02-15](https://www.mapillary.com/legal) `[primary]`; [forum](https://forum.mapillary.com/t/completethemap-bengaluru/1325) `[secondary]` |

**Regulation that shapes supply.** The Feb 2021 DST geospatial guidelines bar foreign-controlled ("Restricted")
entities from terrestrial mobile mapping and street-view surveys. Foreign firms may only *license* such data from Indian
entities, through APIs. "Indian Entity" includes any Indian citizen. Data finer than the accuracy threshold must be
stored in India ([Nishith Desai analysis](https://www.nishithdesai.com/default.aspx?id=4678) `[secondary]`; the DST PDF
itself did not load). This explains why Google relies on Genesys and Tech Mahindra `[secondary]`. It may also explain
why the foreign crowdsourcers are absent `[inference]`.

## The gap

1. **I found no synchronized, calibrated, 360° multi-camera video dataset of Indian roads that is both sizeable and
   obtainable.** The closest are three small research sets:
   - IDD-3D: 6 cameras + LiDAR, 25 min of labelled clips, daytime Hyderabad. Availability and licence unclear.
   - TiAND: 4 cameras + LiDAR + radar, roughly 5–10 h, Hyderabad, under a data agreement.
   - MV2: GoPros on a car, a scooter and a drone. It is a novel-view-synthesis benchmark, not a surround rig.

   Surround rigs do exist: IIIT-H's Bodhyaan car (six cameras + LiDAR `[secondary]`), TiHAN's car (drove Hyderabad →
   Jammu in Jan 2025 `[secondary]`), ARAI's Swayam-Go cars and drivebuddyAI's six-camera trucks. Their raw multi-camera
   logs are not on sale `[inference from absence]`.
2. **Two-wheelers.** MOTOR (front, rear and helmet cameras, research use only) and myEye2Wheeler (gaze) record the
   *rider*. Ola's 360° S1 fleet feeds a map product. I found **no calibrated surround dataset from a two-wheeler**.
3. **Night, monsoon and rural.**
   - IDD-AW: rain, fog, low light and snow, but as 5k single-camera stills.
   - DriveIndia: fog, rain, low light and rural roads, but as 2D stills.
   - IDD-X: day and night, but front and rear cameras only.
   - IDD-3D: **daytime only**.

   I found no surround dataset that covers night or monsoon.
4. **Cheap substitutes and anchors to watch.** CROWD indexes 36,204 h of public YouTube dashcam footage from 238
   countries. It links to the videos and does not license them ([arXiv 2604.01044](https://arxiv.org/abs/2604.01044)
   `[primary]`). NATIX shows that buyers pay for multi-camera Tesla footage outside India (prices not disclosed).
   nuScenes, Argoverse 2 and NVIDIA PhysicalAI-AV are free or cheap anchors with no Indian roads (see `../12-test-datasets.md`).

## Dead ends

- **IDD licence text was not found.** It is "displayed before downloading" and needs an account. A DST snippet
  says "public domain… unrestricted use", which contradicts the IIIT "for research" wording. Unresolved.
- `inai.iiit.ac.in` failed DNS (ENOTFOUND) on 2026-11-24. The `india-data.org` dataset page rendered only its title,
  so the terms could not be read.
- The `idd3d_kit` README still says "Toolkit code, Data demos and Dataset coming soon!" and has no licence file.
- The DST guidelines PDF URL returns an HTML stub. Business Wire (Bee Maps USDC news) and AckoDrive (ARAI) returned 403.
- A search snippet said Ainnotate's annotated set costs "from USD 9,000". **The page itself says pricing is not
  published**, and the listing is auto-generated and unclaimed. Treat the price as unverified.
- I found no India coverage for Bee Maps, Nexar or DIMO, and no current Mapillary India volume. Not checked: iMerit,
  Cogito, Intangles (a telematics firm, not video), the MapmyIndia and Genesys raw-imagery licence terms, and the
  licences for myEye2Wheeler and RideSafe-400.
- TiAND's venue and year are not confirmed beyond IEEE Xplore doc 10588583. I don't know whether its 4 cameras give
  surround coverage.

## Open questions

1. What exactly do the IDD and IDD-3D licences say? Register and read them. Is IDD-3D actually downloadable?
2. Would MapmyIndia, Genesys or Ola license raw 360° imagery or video for ML training, and at what price?
3. Do the Netradyne, LightMetrics or drivebuddyAI contracts allow them to resell customer video? If so, they are the
   real competitors at scale.
4. Does a private multi-camera rig recording for an ML dataset count as a "street view survey" under the 2021
   guidelines? What storage and export duties follow? What does the DPDP Act require for faces and plates? (These are
   for the legal research file.)
5. Will NATIX VX360 launch in India as Tesla's fleet there grows?
