# 04 — Indian law for collecting and selling street driving video

Researched 2026-11-24 with light web research by one agent. **This is not legal advice.** It is a map of the rules
and how sure we are of each one. Talk to an Indian tech/privacy lawyer before the first sale, and before any sale abroad.

Tags: `[primary]` = text of a statute, rule or guideline (section + URL); `[primary via mirror]` = the same text read
from an unofficial copy because the government URL failed on 2026-11-24 (dst.gov.in 404, meity/indiacode 403,
surveyofindia/geospatial.dst/egazette TLS errors); `[secondary]` = law-firm/news summary (URL + date);
`[inference]` = my reading; `[UNCERTAIN]` = could not confirm.

## TL;DR

- **Collecting is allowed without a licence, but only for an "Indian Entity".** The 2021 geospatial guidelines need no
  prior approval, and they reserve "Street View survey" and "Terrestrial Mobile Mapping survey" for Indian Entities
  "irrespective of accuracy". An Indian citizen, or a company owned or controlled by resident Indian citizens, qualifies.
  A foreign company cannot collect itself; it can only license from you. `[primary via mirror, ¶7(f), ¶8(ii), ¶8(vi)(b)]`
- **Selling abroad is the hard part.** Geotagged data coarser than **1 m horizontal / 3 m vertical** may be exported. Anything
  finer must stay on servers in India. Foreign buyers may then use it only through an API that keeps the data off their
  servers, only to serve customers in India, and may not re-use or resell it. A training-data sale cannot meet those
  terms. Consumer GPS is coarser than 1 m, but synchronized multi-camera video with RTK or SfM poses can be finer.
  `[primary via mirror, ¶8(iv), ¶8(vii)–(x)]` `[inference]`
- **Privacy law is not fully in force yet.** The DPDP Rules were notified on 13/14 Nov 2025. Consent, notice, the
  exemptions and the cross-border section all start about **13 May 2027**. After that, identifiable faces (and very
  likely number plates) in your video are personal data. You cannot get consent from passers-by, and there is no
  general "legitimate interests" ground. So **blur faces and plates when you record** (on the device, or before the
  footage leaves your machine). `[primary via mirror]` `[secondary]`
- **DPDP itself barely limits sending data abroad.** Section 16 lets the government blacklist countries, and none are
  named. The real export limits are the geospatial guidelines and DST's Nov 2022 memo, which bars "derived products"
  finer than the threshold from any non-Indian entity's servers. `[primary]` `[secondary]`
- **There is a criminal risk.** Under the Official Secrets Act a "sketch" includes any photograph. Being near or recording
  a "prohibited place" (defence establishments, and roads or railways the government notifies) for a purpose "prejudicial
  to the safety or interests of the State" can carry up to 14 years, and s.3(2) lets a court infer that purpose from the
  circumstances. Remove those segments, and do not record in cantonments.
  `[primary via mirror]`

## 1. DPDP Act 2023 and DPDP Rules 2025

**Status.** The Act was enacted on 11 Aug 2023 `[primary: PIB backgrounder, 17 Nov 2025, https://static.pib.gov.in/WriteReadData/specificdocs/documents/2025/nov/doc20251117695301.pdf]`.
The Rules' date is reported differently: PIB says "DPDP Rules notified on 14 November 2025"; most law firms give the gazette date as 13 Nov 2025 `[secondary: Hogan Lovells, https://ca.hoganlovells.com/en/publications/indias-digital-personal-data-protection-act-2023-brought-into-force-]` **`[UNCERTAIN: 13 vs 14 Nov]`**.
The commencement notification (reported as G.S.R. 843(E)) has three stages `[primary via mirror: https://www.dpdpa.com/dpdpa_enforcement_timeline.html; G.S.R. number UNCERTAIN]`:
- **From publication:** "sub-section (2) of section 1, section 2, sections 18 to 26 sections 35, 38, 39, 40, 41, 42, 43" (definitions and the Data Protection Board).
- **After 1 year (~13 Nov 2026, now in force):** "sub-section (9) of section 6 and clause (d) of sub-section (1) of section 27" (Consent Managers).
- **After 18 months (~13 May 2027):** "sections 3 to 5, sub-sections (1) to (8) and (10) of section 6, sections 7 to 10, sections 11 to 17 … sections 28 to 34, 36, 37 and sub-section (2) of section 44". These cover scope, consent, notice, duties, rights, cross-border transfer, the exemptions, penalties, and the repeal of IT Act s.43A.
- In Jan–Feb 2026 MeitY proposed cutting the timeline "from 18 months to 12 months" (some reports say only for Significant Data Fiduciaries) `[secondary: S.S. Rana, 13 Feb 2026, https://ssrana.in/articles/meity-plans-to-cut-short-dpdp-compliance-timeline-and-notify-cross-border-restrictions-for-sdfs/]`. **I found no notified amendment `[UNCERTAIN]`.** The only 2026 instrument I found is a Removal of Difficulties Order dated 5 Oct 2026. It makes wording fixes to ss.9(1) and 10(2)(c)(ii) `[secondary: SCC Online, 15 Oct 2026, https://www.scconline.com/blog/post/2026/10/15/dpdp-removal-of-difficulties-order-2026/]`.
- `[inference]` The Act regulates "processing", which includes storage, use and sharing. Raw footage you collect today but still hold or sell after May 2027 will therefore be covered. Blur now.

**Are faces and plates personal data?** s.2(t): personal data is "any data about an individual who is identifiable by or in relation to such data" `[primary via mirror: https://www.dpdpa.com/dpdpa2023/chapter-1/section2.html]`.
- A clear face is personal data under that wording `[inference]`. Nishith Desai (NDA) says a vehicle that "capture[s] street images in a public space and incidentally captures pictures of individuals' faces" "may be required to provide notice to each such individual" and "would be required to obtain consent from all such individuals" `[secondary: NDA via NatLawReview, 19 Aug 2024, https://natlawreview.com/article/impact-indias-new-privacy-law-geospatial-industry]`.
- **Number plates: I found no Indian ruling or official guidance `[UNCERTAIN]`.** A plate identifies the registered owner through the transport registry, so it is very likely "identifiable … in relation to such data" `[inference]`. S&R Associates says plates "may constitute personal data", but in a GDPR comparison `[secondary: https://chambers.com/articles/s-r-data-defining-the-scope-of-personal-data-in-digital-india; date not checked]`.
- The Act does not define "anonymised". Data that identifies no one falls outside s.2(t) `[inference]`.

**Lawful basis.** s.4(1) allows processing only "(a) for which the Data Principal has given her consent; or (b) for certain legitimate uses" `[primary via mirror: …/chapter-2/section4.html]`.
The s.7 "legitimate uses" (clauses a–i) cover voluntarily provided data, State functions, legal obligations, court orders, medical emergencies, disasters and employment. None is a general "legitimate interests" ground `[primary via mirror: …/chapter-2/section7.html]`. NDA's view: "Commercial collection of map data in numerous use cases is unlikely to be covered" `[secondary, 2024]`.
- **Personal or domestic use** (s.3(c)(i)) covers a private dashcam. It does not cover selling the footage `[primary via mirror: …/chapter-1/section3.html]` `[inference]`.
- **"Publicly available"** (s.3(c)(ii)) covers data "made or caused to be made publicly available by" the person or by someone legally obliged to publish it. The Act's example is a blogger. Whether walking down a road counts is open. NDA asks if it means entities "can freely capture faces of individuals in public" `[secondary, 2024]`. **Do not rely on it `[UNCERTAIN]`.**
- **Research** (s.17(2)(b)) applies "if the personal data is not to be used to take any decision specific to a Data Principal" and the processing meets prescribed standards. Rule 16 points those standards to the Second Schedule `[primary via mirror: …/chapter-4/section17.html, https://dpdpa.com/dpdparules/rule16.html]`. It has **not started yet** (18-month tranche).
  - Whether commercial AI training qualifies is disputed. Cyril Amarchand reads the Delhi HC's 24 Jul 2026 interim ruling in *ANI v OpenAI*, a copyright case, as making the research exception "likely" easier to meet. It adds that this "does not finally resolve how the DPDPA will apply to AI training" `[secondary: 3 Aug 2026, https://corporate.cyrilamarchandblogs.com/2026/08/research-rejuvenated-ani-v-open-ai-and-the-dpdpa/]`.

**Duties and penalties.** A Data Fiduciary is "any person who alone or in conjunction with other persons determines the purpose and means of processing" (s.2(i)). That includes an individual collector `[primary via mirror]`.
Duties start in May 2027: notice, consent, security safeguards, breach notices, erasure, a contact person, and answering rights requests within 90 days `[primary: PIB backgrounder]`. Maximum penalties: "up to ₹250 crore" for failing security safeguards, "up to ₹200 crore" each for breach-notification and children's-data failures, and "up to ₹50 crore" for anything else `[primary: PIB backgrounder]`.
Until s.44(2) starts, IT Act s.43A and the SPDI Rules 2011 still apply. They cover only "sensitive" data held by a body corporate. Whether raw street video counts as "biometric" under them is `[UNCERTAIN]`.

**Cross-border.** s.16(1): the government "may, by notification, restrict the transfer … to such country or territory outside India as may be so notified". s.16(2) keeps any stricter Indian law in force `[primary via mirror: …/chapter-4/section16.html]`.
Rule 15 allows transfer subject to any requirements the government sets on "making such personal data available to any foreign State" `[primary via mirror: https://dpdpa.com/dpdparules/rule15.html; the page does not say if it is the final text]`. No countries have been notified `[UNCERTAIN: none found]`.
A foreign buyer that offers no goods or services to people in India is probably outside s.3(b). The Indian collector stays liable for what it shares `[inference]`.

**What blurring buys you.** NDA calls blurring "at the time of collection of data" the practical fix for notice and consent `[secondary, 2024]`.
Google and Apple blur faces and plates in published street imagery. Apple says it "uses blurred imagery to improve other Apple products and services", which includes training models `[primary: https://maps.apple.com/imagecollection/in]`.
- What blurring does **not** fix: your own unblurred raw copy (still personal data), faces or plates the blur misses, re-identification from the vehicle, place and time, audio, and the occupants of your own car.
- `[inference]` AV buyers may ask for unblurred pedestrians. Treat that as a separate, consent-only product.

## 2. Geospatial rules

**The 2021 Guidelines are still the text that applies.** DST F.No.SM/25/02/2020 (Part-I), "dated 15th February, 2021" `[primary via mirror: https://www.slideshare.net/dev3/final-approved-guidelines-on-geospatial-data; official URL https://dst.gov.in/sites/default/files/Final%20Approved%20Guidelines%20on%20Geospatial%20Data.pdf returned 404]`:
- ¶7(c) Geospatial Data: "Positional data with or without attribute data tagged, whether in the form of images, videos, vector, voxel and/or raster datasets…". **Geotagged driving video is in scope.**
- ¶7(f) Indian Entity: "Any Indian citizen, … or any Indian company or Indian LLP owned by resident Indian citizens or … controlled by resident Indian citizens (as defined in the Explanation to Rule 23 of the Foreign Exchange Management (Non-Debt Instrument) Rules, 2019)".
- ¶8(ii)(1): "Save as specifically provided for under these guidelines, there shall be no requirement for prior approval". Also: "Self-certification will be used to convey adherence to these guidelines."
- ¶8(iii)(a): "There shall be a negative list of sensitive attributes that would require regulation before anyone can acquire and/or use such attribute data."
- ¶8(iv)(a) threshold: "On-site spatial accuracy shall be one meter for horizontal or Planimetry and three meters for vertical or Elevation."
- **¶8(vi)(b): "Terrestrial Mobile Mapping survey, Street View survey and surveying in Indian territorial waters shall be permitted only for Indian Entities irrespective of accuracy."**
- ¶8(vii): data "finer than the threshold value can only be created and/or owned by Indian Entities and must be stored and processed in India."
- ¶8(viii): foreign companies, and Indian companies they own or control, "can license from Indian Entities" data finer than the threshold "only for the purpose of serving their customers in India". Access is "only … through APIs that do not allow Maps/Geospatial Data to pass through Licensee Company or its servers", and "Re-use or resale of such map data by licensees shall be prohibited."
- ¶8(ix) and ¶8(x): data up to the threshold "can be uploaded to the cloud". "There shall be no restriction on export of Maps/Geospatial Data of spatial accuracy/value up to the threshold value except for attributes in the negative lists."
- ¶8(xv): "Any violation of these guidelines will be dealt with under the applicable laws." The guidelines name no penalty of their own.
- The guidelines do not define "street view survey" or "mobile mapping": "Since the terms have not been defined, it is difficult to ascertain the activities which the Guidelines seek to restrict" `[secondary: Nishith Desai, 18 Feb 2021, https://www.nishithdesai.com/default.aspx?id=4678]`.

**DST clarification memo, 28 Nov 2022.** The PDF returned 404, so I have only search-engine excerpts and summaries `[UNCERTAIN wording]`:
- "All foreign entities including their group and/or sister organisations, that do business and operate in India will be governed by these guidelines."
- "Foreign entities cannot capture data better than the thresholds given above."
- "Under no circumstance will mapping data or its derived products of quality better than the defined threshold quality will be allowed to be transmitted to or reach the servers of any non-Indian entity in India or abroad."
- It also reportedly treats "general nations" differently from other countries; I could not read the details.
- Sources: [DST URL](https://dst.gov.in/sites/default/files/DST%20OM%20dated%2028th%20November%202022.pdf) and the [JSA Prism note, Jan 2023](https://jsalaw.com/wp-content/uploads/2023/01/JSA-Prism-Telecommunications-January-2023-Geospatial.Final0750.pdf) (403).

**National Geospatial Policy 2022.** "S.O. 6095(E).—The Union Cabinet, in its meeting held on 16.12.2022, approved the National Geospatial Policy, 2022" `[secondary: search excerpt of the gazette; MEA copy 404]`. Summaries say the data guidelines continue "in its present form or as stipulated by DST from time to time" `[secondary, UNCERTAIN wording]`.
- No 2023–2026 amendment found `[UNCERTAIN: the DST site was mostly unreachable]`.
- The restrictions were still in place in April 2025, when the US industry group CCIA asked India to allow "foreign service providers to create and own geospatial data above the threshold", to allow "reuse and resell[ing]", and to remove domestic storage `[secondary: CCIA, Apr 2025, https://ccianet.org/wp-content/uploads/2025/04/Indias-Barriers-to-U.S.-Digital-Service-Suppliers-and-Suggested-Commitments.pdf]`.

**What this means for driving video `[inference]`:**
- A car with synchronized cameras and GNSS/IMU is essentially a mobile-mapping rig, so assume ¶8(vi)(b) applies. You must be an Indian Entity.
- Taking money from a foreign investor that results in foreign ownership or control can cost you that status.
- Data tagged only with consumer-GPS positions (typically a few metres off), with negative-list attributes removed, reads as exportable under ¶8(x).
- Do not supply RTK/PPK poses, lidar or HD-map layers finer than 1 m to foreign buyers.
- Precise geometry a buyer can rebuild from your calibrated multi-camera video may count as a "derived product" finer than the threshold. Nobody has tested this `[UNCERTAIN]`.

**How Street View came back (27 Jul 2022).** Google said: "fresh imagery that we have licensed from our local partners" (Genesys International, Tech Mahindra), and "Street View data collection is being brought to life completely by local partners" `[primary: Google India blog, https://blog.google/intl/en-in/products/explore-communicate/google-announces-local-partnerships-to-build-a-more-helpful-maps-experience-in-india/]`.
TechCrunch reported: "They own the data that they collect, but then they license it to entities like Google". India had "rejected Google's plans … in 2016" `[secondary: TechCrunch, 26 Jul 2022, https://techcrunch.com/2022/07/26/google-street-view-india/]`.
**That is the pattern to copy: an Indian entity collects and owns the data, and foreign companies license it.**

## 3. Other constraints

- **Official Secrets Act 1923** `[primary via mirror: https://www.idsa.in/system/files/Official_Secret_Act1923.pdf]`
  - s.2(9): "'sketch' includes any photograph or other mode of representing any place or thing".
  - s.2(8)(a): a prohibited place includes "any work of defence, arsenal, naval, military or air force establishment or station, mine, minefield, camp, ship or aircraft belonging to, or occupied by or on behalf of, Government". Under s.2(8)(d), roads and railways can be made prohibited places by notification.
  - s.3(1): it is an offence if anyone, "for any purpose prejudicial to the safety or interests of the State", "approaches, inspects, passes over or is in the vicinity of, or enters, any prohibited place" or "makes any sketch … useful to an enemy". The maximum is fourteen years for defence matters and three years otherwise.
  - s.3(2) lets the prejudicial purpose be presumed from "the circumstances of the case or his conduct".
  - The Bombay HC held that the s.2(8) list "is an exhaustive definition": a police station is not on it `[secondary: ThePrint, 23 Dec 2022, https://theprint.in/judiciary/clicking-photos-of-police-station-doesnt-violate-official-secrets-act-bombay-high-court/1278308]`.
- **Negative list of sensitive attributes.** DST said it would publish one. Restrictions can be relaxed where an attribute is "displayed through public notices/signages", with the owning ministry's permission `[secondary: OSM talk-in, 16 Aug 2022, https://lists.openstreetmap.org/pipermail/talk-in/2022-August/003580.html]`. The list itself returned 404 `[UNCERTAIN: contents]`.
- **Dashcams.** I found no statute that bans them, but the sources were only blogs and vendor pages `[UNCERTAIN]`. MV Act s.125: "No person driving a motor vehicle shall allow any person to stand or sit or to place anything in such a manner or position as to hamper the driver in his control of the vehicle" `[primary via mirror: https://lawgist.in/motor-vehicles-act-1988/125]`. I found no state rule on private dashcams or on selling their footage `[UNCERTAIN; not searched exhaustively]`.
- **IT Act.** s.43A and the SPDI Rules apply until about May 2027 (see §1). s.66E (capturing images of a person's private area) could matter for footage shot into homes or changing areas `[UNCERTAIN: not re-read this session]`.
- **Export control and localisation.** DPDP has no general localisation rule. Significant Data Fiduciaries "must follow government directions on restricted categories of data, including local storage where needed" `[primary: PIB backgrounder]`; the government designates them, and a small collector is unlikely to be one `[inference]`.
  - The localisation that does bind you is the geospatial one: finer-than-threshold data stays in India (¶8(vii), ¶8(ix)). I found no sign that street imagery is on India's export-control list (SCOMET), but I did not check it `[UNCERTAIN]`.

## 4. How existing players handle it

| Player | Model | What they say publicly |
|---|---|---|
| Google Street View | Indian partners (Genesys, Tech Mahindra) collect and own the imagery; Google licenses it | "licensed from our local partners" `[primary, 2022]`. Press reports said faces and plates would be blurred `[secondary: 2022 news, search excerpt]`; Google's India post does not mention it |
| Apple Look Around | Live in India since 18 Nov 2026 (Apple: "Now users anywhere in the world can explore with Look Around in India") `[primary: https://www.apple.com/in/newsroom/2026/11/apple-rolls-out-all-new-map-across-india/]`. India vehicle surveys listed for Mar–Jul 2026 | Blurs faces and plates in published imagery; trains on blurred imagery `[primary: imagecollection page]`. Neither page names the Indian entity that collects. A Tech Mahindra link was reported in Feb 2025 `[UNCERTAIN]` |
| MapmyIndia (Mappls RealView) | Sells its own rig and runs collection as a service: "syncs the high resolution panoramic camera with a GNSS receiver and a high sensitivity accelerometer" `[primary: https://www.mapmyindia.com/realview]` | The page says nothing on blurring, compliance or ownership |
| Genesys International | 100+ mapping vehicles; HD maps for ADAS; HERE partnership in 2025 `[secondary: search excerpts (Autocar Pro, HERE press release)]` | Says it respects "India's privacy norms" `[secondary: Mobility Outlook, Jul 2025, search excerpt]` |
| Netradyne | Business-to-business fleet cameras; the fleet customer decides what is recorded, so it is not selling street data | "Blurring of faces and license plates"; "We store data on AWS servers in the United States"; SCCs for transfers. No DPDP section on the page `[primary: https://www.netradyne.com/legal/privacy]`. Its India agreement reportedly defines anonymised video as faces and plates blurred "to a commercially reasonable standard" `[secondary: search excerpt; page returned 401]` |
| Hivemapper/Bee, Mapillary | Crowdsourced, foreign-run | Bee blurs on the device `[secondary: docs.beemaps.com]`. I found no evidence of India operations or of how they meet ¶8(vi)(b) `[UNCERTAIN]` |

## 5. Checklist for a small collector

1. **Collect as an Indian Entity**: an Indian citizen, or a company/LLP owned or controlled by resident Indian citizens. Keep it that way. Self-certify that you follow the guidelines. (¶7(f), ¶8(ii)(1), ¶8(vi)(b))
2. **Store the raw data and anything finer than 1 m / 3 m in India**, on Indian servers or an Indian cloud region. Do not let it reach a non-Indian entity's servers. (¶8(vii), ¶8(ix); Nov 2022 memo)
3. **License data; do not transfer ownership.** Exports should be data up to the threshold with negative-list attributes removed. Finer data may go to a foreign buyer only through an API, only to serve customers in India, with no re-use or resale. (¶8(viii), ¶8(x); Google model)
4. **Keep away from prohibited places.** Geofence the cameras off near defence establishments, cantonments and notified areas, and obey "photography prohibited" signs. Remove such segments before any sale. (OSA s.2(8), s.2(9), s.3)
5. **Blur faces and plates on the device or before upload.** Measure how many the blur misses. Record no audio. Keep raw unblurred footage briefly and encrypted. (s.2(t); NDA 2024)
6. **Get consent where you can**: drivers, passengers and staff. Publish a privacy notice and a grievance contact. Have a security and breach plan ready before ~13 May 2027. (ss.4–8; PIB backgrounder)
7. **Do not build the business on the "publicly available" or "research" exemptions.** Neither is tested for this use, and the research one has not started. (s.3(c)(ii), s.17(2)(b), Rule 16)
8. **Buyer contract terms**: no re-identification; no decisions about individuals (this keeps s.17(2)(b) available); no resale; deletion when you ask; the buyer states its country of incorporation and that it is not on any s.16 list.
9. **Mount the camera so it never hampers driving.** (MV Act s.125)
10. **Get a written legal opinion** on two questions: whether your rig is a "street view / mobile mapping survey", and how the accuracy of your data, including derived poses, is classified. Get it before the first foreign deal. (NDA 2021: terms undefined)

## Dead ends

- Official copies unreadable on 2026-11-24: DST guidelines, the Nov 2022 memo and the negative-list PDF (**404**); DPDP Act at MeitY/indiacode and the JSA note (**403**); Survey of India, geospatial.dst.gov.in and egazette (**TLS errors**). I did not retry with certificate checks off. Re-check every "via mirror" quote against the gazette.
- dpdpa.com mixes the statutory text with commentary that contradicts it (for example, an "adequacy" regime under s.16 that is not in the Act). I used only its statutory-text blocks.
- **Draft DPDP Rules (Jan 2025)** were replaced by the final Nov 2025 Rules. Cite only the final text; the draft's rule numbers may differ `[UNCERTAIN: draft numbering not re-checked]`.
- **Geospatial Information Regulation Bill 2016** was never enacted. It was "as good as dead" by 2018 `[secondary: Hindustan Times via PressReader, 16 Oct 2018]`. Wikipedia still says "Pending" `[UNCERTAIN]`.
- The **draft NGP 2021** was replaced by NGP 2022.
- **MeitY's 2026 proposal** to shorten the DPDP timeline was a proposal only; I found no notification.
- **Dashcam "2026 encryption rules" and "s.177 obstruction"** claims come from blogs with no primary source. Dropped.
- I found no Indian authority on number plates as personal data.
- I found no published MapmyIndia or Genesys blurring policy.

## Open questions

1. Does a dashcam-style multi-camera rig count as a "Street View survey" or "Terrestrial Mobile Mapping survey"? The terms are undefined.
2. How is "on-site spatial accuracy" measured for video plus GNSS, and does geometry a buyer reconstructs count as your "derived product"?
3. Can the 2021 guidelines be enforced on their own? They are executive guidelines, and ¶8(xv) refers only to "applicable laws".
4. After May 2027, is blurred video outside "personal data"? Does s.3(c)(ii) ever cover people seen in public? Does s.17(2)(b) cover a commercial dataset sale?
5. Will MeitY shorten the DPDP timeline, or notify any s.16 country list, or cross-border limits for Significant Data Fiduciaries?
6. If a foreign buyer specifies the routes and pays for collection, is the buyer the one "conducting" the survey? Google's 2022 setup avoided this: the partners own the data.
7. What do the full Nov 2022 memo and the negative list actually say? Get the official copies.
