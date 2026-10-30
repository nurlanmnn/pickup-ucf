# Age-rating proposal — October 30, 2026

**Completed, saved and reload-verified:13+ on current OS;12+ before OS26.**
The owner confirmed rare occurrences for profanity, substance references and
mild suggestive themes. The questionnaire was completed in a separate App
Information tab. Reviewer fields were preserved.

[Apple's definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)
were checked against current source and the live questionnaire. Proposed answers:

| Question | Proposal |
| --- | --- |
| Parental controls; age assurance | No |
| Unrestricted web access; advertising | No |
| User-generated content; messaging/chat | Yes |
| Social media | Yes, conservatively classify public Discover/session interaction |
| Social media disabled under13 | No; no Declared Age Range API gate |
| Profanity/crude humor; alcohol/drug references; mild suggestive themes | Infrequent, owner-confirmed expectation |
| Horror/fear; medical/treatment; health/wellness recommendations | None/No |
| Sexual content/nudity; graphic sexual content | None |
| Cartoon/fantasy violence; realistic/graphic violence; weapons | None |
| Gambling; simulated gambling; loot boxes | None/No |
| Contests | Frequent, conservative interpretation of recurring pickup sport competition |

The source evidence is `DiscoverView`, `ChatRepository`,
`Core/Validators/UserContentPolicy.swift`, `SportType` and published Community
Guidelines. Text validation blocks selected threats/slurs, explicit solicitations,
web links and phone solicitations; it is not a complete objectionable-content
filter. Reporting/blocking and moderator removal do not guarantee every violating
post is intercepted before another player sees it. The infrequent answer is the
owner's expectation, not a measured rate or approval to seed objectionable material.

Sport scheduling is not medical advice or an exercise-recommendation feature.
The app has no digital match scoring, betting, prizes or randomized purchases;
the contest proposal concerns the real-world games it organizes. Fixed external
policy/provider links do not provide unrestricted in-app browsing.

The older external-beta packet's conditional Social Media No proposal is
superseded for this draft by the conservative Yes interpretation. Preserve all
other release gates. Step7 calculated13+; Not Applicable remained selected for
age category/override, no Kids category, no higher override and no optional
suitability URL. The app Terms have no higher contractual age minimum. Saved the
wizard and parent App Information form; no review submission occurred.

Reload confirmed13+ for171 countries/regions,16+ for two, Brazil's separate
rating and15+ for Korea. The US/current-OS result is13+; the page states global
12+ with regional exceptions for operating systems earlier than26. Availability
remains US-only; the regional calculation is not a territory expansion.
Nonprivate evidence: `/tmp/pickup-age-rating-saved.png`.
