# 03 — Prices, business models and buyer requirements for driving data

Researched 2026-11-24, light web research only (nothing downloaded except two PDFs read as text). Tags: `[primary]` =
seller's or buyer's own page, listing, filing or dataset card, read this session; `[secondary]` = news, analytics firm or
search snippet; `[UNCERTAIN]` = could not confirm; `[derived]` = my arithmetic on tagged numbers. Prices rot fast.
₹ figures use 1 USD = ₹92.92 (ECB reference rate dated 2026-11-23, via api.frankfurter.dev).

## TL;DR

- **The one published price for this exact product:** DrivingFootage.com sells footage from **9 synchronized 4K cameras
  (360°)** at **$85–100 per hour of combined footage**, so **≈$765–900 (₹71k–84k) per hour of driving**, as a
  non-exclusive, perpetual AI-training licence. That is an asking price. The footage has no GPS and is not blurred `[primary]`.
- **Ordinary street imagery sells for almost nothing:** Bee Maps charges $0.005 per image and $6 per event clip. Nexar's
  2020 samples were $0.05 per image-year. Mapillary is free. NVIDIA gives away 1,700 h of 7-camera + LiDAR data for internal
  AV work. Hours of ordinary driving are worth little; events, places nobody else covers and clean rights are worth more.
- **Contributors earn little, and less each year:** NATIX says Tesla owners earn "up to $60/month" in tokens, which is
  ≈$21 at today's token price `[derived]`. Bee paid about $20 per recipient in Dec 2025 `[derived]`. DIMO's rewards and NATIX's phone-app
  rewards ended in 2026. Solana DePIN networks paid >$100M in 2025 rewards against $17M revenue, so token subsidies paid the drivers, not data sales.
- **The money is in fleet-safety subscriptions and labelling, not raw footage.** Hivemapper's on-chain revenue was ≈$550k in 2025.
  NATIX publishes no revenue figure. Nexar + Nauto merged into Empiric Earth (terms undisclosed). Netradyne (≈$1.35B) sells
  fleet safety. Scale's AV labelling went into decline in 2022.
- **Buyers split into two tiers.** Generative-video and world-model buyers accept timecode sync, no GPS and nominal
  calibration, so a well-documented phone rig can **pass** there. AV perception and 3D-label buyers expect a hardware trigger,
  calibrated extrinsics, rolling-shutter timing, cm-level pose, CAN and usually LiDAR, so a phone rig **fails** there.

## Price table (what each price buys)

| What | Price | Unit | Raw / labelled · licence | Source |
|---|---|---|---|---|
| DrivingFootage.com regional package (e.g. Urban N. America, 1,136 h, $113,600) | **$100** (₹9,292) | per hour of *combined* footage from all 9 cameras; ≈$900 per driving hour `[derived]` | raw C4K 23.976 fps, 9 cams, per-clip tags; **no GPS, unblurred**; non-exclusive, worldwide, perpetual training licence; no resale or redistribution | Datarade listing, read 2026-11-24 `[primary, asking price]` |
| DrivingFootage.com full library (≈1,750 combined h ≈ 194 driving h) | **$85**/h, ≈$150,000 | same; ≈$771 per driving hour `[derived]` | same; "part of the library has already been licensed … by a major AI developer" (seller's claim) | same `[primary]` |
| Bee Maps street-level imagery | $0.005 | per geolocated frame (GPS/IMU metadata) | raw, blurred; API, consumption-based | beemaps.com/pricing, read 2026-11-24 `[primary]` |
| Bee Maps AI Event Videos | $6 | per event clip (harsh braking, swerving, high-g…) + GPS/speed trace | raw, picked by event trigger | same + docs/platform/road-intelligence-api `[primary]` |
| Bee Maps road detections / Burst | $3 / $1 | per 1,000 machine detections / per on-demand location | machine-labelled / commissioned collection | same `[primary]` |
| Bee Edge AI on network devices | $0.02 | per km (5 MB/km included; $0.05 per extra 10 MB) | your model runs on other drivers' cameras | same `[primary]` |
| Nexar on AWS Data Exchange (Las Vegas, Manhattan, Feb 2020) | $500 | per 10,000 images per 12 months (=$0.05/image-year `[derived]`) | raw JPG + GPS + timestamp; Manhattan listing says faces/plates blurred | AWS Marketplace listings `[primary]` |
| nuScenes (Motional) on AWS Marketplace | $0 | — | labelled; non-commercial (see ../12-test-datasets.md) | listing `[primary]` |
| NVIDIA PhysicalAI-Autonomous-Vehicles | $0 (gated) | 1,700 h, 306,151 × 20 s clips | 7 cams + LiDAR + radar + auto labels; **internal AV development "using NVIDIA technology" only, no resale** | HF dataset card `[primary]` |
| NATIX Multi-Camera Driving Dataset | $0 for 100 h; commercial price not published | — | raw, blurred; RAIL-NC licence, **commercial use needs NATIX's written permission** | HF dataset card `[primary]` |
| Unpublished creator video sold to AI labs | $1–4 per minute (= $60–240/h `[derived]`) | single camera | raw; "premium" for 4K/drone | Bloomberg 2025-01-10 via relays `[secondary]` |
| Label Your Data (annotation service) | box $0.02 · polygon $0.045 · image cuboid $0.09 · keypoint $0.015 per object; **$6 per annotator-hour** | "starts at" | labelling only | labelyourdata.com/pricing calculator `[primary]` |
| Scale Rapid 3D sensor fusion | $0.50 per LiDAR sequence + $0.15 per cloud annotation | undated | labelling | TrustRadius snippet; page returned 403 `[UNCERTAIN]` |
| LiDAR 3D box, quality labelling | ~$1–2 per box; 20–40 boxes/h per annotator | undated personal research note | labelling | kvynlim.github.io `[UNCERTAIN]` |
| India data-work pay (worker side) | Karya ≥$5/h (₹465); one worker ₹250/h (≈$2.69) | worker wage, not vendor price | — | Karya/TIME via search `[secondary]`; Business Today 2026-06-13 `[secondary]` |
| India vendor rates (client side) | $4–8 per annotator-hour | vendor marketing | labelling | search snippets only `[UNCERTAIN]` |

India market size: NASSCOM put India-serviced annotation at ≈$250M in FY20 and ">$7B by 2030" (report is members-only) `[secondary]`.
**No India-specific price for driving video was found anywhere** (see Dead ends).

## Contributor payouts

| Network | Contributor's cost | What drivers get | Form | 2026 status | Source |
|---|---|---|---|---|---|
| NATIX VX360 (Tesla owners; ships to US/UK/EU/Japan, not India) | $379 device | "up to $60/month in $NATIX", based on the Jan-2026 token rate; the token is −65% since then, so the same tokens ≈ **$21** `[derived, CoinGecko]`. Dec 2025: 714 on-chain recipients, USD paid −56% vs Nov | tokens (+"non-crypto rewards") | live; the "ROI in 6–12 months" is marketing | shop.natix.network `[primary]`; Syndica Dec-2025 report `[secondary]` |
| NATIX Drive& (smartphone app) | phone | — | tokens | **ended**: earnings stopped 2026-05-01, app closed 2026-07-01 | NATIX April-2026 update `[primary]` |
| Bee / Hivemapper | $19/month × 24 months (US/PR only) or $589 upfront | USDC each week if the region's weekly km goal is met; amounts shown in the app only; "funded by Bee Maps … at our sole discretion". Dec 2025 (HONEY era): 20M HONEY to 9.3k recipients ≈ **$20 per recipient** `[derived]` | USDC on Base via Circle Wallet | HONEY dropped from the Bee App in Aug 2026; Bee Maps ended its services agreement with the Hivemapper Foundation | beemaps.com blog 2026-07-16 + docs `[primary]`; Syndica `[secondary]` |
| DIMO (car telemetry, not video) | dongle or app | — | DIMO tokens | **ended**: Baseline Issuance stopped 2026-08-28 (DIP-12); developers now pay 1,250 DCX per vehicle-month (USD value of a DCX not checked) | DIMO token-transparency filing on Blockworks `[primary]` |
| Nexar → Empiric Earth | buys dashcam/subscription | no payout scheme found | — | — | `[UNCERTAIN]` |
| Mapillary (Meta) | phone/camera | nothing; imagery CC BY-SA, free for commercial use since 2020 | — | — | TechCrunch/Reuters 2020 `[secondary]` |

Token prices on 2026-11-24 versus their all-time highs: HONEY $0.00122 (−99.7%), NATIX $0.000107 (−94.6%), DIMO $0.0139 (−98.2%) (CoinGecko API) `[primary data]`.
In 2025, Solana DePIN rewards totalled >$100M against $17M revenue. The two figures cover slightly different sets of protocols, but rewards far exceeded revenue (Syndica) `[secondary]`.

## Business and revenue evidence

- **Empiric Earth** (Nexar + Nauto, renamed 2026-09-15): >10B miles, 60M edge cases, 350k sensors, 300M new miles a month.
  Its buyers are developers, automakers, fleets, insurers and public agencies. Deal terms were undisclosed `[primary: PR Newswire]`. Nexar was
  valued at ≈$300–400M in earlier rounds `[secondary: Calcalist]`. Its "≈$60M revenue" is a third-party estimate `[UNCERTAIN]`.
- **Hivemapper / Bee Maps:** raised $32M on 2025-10-06 (Pantera, LDA, Borderless, Ajna). Customers it names: VW's robotaxi program,
  Lyft, Mapbox, NBC; no contract values `[primary: PR Newswire]`. On-chain revenue was ≈$550k for 2025 and ≥$110k/month by
  year-end, with average monthly revenue −18% vs 2024 `[secondary: Syndica]`. Now that Bee Maps sells for USD and has left the
  Foundation, on-chain burns may no longer track its revenue `[UNCERTAIN]`. HONEY market cap ≈$8M.
- **NATIX:** "VX360 is now generating the majority of NATIX protocol revenue", with no figures `[primary, 2026-05-11]`. It reports
  141K h of multi-camera footage, 270K drivers and 247M km `[primary, 2026-03-09]`. Nomadic ML is a data customer and Autoware a
  data partner `[primary]`. 40% of data revenue goes to token buyback-and-burn `[secondary: Blockworks]`. Token market cap ≈$6.8M.
- **Netradyne** (fleet-safety cameras): $90M Series D in Jan 2025 led by Point72. TechCrunch's text says
  "$1.35B pre-money" while its URL says 1.25B, and the CEO told Inc42 "$1.34B post-money". 18B+ miles, 65% growth `[secondary]`. Revenue
  estimates run from $116M (2023) to $210M (2024) `[UNCERTAIN]`.
- **Scale AI:** Meta bought 49% for ≈$14.3B (June 2025, ≈$29B valuation); 2024 revenue ≈$870M. AV labelling "went into a
  decline" from mid-2022 `[secondary: Axios, Sacra, Contrary]`. The AV share of revenue is not disclosed.
- **Mapillary → Facebook** (June 2020): price undisclosed `[secondary]`. **Troveo** (video licensing broker) says it has paid content
  owners >$20M `[secondary: IT Brief, May 2026]`. **DrivingFootage.com** grew out of film/TV "driving plates" and now sells the
  same library for AI `[primary]`. That is a second market for synced multi-camera rigs.

## Buyer requirements checklist, and how a DIY phone rig fares

| Requirement | What reference datasets and buyers do | DIY phone rig | Sources |
|---|---|---|---|
| Inter-camera sync | nuScenes fires each camera when the LiDAR sweeps its view; PTP gets ≈100 µs. DrivingFootage only promises "matching timecode and in/out points". NATIX cameras run at different rates (36.02 vs 34.62 fps) | **Pass** for the generative tier if offset is measured and documented; **fail** for the AV tier. Software sync ≈ 1 frame (16.7 ms at 60 fps) = 0.23 m of travel at 50 km/h, 0.46 m at 100 km/h `[derived]` | nuScenes paper `[primary]`; sync paper `[secondary]`; DF, NATIX cards `[primary]`; 16.7 ms floor from the SynciOS notes `[UNCERTAIN]` |
| Rolling-shutter timing | Waymo stores readout direction and per-image trigger and readout-done times | phone sensors are rolling-shutter `[UNCERTAIN]`; measure the readout time once per phone model and ship it | waymo-open-dataset dataset.proto `[primary]` |
| Intrinsics and extrinsics | NVIDIA ships intrinsics, extrinsics and windshield models, and fixed 140 clips whose LiDAR–camera calibration was off (115 re-solved, 25 dropped). NATIX ships *estimated* intrinsics, distortion and rotation to the ground. DrivingFootage ships nominal intrinsics, with per-day calibration on request | **Pass** if you lock the lens, turn off OIS/EIS and calibrate each mounting. Lens switching and stabilisation change intrinsics `[UNCERTAIN]` | HF cards, DF listing `[primary]` |
| Resolution, FPS, FOV, overlap | NVIDIA 1080p30 on 7 cams (120°/70°/30°); nuScenes 1600×900 at 12 Hz; NATIX 1448×938 at ~36 fps; DF C4K with 20–32° overlap between neighbours; Bee 12.3 MP at 30 Hz | **Pass** on resolution; overheating over long drives not checked `[UNCERTAIN]` | cards, paper, beemaps.com/bee `[primary]` |
| Position, pose and timing | nuScenes ≤10 cm (LiDAR map). Bee: dual-band L1/L5 GNSS + 6-axis IMU; it says a phone's "5 mm antenna" is off by 10–30 m in cities. NATIX: consumer GPS, GPS-video offset 0–1 s (up to 3 s). DF: **no GPS at all** | **Partial**: enough for generative buyers, weak for mapping and AV. A dual-band GNSS receiver plus visual-inertial odometry would close the gap | nuScenes paper; Bee blog 2026-02-19; NATIX card; DF `[primary]` |
| Vehicle actions (steering, pedals, speed) | nuScenes ships raw CAN. NATIX is adding "pedal position, wheel angle" telemetry. NVIDIA ships ego-motion | **Fail** for end-to-end and VLA buyers unless you log CAN. Standard OBD-II may not expose steering angle `[UNCERTAIN]` | paper, NATIX card, NVIDIA card `[primary]` |
| LiDAR | nuScenes, Waymo and NVIDIA have it. NATIX, Bee and DrivingFootage are camera-only and still sell | not needed for the camera-only tier; needed for 3D ground truth | as above `[primary]` |
| Curation, edge cases, metadata | Bee sells event clips at $6 each. NVIDIA marks 1,434 critical-event moments. Empiric Earth claims "60M edge cases". DF tags time of day, weather, road and traffic per clip | **Pass** if you tag events (IMU braking, near-misses) and conditions; Indian traffic mixes are the scarce part | pages above `[primary]` |
| Anonymisation | Bee blurs faces, bodies, vehicles and plates, and trims 500 m at each trip end. NATIX blurs faces and plates and removes sensitive sites. NVIDIA's licence bans re-identification. DF ships unblurred and leaves privacy to the licensee | blur by default. India's DPDP Rules were notified 13/14 Nov 2025, with most duties in force ≈May 2027 | Bee privacy docs, cards `[primary]`; DPDP coverage `[secondary]` |
| Format and delivery | NVIDIA: mp4 + parquet + Draco LiDAR. NATIX: 1-min mp4 + per-clip GPS CSV, ≈12.8 GB per driving hour `[derived]`. ROS 2 records MCAP by default since Iron. Models in this repo read nuScenes format | **Pass**: easy | cards `[primary]`; Foxglove/ROS docs `[secondary]` |
| Rights and provenance | DF: "self-shot … nothing scraped … chain of title is clean"; non-exclusive; no redistribution | **Pass**: owning the whole chain is the DIY rig's real advantage. Record consent for drivers and passengers | DF listing `[primary]` |

## Dead ends

- Datarade's AV category is almost all "Pricing available upon request". Ainnotate's "Raw Indian Traffic Videos" profile is
  unclaimed with no price. Datarade search pages refuse scripts. Defined.ai has no dashcam listing or price. Shaip prices on
  request and has no Indian driving set. Nothing found for FutureBeeAI. No driving-video listing on Snowflake Marketplace.
- AWS's SageMaker Ground Truth pricing page showed no per-object or per-frame rates when fetched. Scale's pricing page shows no
  numbers. Indian vendor rate cards were blocked or missing: Cogito (403), Anolytics (unreachable), Infosearch (404); Wisemonk's
  India page has no figures. No public per-frame LiDAR labelling rate card was found; real rates need quotes.
- Bee Maps' old docs and blog (Map Image API "$1 per road km per week"; "licensing to paying customers") and its tech-specs page now
  return 404. Getty "synced series" driving plates returned 403; DrivingPlates.com 9-angle sets are priced on request.
- NATIX: no commercial data price, WorldSeek pricing not found, its HF datasets are gated and non-commercial, and no evidence of a Grab deal.
- Programmes ended: NATIX Drive& (2026), HONEY rewards in the Bee App (Aug 2026), DIMO Baseline Issuance (2026-08-28).
- Scale's AV revenue share, Nexar's data-licence prices after the 2020 samples, and Empiric Earth's deal value are not disclosed.

## Open questions

- Has DrivingFootage actually sold at $85–100/h, and how often? A listed "starts at" price is not a transaction price.
- Do buyers pay more for Indian roads? No price was found, so ask the buyers named in 01-demand-india.md with a sample.
- What sync offset will a specific buyer (Nomadic ML, Autoware, world-model labs) accept? Measure the rig, then ask.
- Are Bee's USDC rewards live in India, and does Bee or NATIX hardware ship there? (NATIX VX360 ships only to US/UK/EU/Japan.)
- Under DPDP, can unblurred footage of bystanders be licensed at all? That question belongs to a legal review.
