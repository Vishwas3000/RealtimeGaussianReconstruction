# Would anyone pay for multi-camera driving data of Indian roads?

Synthesis written 2026-11-24 from four research files plus spot-checks done by the lead session (marked `[measured]`).
It is not legal or financial advice. The tags in the detail files are: `[primary]` read at source, `[secondary]` from news
or snippets, `[UNCERTAIN]` not confirmed.

| File | Question |
|---|---|
| [01-demand-india.md](01-demand-india.md) | Who needs or buys Indian road data |
| [02-supply-india.md](02-supply-india.md) | What already exists, and who collects it |
| [03-pricing-and-requirements.md](03-pricing-and-requirements.md) | Prices, contributor pay, what buyers require |
| [04-legal-india.md](04-legal-india.md) | Indian law: geospatial guidelines, DPDP, Official Secrets Act |

## Answer

**The gap is real, the market is young, and nobody publicly pays individuals for this today.** The data that is
scarce is not hours of ordinary driving, which are cheap or free. It is calibrated, synchronized **surround** video of
Indian traffic, with vehicle motion and tagged events, blurred, and with clean rights.

## Evidence

**The gap**
- NVIDIA's 7-camera PhysicalAI-AV dataset covers 25 countries (the US plus 24 European) and has **0 India clips** `[measured]`.
- No public or purchasable surround dataset of Indian roads exists at any scale. The closest are IDD-3D (6 cameras,
  25 minutes of labelled clips, "coming soon") and TiAND (4 cameras, under a data agreement) (02).
- No crowdsourced network operates in India: NATIX VX360, Bee Maps, Nexar and DIMO are all absent (02).

**Value signals**
- Tesla paid its own operators to collect camera data in Delhi and Mumbai (2025) `[secondary]`.
- NATIX closed its phone app, citing what "Physical AI customers are prepared to pay for… multi-camera driving data" `[primary]`.
- Valeo is building a multi-camera world model on NATIX's Tesla footage `[primary]`.
- Uber AV Labs collects for 20+ AV partners. It is free today, with a fee planned later `[secondary]`.
- India's final rule G.S.R. 834(E) mandates AEBS, LDWS, DDAWS, BSIS and MOIS on buses and trucks in 2027–28 `[primary]`.
  The tests run on a track, so any demand for road data is indirect.

**Who would compete with you rather than buy**
- Netradyne, drivebuddyAI (six-camera trucks) and ARAI already hold Indian video or multi-sensor data.
- MapmyIndia, Genesys, Ola and Apple own 360° fleets, but they hold map panoramas, not dataset video (01, 02).

**The only published price for this exact product**
- DrivingFootage.com sells 9 synchronized 4K cameras covering 360°. It charges **$100 per hour of combined footage** for
  regional packages ($65,100 and $113,600) and **$85/h for the full library** (~$150,000). The listing says this means
  ~1,750 combined hours ≈ 195 hours of driving. That works out to **≈$765–900 per hour of actual driving**.
- The licence is non-exclusive. The seller says "a major AI developer licensed part of our library." These are asking
  prices: volume and actual sales are unknown `[measured: datarade.ai/data-providers/drivingfootage-com/profile and the full-library product page]`.

**Other price anchors**
- Bee Maps: $6 per event clip, $0.005 per image `[primary]`.
- Generic AI-training video: $1–4 per minute `[secondary]`.
- NVIDIA's 1,700 h of data and nuScenes are free under restrictive licences (03).

**Crowdsourcing pays drivers little**
- NATIX advertises "up to $60/month" in tokens, worth ≈$21 at today's price.
- Several reward programmes closed in 2026.
- Solana DePIN networks paid >$100M in rewards against $17M of revenue in 2025 (03).

## Two kinds of buyer

| Buyer tier | Accepts | A DIY synced-phone rig |
|---|---|---|
| Generative-video / world-model labs | timecode-level sync, nominal calibration, consumer GPS | **can pass**, if you measure and document the sync offset, lock lenses and turn off stabilization, calibrate each mounting, and tag events |
| AV perception / 3D-label buyers | hardware-triggered sync, rolling-shutter timing, cm-level pose, CAN, usually LiDAR | **fails**. A one-frame software sync error is 0.23–0.46 m of travel at 50–100 km/h (03) |

## Legal shape

Not legal advice. The 2021 geospatial guideline clauses were checked on the **official Survey of India page** `[measured]`.

- **You may collect.**
  - ¶8(vi)(b): "Terrestrial Mobile Mapping survey, Street View survey … shall be permitted only for Indian Entities
    irrespective of accuracy."
  - ¶7(f): an Indian Entity includes "Any Indian citizen" and companies owned or controlled by resident Indian citizens.
  - Foreign firms cannot collect themselves. They license from an Indian entity, which is how Google Street View works through Genesys and Tech Mahindra.
- **What can leave India.**
  - The threshold is **1 m horizontal / 3 m vertical** (¶8(iv)).
  - Data finer than that "can only be created and/or owned by Indian Entities and must be stored and processed in India" (¶8(vii)).
  - Foreign licensees may use it only "for the purpose of serving their customers in India", only through APIs that keep
    it off their servers, and "Re-use or resale … shall be prohibited" (¶8(viii)).
  - Data up to the threshold has "no restriction on export … except for attributes in the negative lists" (¶8(x)).
  - **So a foreign training-data sale needs coarse positions: consumer GPS, no RTK or HD geometry.** Whether geometry
    a buyer reconstructs from your video counts is untested.
- **Privacy (DPDP).** Most duties start ≈13 May 2027. Faces, and very likely number plates, are personal data, and
  passers-by cannot consent. **Blur at capture**, keep raw footage briefly and encrypted in India, and record no audio (04).
- **Official Secrets Act.** Recording near defence or notified places carries criminal risk. Geofence those places out (04).

## What to do, if this is worth pursuing (Claude's recommendation)

1. **Ask buyers before building anything.** Make a 1–2 hour sample that is calibrated, synced, blurred and documented,
   with events tagged. Then ask 5–10 likely buyers whether they would pay, how much, and to what spec: Indian AV
   startups, Tier-1 and engineering-services firms, NATIX, Uber AV Labs, world-model labs, and a Datarade-style listing.
   No public price exists for Indian surround video, so only buyers can set one.
2. **Aim at what is scarce in India**, not plain kilometres: dense mixed traffic, two-wheelers and autos, unmarked roads,
   animals, monsoon and night. Two-wheeler and truck/bus surround footage are open niches. The bus and truck niche lines up
   with the 2027–28 BSIS/MOIS rules (01, 02).
3. **Sell first to world-model and generative buyers**, where a phone rig can pass. Selling to AV perception buyers needs a
   hardware-synced rig with RTK/IMU and CAN.
4. **Stay legally clean.** Collect as an Indian Entity. Export only coarse positions. Blur at capture. Geofence sensitive
   sites. Get a lawyer's written opinion before the first foreign deal.
5. **It feeds the learning roadmap anyway.** This same footage is the input for roadmap stages 1, 6 and 7, so even with
   no buyer it becomes your own reconstructions and a portfolio.

## Not verified

- Whether any buyer would pay for *Indian* data specifically, or at what premium. No public price exists.
- DrivingFootage's actual sales volume.
- ARAI's licensing terms.
- Whether Uber AV Labs collects in India.
- IDD and IDD-3D licence texts.
- The DST Nov 2022 memo and the negative list. Both were unreadable at source.
- The DPDP Rules date (13 vs 14 Nov 2025).
- Whether a dashcam-style rig legally counts as a "street view survey". The guidelines don't define the term.
