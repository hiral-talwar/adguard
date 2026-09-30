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

**Incident ID:** `ADGUARD-2026-09-30-01`
**Scenario:** 1 — Anomalous Remote Logon
**Analyst:** [Hiral]
**Severity:** Medium
**Status:** Closed

### 1. Preparation
- Detection rule `adguard-anomalous-remote-logon` active, 1-minute test cadence
- Telemetry confirmed flowing into `index=adguard_ad` from both `ADGUARD-DC01` and `ADGUARD-TARGET`
- Targets T1078 + T1021.001 (see `mitre-attack-mapping.md`)

### 2. Detection & Analysis
| Field | Value |
|---|---|
| Detection time (UTC) | [fill in from your Splunk Triggered Alerts timestamp] |
| Triggering host | ADGUARD-TARGET |
| Source IP / account involved | Mobile hotspot IP (`106.202.96.208`) / jsmith |
| Relevant Event ID(s) | 4624, Logon_Type 7 |
| Initial severity assessment | Medium — real account, real successful auth, source outside the trusted VNet range, but a known test condition (test login performed deliberately from a phone hotspot to generate an untrusted-source event) |

**Analyst narrative:** Alert fired within the scheduled detection window following a deliberate login from outside the home/office trusted IP (using a mobile hotspot to guarantee a different public IP). Source correctly excluded from the trusted-range filter, confirming the detection boundary works as designed. No IP reputation check performed — noted as a gap in `mitre-attack-mapping.md`. In a real environment lacking the "this was a test" context, this would default to High pending triage.

### 3. Containment, Eradication & Recovery
| Field | Value |
|---|---|
| Action taken | **Manual** — Active Directory account `jsmith` disabled by hand in ADUC on `ADGUARD-DC01`, after Shuffle's automated approval chain completed |
| Who/what approved it | Human approval via Shuffle's User Input node (approved using the `frontend_continue` link, since the email delivery for this step did not arrive during testing — see `lab-notebook.md`, item 15) |
| Time to containment | 4 minutes, 18 seconds |
| Verification method | Manually refreshed Active Directory Users and Computers and confirmed the disabled-account (down-arrow) icon appeared on the `jsmith` object |

**Analyst narrative:** The playbook was designed for Shuffle to disable the account automatically via its Active Directory app immediately after approval. That app failed on every call (both a read-only "get user attributes" test and the actual "disable user" action) with `ValueError: unsupported hash type MD4` — traced to Shuffle's AD app using NTLM authentication internally, which requires an MD4 hash that the runtime's crypto library refuses to compute since MD4 is a broken legacy algorithm. This was confirmed as a hard platform bug, not a misconfiguration, by testing two different login formats and confirming no alternate authentication-type setting exists in the app's fixed field set. The workflow was redesigned so that, after approval, Shuffle posts a "MANUAL ACTION REQUIRED" message to Slack instead of calling Active Directory directly, and the analyst completes the disable action by hand. Every other stage of the chain (detection, Slack alert, email/approval gate) worked exactly as designed.

### 4. Post-Incident Activity
- **Root cause:** Deliberate test — NSG rule for RDP was temporarily widened to Any, a login performed from a mobile hotspot (to guarantee a source IP outside the trusted range), then the rule reverted immediately afterward.
- **What worked well:** Full chain up through approval (detect → notify → human decision) completed correctly and quickly. The pivot to a manual-disable step, once the platform bug was identified, was itself fast to implement (delete the broken node, add an Http+webhook node in its place).
- **Gaps identified:** No enrichment step before human escalation. Detection boundary doesn't account for legitimate remote work. Shuffle's Active Directory app is not usable for account-disable automation on this backend. Email delivery for the approval step did not arrive during testing (worked around via the direct approval link instead — root cause not fully diagnosed).
- **Follow-up actions:** Add IP reputation lookup before escalating. Replace the Domain Admin LDAP bind with a least-privilege service account if a working AD automation path is found. Investigate the email delivery gap separately. Re-test Shuffle's Active Directory app periodically in case the MD4 issue gets fixed upstream, or migrate this specific action to Microsoft Sentinel + Logic Apps / a custom WinRM runbook instead.
- **MTTR:** [fill in — from initial Slack alert to manual account disable confirmed in ADUC]

---

## Worked Example — Scenario 2 (Brute-Force Login Attempt)

**Incident ID:** `ADGUARD-2026-09-27-02`
**Scenario:** 2 — Brute-Force Login Attempt
**Analyst:** [hiral]
**Severity:** Medium
**Status:** Closed (monitoring only — no automated response wired up for this scenario, by design)

### 1. Preparation
- Detection rule `adguard-brute-force-attempt` active
- Targets T1110

### 2. Detection & Analysis
| Field | Value |
|---|---|
| Detection time (UTC) | 10:26:45:689 p.m |
| Triggering host | |
| Source IP / account involved | |
| Relevant Event ID(s) | 4625 ×5+ within 1 minute |
| Initial severity assessment | |

**Analyst narrative:** All 6 attempts originated from the external source IP 106.202.96.208. No attempts succeeded during this window, and the threat was successfully intercepted prior to account compromise.

### 3. Containment, Eradication & Recovery
**Analyst narrative:** By design, this scenario has **no automated remediation** — see the design-decisions section of the README for why (real brute-force response is usually a lockout policy + ticket, not an immediate account disable via bot). Document here what a human analyst *would* do manually: check if the account subsequently succeeded, check for account lockout policy engagement, consider a manual password reset.

### 4. Post-Incident Activity
- **Root cause:** Deliberate test — repeated wrong-password RDP attempts against a known test account.
- **Follow-up actions:** Consider correlating this alert with Scenario 1 (a brute-force immediately followed by a success from the same source is a stronger combined signal than either alone).

---

## Worked Example — Scenario 3 (Privilege Escalation)

**Incident ID:** `ADGUARD-2026-09-27-03`
**Scenario:** 3 — Privilege Escalation
**Analyst:** [hiral]
**Severity:** High
**Status:** Closed

### 1. Preparation
- Detection rule `adguard-privilege-escalation` active, no threshold (fires on any single event)
- Targets T1098

### 2. Detection & Analysis
| Field | Value |
|---|---|
| Detection time (UTC) |07:41:36 AM |
| Account added to Domain Admins | jsmith |
| Who performed the change (Administrator) | |
| Relevant Event ID(s) | 4728 |
| Initial severity assessment | High — Domain Admins is the highest-privilege group in the domain; any addition warrants review regardless of context |


### 3. Containment, Eradication & Recovery
**Analyst narrative:** By design, no automated remediation for this scenario either — a real environment would require cross-referencing this against a change-management/ticketing system before taking any action, since a legitimate admin change looks identical to a compromise from Splunk's point of view alone.

### 4. Post-Incident Activity
- **Root cause:** Deliberate test — manually added `jsmith` to Domain Admins via ADUC to generate the event.
- **Follow-up actions:** In a real deployment, integrate with a change-management system so this alert can auto-suppress for pre-approved changes and escalate loudly for unapproved ones.
