# Incident Response Report Template — ADGuard

**Why this format:** this follows the four phases from [NIST SP 800-61 Rev. 2](https://csrc.nist.gov/pubs/sp/800/61/r2/final) — Preparation, Detection & Analysis, Containment/Eradication/Recovery, Post-Incident Activity. Writing every test run up this way, instead of as a build log ("I did X then Y"), is what turns this project into a demonstration of incident-handling process rather than a record of following instructions.

**How to use this file:** copy the template block below for every test run of every scenario. Fill it in the same day you run the test — timestamps and reasoning fade fast, and a report written from memory a week later is noticeably thinner than one written in the moment.

---

## Template (copy this block for each new report)

**Incident ID:** `ADGUARD-YYYY-MM-DD-0N`
**Scenario:** [1 — Anomalous Remote Logon / 2 — Brute-Force Attempt / 3 — Privilege Escalation]
**Analyst:** [your name]
**Severity:** [Low / Medium / High]
**Status:** [Open / Contained / Closed]

### 1. Preparation
- Detection rule active: `[alert name]`
- Data source confirmed flowing: `index=adguard_ad`, from host(s) `[ ]`
- ATT&CK technique this detection targets: `[T-number]`

### 2. Detection & Analysis
| Field | Value |
|---|---|
| Detection time (UTC) | |
| Triggering host | |
| Source IP / account involved | |
| Relevant Event ID(s) | |
| Initial severity assessment | |

**Analyst narrative:** [What did the alert actually show? Was this a known test or could it plausibly be mistaken for a real event? What made you escalate — or not?]

### 3. Containment, Eradication & Recovery
| Field | Value |
|---|---|
| Action taken | |
| Who/what approved it | |
| Time to containment (detection → action complete) | |
| Verification method | |

**Analyst narrative:** [What was actually done, and — importantly — how did you confirm it actually worked, not just that a button was clicked?]

### 4. Post-Incident Activity
- **Root cause:** [for ADGuard, state plainly this was a deliberate test, not a real compromise]
- **What worked well:**
- **Gaps identified:**
- **Follow-up actions:**
- **MTTR (Mean Time to Respond) for this incident:** [detection timestamp → containment timestamp]

---

## Worked Example — Scenario 1 (Anomalous Remote Logon)

**Incident ID:** `ADGUARD-2026-09-27-01`
**Scenario:** 1 — Anomalous Remote Logon
**Analyst:** [your name]
**Severity:** Medium
**Status:** Closed

### 1. Preparation
- Detection rule `adguard-anomalous-remote-logon` active, 1-minute test cadence
- Telemetry confirmed flowing into `index=adguard_ad` from both `ADGUARD-DC01` and `ADGUARD-TARGET`
- Targets T1078 + T1021.001 (see `mitre-attack-mapping.md`)

### 2. Detection & Analysis
| Field | Value |
|---|---|
| Detection time (UTC) | [fill in] |
| Triggering host | ADGUARD-TARGET |
| Source IP / account involved | [external test IP] / jsmith |
| Relevant Event ID(s) | 4624, Logon_Type 10 |
| Initial severity assessment | Medium — real account, real successful auth, source outside the trusted VNet range, but a known test condition |

**Analyst narrative:** Alert fired within the scheduled detection window following a deliberate external test login. No IP reputation check performed — noted as a gap in `mitre-attack-mapping.md`. In a real environment lacking the "this was a test" context, this would default to High pending triage.

### 3. Containment, Eradication & Recovery
| Field | Value |
|---|---|
| Action taken | Active Directory `disable-user` executed against `jsmith` via Shuffle, over LDAP to the DC |
| Who/what approved it | Human approval via the emailed user-input link |
| Time to containment | [fill in — should be under 5 minutes given the only manual step is the approval click] |
| Verification method | A second, independent Shuffle call re-queried the account's `userAccountControl` attribute and confirmed `ACCOUNTDISABLE` before reporting success — not just trusting that the "disable" action ran without error |

**Analyst narrative:** [fill in from your actual run]

### 4. Post-Incident Activity
- **Root cause:** Deliberate test — NSG rule for RDP was temporarily widened to Any, a login performed from outside the network, then the rule reverted immediately.
- **What worked well:** Full chain (detect → notify → human decision → automated action → independent verification → confirmation) completed with a single manual step.
- **Gaps identified:** No enrichment step before human escalation; detection boundary doesn't account for legitimate remote work.
- **Follow-up actions:** Add IP reputation lookup before escalating; replace the Domain Admin LDAP bind with a least-privilege service account.
- **MTTR:** [fill in]

---

## Worked Example — Scenario 2 (Brute-Force Login Attempt)

**Incident ID:** `ADGUARD-2026-09-27-02`
**Scenario:** 2 — Brute-Force Login Attempt
**Analyst:** [your name]
**Severity:** Medium
**Status:** Closed (monitoring only — no automated response wired up for this scenario, by design)

### 1. Preparation
- Detection rule `adguard-brute-force-attempt` active
- Targets T1110

### 2. Detection & Analysis
| Field | Value |
|---|---|
| Detection time (UTC) | [fill in] |
| Triggering host | |
| Source IP / account involved | |
| Relevant Event ID(s) | 4625 ×5+ within 1 minute |
| Initial severity assessment | |

**Analyst narrative:** [fill in — how many attempts, over what time span, did any attempt succeed?]

### 3. Containment, Eradication & Recovery
**Analyst narrative:** By design, this scenario has **no automated remediation** — see the design-decisions section of the README for why (real brute-force response is usually a lockout policy + ticket, not an immediate account disable via bot). Document here what a human analyst *would* do manually: check if the account subsequently succeeded, check for account lockout policy engagement, consider a manual password reset.

### 4. Post-Incident Activity
- **Root cause:** Deliberate test — repeated wrong-password RDP attempts against a known test account.
- **Follow-up actions:** Consider correlating this alert with Scenario 1 (a brute-force immediately followed by a success from the same source is a stronger combined signal than either alone).

---

## Worked Example — Scenario 3 (Privilege Escalation)

**Incident ID:** `ADGUARD-2026-09-27-03`
**Scenario:** 3 — Privilege Escalation
**Analyst:** [your name]
**Severity:** High
**Status:** Closed

### 1. Preparation
- Detection rule `adguard-privilege-escalation` active, no threshold (fires on any single event)
- Targets T1098

### 2. Detection & Analysis
| Field | Value |
|---|---|
| Detection time (UTC) | |
| Account added to Domain Admins | jsmith |
| Who performed the change (Caller_User_Name) | |
| Relevant Event ID(s) | 4728 |
| Initial severity assessment | High — Domain Admins is the highest-privilege group in the domain; any addition warrants review regardless of context |

**Analyst narrative:** [fill in — was the change plausible as an authorized action, or clearly anomalous?]

### 3. Containment, Eradication & Recovery
**Analyst narrative:** By design, no automated remediation for this scenario either — a real environment would require cross-referencing this against a change-management/ticketing system before taking any action, since a legitimate admin change looks identical to a compromise from Splunk's point of view alone.

### 4. Post-Incident Activity
- **Root cause:** Deliberate test — manually added `jsmith` to Domain Admins via ADUC to generate the event.
- **Follow-up actions:** In a real deployment, integrate with a change-management system so this alert can auto-suppress for pre-approved changes and escalate loudly for unapproved ones.
