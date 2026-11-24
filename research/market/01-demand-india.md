# 01: Demand. Who needs or pays for Indian road driving data, especially multi-camera?

Researched 2026-11-24 in a light web pass (about 60 searches and fetches, no datasets downloaded).
Tags: **[primary]** means a company or regulator page, a job post or a gazette. **[secondary]** means news or analysis. **[UNCERTAIN]** means I could not open or confirm the source.
The tables keep "says it needs Indian data" separate from "pays outsiders for it". Several pages returned 403 (Axios, ackodrive, YourStory). Those claims are tagged UNCERTAIN.

## TL;DR
- **I found no public evidence that anyone buys DIY multi-camera Indian road footage from individuals.** Many companies say they need Indian data. Evidence that anyone pays outsiders for it is thin and indirect.
- **The strongest value signals:**
  - Tesla paid its own "Autopilot vehicle operators" in Delhi and Mumbai to collect camera data in 2025.
  - ARAI built a synchronised camera, LiDAR and radar database of Indian roads. Reports say OEMs can license it.
  - Uber AV Labs is building an AV-data business for its partners. It is free for now, with a fee planned later. India collection is not confirmed.
- **The big global multi-camera datasets leave out India.**
  - NVIDIA PhysicalAI-AV covers 25 countries with 7 cameras and has zero India clips.
  - Wayve's 90-city roadshow included no Indian city.
  - The NATIX and Valeo data covers the US, Europe and Asia, and India is not named.
  - So there is a real gap, but no global buyer has said publicly that it will pay for Indian data.
- **Regulation creates demand only indirectly.**
  - A final rule, G.S.R. 834(E) of November 2025, requires AEBS, lane departure warning (LDWS), drowsiness warning (DDAWS), blind-spot information (BSIS) and moving-off information (MOIS) systems on buses and trucks in 2027–28.
  - Mandatory AEB for cars is still a draft, with dates of 2030 for new models and 2032 for all. Bharat NCAP 2.0 is also a draft, starting October 2027.
  - Type approval is done by track tests. So the need is for OEMs and Tier-1 suppliers to get Indian data for their engineering work. No rule makes anyone buy data.
- **The likeliest buyer types, if there are any:**
  - Tier-1 suppliers and engineering-services firms: Bosch BGSW, KPIT, Tata Elxsi, Aumovio, Valeo, Mobileye.
  - Indian AV startups, such as Minus Zero.
  - Global AV and world-model labs, buying through brokers such as Uber AV Labs or NATIX-style networks.
  - Single-camera Indian video is **not scarce**: Netradyne has analysed 25B+ miles and drivebuddyAI claims 3.5B km. The possibly scarce product is calibrated, synchronised **surround** video with ego-motion, and nobody has published a price for it.

## Potential buyers

| Name | Type | India relevance | Evidence of data need | Evidence of paying for external data | Source + tag |
|---|---|---|---|---|---|
| Tesla | Global OEM / AV | Model Y on sale in India since July 2025; FSD "pending regulatory approval" | Hired "Autopilot Vehicle Operators" in New Delhi and Mumbai to drive engineering vehicles collecting "dynamic audio and camera data" | Pays **its own staff**, with a 10% premium for afternoon and night shifts. I found no third-party buying. | driveteslacanada.ca/news/tesla-begins-hiring-autopilot-vehicle-operators-in-india/ (2025-05-02) [secondary]; basenor.com/blogs/news/tesla-fsd-global-rollout-india-approval-now-pending (~Jun 2026) [secondary]; a March 2026 Delhi repost was seen only on a dead aggregator link [UNCERTAIN] |
| Uber AV Labs | Data broker for 20+ AV partners | Uber's India-locale notice: outward cameras on vehicles "driven and owned by third-party operators", data shared with AV partners, "we do not blur faces". The same notice appears on many country sites. Uber is building two India campuses and hiring for "autonomous vehicle operations". | Data for Waymo, Waabi, Lucid and others; 500 sensor-equipped Ioniq 5s "worldwide in 2026"; CBS says it starts with its 50,000 global fleet partners fitting sensor kits | **Free for now:** "Uber won't be charging for it. At least not yet." Uber plans to charge partners later. Pay to fleet partners is not stated. India collection is not confirmed. | techcrunch.com/2026/01/27/uber-launches-an-av-labs-division-to-gather-driving-data-for-robotaxi-partners [secondary]; cbsnews.com/news/uber-self-driving-cars-autonomous-driving (2026-01-29) [secondary]; uber.com/in/en/autonomous/data-collection/ (undated) [primary]; autotechinsight.spglobal.com/news/5288752 (2026-06-08) [secondary]; techcrunch.com/2026/05/14/uber-to-open-2-campuses-in-india... [secondary]; Axios (2026-09-23), "deals with Nvidia and Wayve" [UNCERTAIN: 403, search snippet only] |
| NVIDIA | Physical-AI platform and dataset publisher | PhysicalAI-AV dataset: 306k 20-second clips, about 1,700 h, 7 cameras plus LiDAR, 25 countries (US plus 24 European). **No India.** | Needs geographic diversity (2,500+ cities) | No evidence that it buys Indian data. The dataset is free under a restrictive licence: internal AV development on NVIDIA tech only, 12-month term. | huggingface.co/datasets/nvidia/PhysicalAI-Autonomous-Vehicles README (v25.10 → v26.11) [primary] |
| Wayve | Global end-to-end AV | The 90-city "AI-500" roadshow named no Indian city; next steps are the US East Coast, Europe and Japan | Sources fleet data through partners (DPD vans in London, S.RIDE taxis in Tokyo) | Partner deals exist in the UK and Japan. None found in India. | wayve.ai/thinking/ai-500-roadshow-90-cities/ (2025-06-09) [primary]; theregister.com/2025/04/22/wayve_heads_to_japan_for/ [secondary] |
| Valeo (+NATIX) | Tier-1 | Active in India (radar tie-up with Hero) | Open-source multi-camera world foundation model built on NATIX's 100k+ h of Tesla surround data, to learn "true edge cases" | Terms undisclosed. Data comes from the US, Europe and Asia, and India is not mentioned. | valeo.com/en/valeo-and-natix-partner-to-build-one-of-the-largest-open-source-multi-camera-world-foundation-models/ (2026-01-22) [primary]; autocarindia.com/bike-news/hero-partners-with-valeo-to-develop-radar-based-safety-tech-438812 [secondary] |
| Odyssey | World-model lab | Odyssey-3 "drove a car on real roads in India" | Driving policy trained on about 20 h of data, which most reports call simulated | None | thenextweb.com/news/odyssey-3-world-model-robots-humanoids-cars-drones (Sep–Oct 2026) [secondary]; simulated vs. real data is disputed [UNCERTAIN] |
| Applied Intuition | AV software and simulation vendor | New Bangalore office ("engineering team and a go-to-market function"); sells to "Indian customers across automotive (passenger and trucking)" | Wants to "glocalize" its tech for India | None found | builtin.com/job/business-development-lead/6408511 (posting removed 2025-12-03) [primary, job-post mirror] |
| ARAI (Swayam-GO) | Government-backed test agency | "Indian Specific Traffic & Infra Database": synchronous camera, LiDAR and radar; Indian classes such as auto rickshaw and bikes | 30–40k km of its own testing. The director says "Many OEMs are already collecting this data" and calls data ownership an open question. | Reports say OEMs can license the raw data or annotated scenarios, so OEMs would pay **ARAI**. That makes ARAI a competitor, not a buyer. Terms are unpublished. | araiindia.com/?p=3644 (undated) [primary]; autocarpro.in/interview/building-indias-road-to-autonomous-safety-131585 (2026-03-11) [secondary]; ackodrive Swayam-GO article (licensing claim, page 403) [UNCERTAIN] |
| Mahindra (+Mobileye) | OEM and Tier-1 | L2 ADAS leader in India in 2025; the Mobileye tie-up is expanding to 6+ models | Mobileye: "specifically trained to identify cows" and adapted for missing lane markings. Per Smartprix, a Mahindra executive said imported ADAS software did not understand Indian roads. | The OEM pays the Tier-1 for localised ADAS. No raw-data purchase found. | mobileye.com/blog/mobileyes-adas-poised-to-power-indias-safety-shift/ (2025-06-18) [primary]; counterpointresearch.com (Mahindra–Mobileye) [secondary]; smartprix.com/bytes/is-adas-suitable-for-indian-road/ [secondary] |
| Tata Motors | OEM | ADAS across its SUVs | "localised sensor fusion" and "robust local validation"; suppliers HL Klemove and Aptiv have India design offices | None found | autocarindia.com/interviews-amp/tata-motors-cpo-mohan-savarkar-on-tuning-adas-for-indian-roads-usage-patterns-440552 (2026-05-24) [secondary] |
| Maruti Suzuki / SRDI | OEM R&D | Plans low-cost ADAS as standard across its range | SRDI is studying Indian conditions to "collect accurate driving data", but leans on simulation and HIL "without the need for millions of kilometres" | None found | suzukirndindia.com/blogs/built-india-ready-world-srdis-self-driving-technology (2026-02-12) [primary] |
| Aumovio (ex-Continental) | Tier-1 | Bengaluru R&D; single-camera L2 for India's mass market | "We have completed extensive trials on Indian roads" | None found | just-auto.com/news/aumovio-india-single-camera-adas/ (quoting ET Auto) [secondary] |
| Bosch (BGSW) | Tier-1 and engineering services | India-specific use cases: animals, auto rickshaws, motorcycles | Offers customers "data collection/labelling" services | **Sells** data services. Buying from outsiders not found. | autocarpro.in/interview/bosch-is-taking-a-comprehensive-approach-to-safety-sandeep-nelamangala-124408 (2025-01-23) [secondary] |
| KPIT | Engineering services | India-specific ADAS developed with ARAI | "data-driven ADAS validation using scenario and data foundries" | None found | autocarpro.in/news/kpit-technologies-showcased-software-defined-mobility-solutions-at-siat-expo-2026-130823 (2026-02-03) [secondary] |
| Tata Elxsi | Engineering services | Annotation service (TESA) and synthetic scenario generation | A Tata Elxsi CTO op-ed argues that India-specific training data makes ADAS affordable | **Sells** annotation. Buying not found. | tataelxsi.com/services/generative-ai/tesa-data-annotation-services-and-solutions [primary]; autocarpro.in opinion "Democratising Safety..." (Sep 2025) [secondary] |
| Minus Zero | Indian AV startup (camera-only, end-to-end) | Bengaluru autopilot (May 2025); MoU with Ashok Leyland; "in talks" with Tata Motors | Model trained on "millions of unlabelled video frames", including dashcam footage and traffic feeds | Not stated. Small-startup budget. | openthemagazine.com/features/indias-first-vision-only-autonomous-car-was-built-for-chaos [secondary]; business-standard.com (Minus Zero autopilot, 2025-05-20) [secondary] |
| Swaayatt Robots | Indian AV startup | Bhopal; camera-only demos | Collects its own data | Last raise was $4M (Jun 2024). Inc42 says it "hasn't really sold their technology". No buying evidence. | entrepreneur.com/en-in/news-and-trends/swaayatt-robots-gains-usd-4-mn-to-propel-ai-and-autonomous/475367 [secondary]; inc42 [secondary, snippet only] |
| Netradyne / drivebuddyAI | Fleet video telematics | Huge Indian fleet video already in hand | Netradyne trains on "real Indian driving data" and says it has analysed 25B+ miles. drivebuddyAI's founder says foreign models failed in India, so "start collecting our own data"; it claims 3.5B km and plans "adjacent data businesses". | **These hold data and compete with an individual seller. They are not buyers.** | netradyne.com/in [primary]; autocarpro.in/news/drivebuddyais-long-road-to-safer-roads-131667 (2026-03-17) [secondary] |
| Genesys / Mappls / HERE | Map makers | Genesys: HD ADAS maps for 100k+ km of highways (Dec 2025). Mappls: HD maps inside MathWorks RoadRunner for Indian digital twins (Oct 2026). | HERE says Indian lane, sign and speed data is "fragmented" (Sep 2026) | Genesys collects with its own survey network, and Genesys licenses its maps. Buying crowd video not found. | autocarpro.in/news/genesys-launches-high-definition-adas-maps-for-national-highways-130209 [secondary]; blog.gaadikey.com/mappls-and-mathworks-partner-to-accelerate-adas-validation-for-indian-roads/ [secondary]; 5paisa.com/blog/fragmented-road-data-could-slow-advanced-driving-technology-in-india-here-technologies [secondary] |
| NATIX Network | DePIN data network | India is listed as a "GEM region": in-app GEMs, not $NATIX tokens | Collects phone footage (Drive&) and Tesla surround footage (VX360) | **Pays contributors in tokens or points.** Indian payout levels and VX360 support on Indian cars are unconfirmed. No data buyers are named. | natix.network/blog/introducing-gem-regions (2024-06-18) [primary]; natix.network/blog/natix-valeo-open-multi-camera-world-foundation-model (2026-01-22) [primary] |
| Ola / Krutrim | OEM and AI | 2024 roadmap: AV for two- and four-wheelers, plus aftermarket kits for its cabs | Its director said camera-only "is not 100% reliable" | Nothing found for 2025–26 | yourstory.com/2024/06/ola-krutrim-lays-roadmap-autonomous-vehicles-india [secondary] |
| Two-wheeler ADAS (Hero+Valeo, Ultraviolette) | OEMs | Two-wheeler ADAS is shipping in India | Radar-led rear and blind-spot rider assistance, not camera surround | None | autocarindia.com (Hero–Valeo, 438812) [secondary]; ackodrive.com/news/ultraviolette-x-47-crossover-launched-at-2-49-lakh [secondary] |

## Regulation-driven demand (India)
- **Final rule:** G.S.R. 834(E), dated 11 Nov 2025, the Central Motor Vehicles (Sixth Amendment) Rules 2025. It finalises the G.S.R. 184(E) draft of 20 Mar 2025 and covers buses and trucks (M2, M3, N2, N3):
  - **AEBS** under AIS-162: new models from 1 Jan 2027, all models from 1 Oct 2027.
  - **LDWS** (AIS-188), **DDAWS** (AIS-184), **BSIS** (AIS-186) and **MOIS** (AIS-187): new models from 1 Oct 2027, existing models from 1 Jan 2028.
  - Source: egazette.gov.in/WriteReadData/2025/267610.pdf [primary, read in full].
- **Draft, cars:** AEBS under AIS-185 becomes mandatory for new M1 models from 1 Oct 2030 and for all M1 from 1 Oct 2032.
  - M1 and N1 cars that are offered with AEBS must comply from 1 Oct 2028.
  - Steering standard AIS-193 from 1 Oct 2027.
  - Automated steering (ACSF) and emergency lane keeping (ELKS) for taxis from 1 Oct 2029.
  - The draft is open for 30 days of comment. Source: autocarindia.com/industry/morth-proposes-mandatory-aeb-for-all-cars-from-october-2032-441114 (2026-10-23) [secondary]. I did not find the gazette draft itself.
- **Bharat NCAP 2.0 (draft, AIS-197 Rev 1 per press):**
  - Five pillars; "Accident Avoidance" is worth 10 of 100 points, and AEB "remains optional".
  - A 5-star rating needs 70 points in 2027–29 and 80 points in 2029–31.
  - It replaces the current protocol in October 2027.
  - Source: autocarindia.com/car-news/govt-proposes-bharat-ncap-20-with-wider-crash-tests-and-tougher-ratings-438502 (2025-11-24) [secondary].
- **Test infrastructure:**
  - ARAI's ₹40 crore ADAS tracks recreate Indian scenarios such as unmarked lanes and non-perpendicular crossings, and include auto-rickshaw dummies (2026-03-11) [secondary].
  - The ARAI page maps the Indian AIS standards to UN R151, R159 and R152 and to EU rules: araiindia.com/?p=3644 [primary].
- **Market context:** ADAS adoption in India was 8.3% in H1 2025, per a JATO figure quoted in a Sandisk VP op-ed: autocarpro.in/opinion-column/indian-roads-need-india-specific-adas-data-pipelines-134672 (2026-09-12) [secondary].
- **What this means (my inference):**
  - Compliance means track tests against AIS standards that mirror UN and EU regulations. No regulator requires anyone to buy naturalistic road video.
  - Demand is indirect: to keep false alarms low in Indian traffic, OEMs and Tier-1 suppliers need Indian scenario data.
  - BSIS and MOIS sense to the side and just ahead of the vehicle. So **surround-camera data from trucks and buses in Indian mixed traffic** is a plausible niche from 2027. No buyer has said so publicly.

## Buying signals, strongest first
1. **Tesla collects in-house.** It pays its own drivers to gather camera data in Delhi and Mumbai, which proves the data has value to Tesla. It does not show Tesla buys from outsiders. (Table row) [secondary]
2. **ARAI licenses Indian sensor data to OEMs.** If confirmed, this shows OEMs will pay for Indian data, but to a state-backed body with a full sensor suite. The licensing terms are [UNCERTAIN].
3. **Uber AV Labs** is the clearest "data as a product" effort, but it is free today ("At least not yet"). It plans to collect through fleet partners' vehicles. If it comes to India, it is both a channel and the biggest competitor for an individual seller. [secondary]
4. **NATIX** pays contributors in tokens for Tesla surround footage and has a Valeo partnership. India has a "GEM region" with in-app points (2024). The value of Indian payouts is unknown. [primary]
5. **Generic AI video licensing:** AI companies reportedly pay **$1–4 per minute** of unused video. Troveo says it has paid creators over $5M. Named buyers are Google, OpenAI and Moonvalley. Source: artificialintelligence-news.com/news/ai-giants-pay-thousands-for-creators-unused-footage-to-train-models/ (2025-01-15) [secondary]. This is **not specific to driving**, and dashcam footage is not mentioned.
6. **Marketplace listings:** Datarade lists "Indian Traffic Videos (MP4)" and an "Annotated Indian Traffic Dataset" from Ainnotate (India). Both are **auto-generated, unclaimed** listings, and the live page says Ainnotate "has not published pricing" [primary, datarade.ai/data-products/raw-indian-traffic-videos-mp4-ainnotate]. Search snippets showed USD 9,000 for 150K annotated images and USD 12,000 for raw video. **I could not confirm either price on the live page** [UNCERTAIN].
7. **NAYAN** (Delhi) is an Indian precedent of crowdsourced phone dashcams in vehicles, with "17,000+ drivers" (NITI frontier-tech page, undated) [secondary]. Claims that drivers are "paid digitally on a daily basis" come from IndiaAI and YourStory 2020 snippets that I could not open [UNCERTAIN]. NAYAN's customers are traffic police and smart cities, not AV companies.
8. **Not found:** listings or India driving-collection gigs from Shaip, FutureBeeAI, Defined.ai, Appen or TELUS. Targeted searches returned nothing, which does not prove they don't exist. I also found no paid India programme from Hivemapper/Bee Maps, Nexar or DIMO.

## Dead ends and things that did not hold up
- **NVIDIA PhysicalAI-AV:** the country table has no India entry [primary].
- **Wayve in India:** none found. One search summary mentioned a Marklines directory listing of a "Wayve-related office in Gurgaon", which I did not verify [UNCERTAIN].
- **Waymo:** 2026 targets are US cities plus London and Tokyo. No India plans found [secondary].
- **comma.ai:** no evidence that it pays for data.
- **Mobileye REM mapping in India:** not found.
- **Hivemapper / Bee Maps:** coverage is strongest in North America, Europe, Korea and Japan, with Lagos, Nairobi and Manila mentioned. No India evidence. The Bee Maps "Asia expansion" blog returned 404.
- **Ola Krutrim AV:** nothing after the June 2024 roadmap.
- **Swaayatt and Minus Zero:** no 2025–26 funding rounds found.
- **Tesla FSD in India:** still pending in mid-2026 reports. No approval found.
- **Decart Oasis 3** (a driving world model): training-data source undisclosed (TechCrunch, 2026-06-10).
- **LightMetrics** reportedly trained its Indian model on Latin American data (2023). The source page returned 403 [UNCERTAIN].
- **Axios: "AV Labs has deals with Nvidia and Wayve."** Page returned 403 [UNCERTAIN]. A separate S&P item names Avride, Waymo and WeRide as data recipients and mentions Nvidia only as the compute platform.
- **Odyssey's India drive** is not evidence of anyone buying Indian data: the policy reportedly used simulated data.

## Open questions
1. **Would any buyer accept a phone rig** with rolling shutter and no LiDAR, RTK GNSS or CAN data? ARAI reportedly found dashcam-only data "about 80%" as accurate as its full sensor set (ackodrive, page 403) [UNCERTAIN]. Ask buyers directly before building.
2. **No public price exists for Indian surround video.** The only anchors are generic video at $1–4/min, NVIDIA's 7-camera dataset given away free under its licence, and Uber AV Labs, which is free for now.
3. **Privacy and consent:** ARAI masks faces and plates, while Uber's notice says it does not blur faces. What does Indian data-protection law require before footage can be sold? This is for the legal and regulatory track.
4. Does NATIX VX360 work on the Model Y sold in India, and does India now earn $NATIX tokens or only GEMs?
5. Is Uber AV Labs collecting in India, and are fleet partners paid for fitting sensor kits?
6. Who will validate BSIS and MOIS on Indian buses and trucks in 2027–28, and with what data? This is a possible niche for surround rigs on commercial vehicles.
7. Do Tier-1 and engineering-services firms (Bosch BGSW, KPIT, Tata Elxsi) ever subcontract road-data collection to small outside teams, or only use their own fleets? Job posts or a direct ask would answer this.
