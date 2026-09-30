# MITRE ATT&CK Mapping — ADGuard

What this document is: a table connecting each of ADGuard's 3 detections to the [MITRE ATT&CK](https://attack.mitre.org/) framework — the industry-standard, shared vocabulary security teams use to describe attacker behavior. Every mature detection engineering team tags its alerts this way, so that coverage can be tracked and compared across a whole security program instead of every alert being a one-off with no shared language.

## Scenario 1 — Anomalous Remote Logon

| Field | Value |
|---|---|
| Tactic | Initial Access / Defense Evasion |
| Technique | [T1078 — Valid Accounts](https://attack.mitre.org/techniques/T1078/) |
| Sub-technique | [T1021.001 — Remote Services: RDP](https://attack.mitre.org/techniques/T1021/001/) |
| Data source | Windows Security Event Log, Event ID 4624 (successful logon), filtered to `Logon_Type` 7/10 |
| What it actually catches | A real, valid account successfully logging in via RDP from an IP address outside the trusted private network range |
| Response | **Semi-automated.** Shuffle receives the alert via webhook, posts to Slack, and emails the analyst for approval. As designed, an approval should then trigger Shuffle's Active Directory app to disable the account directly. In practice, that app is broken (see Known coverage gaps) — approval instead triggers a "manual action required" Slack message, and the analyst disables the account by hand in ADUC. |

## Scenario 2 — Brute-Force Login Attempt

| Field | Value |
|---|---|
| Tactic | Credential Access |
| Technique | [T1110 — Brute Force](https://attack.mitre.org/techniques/T1110/) |
| Data source | Windows Security Event Log, Event ID 4625 (failed logon) |
| What it actually catches | Five or more failed login attempts against the same account, from the same source, within a one-minute window — the standard signature of automated or deliberate password-guessing, as opposed to one honest typo |

## Scenario 3 — Suspicious Privilege Escalation

| Field | Value |
|---|---|
| Tactic | Persistence / Privilege Escalation |
| Technique | [T1098 — Account Manipulation](https://attack.mitre.org/techniques/T1098/) |
| Data source | Windows Security Event Log, Event ID 4728 ("a member was added to a security-enabled global group") |
| What it actually catches | Any account being added to the **Domain Admins** group — the single highest-value group in the entire domain, so this alert has zero threshold; even one event matters |

## Why these three, together

They cover three different stages of a realistic attack path: **get in** (Scenario 1 or 2) → **stay in / expand access** (Scenario 3). A single detection tells you one thing happened; three detections spanning different ATT&CK tactics show a reviewer that the coverage was chosen deliberately to span an attacker's actual progression, not picked at random.

## Known coverage gaps (an honest self-assessment, not just a list of wins)

- **No correlation between Scenario 2 and Scenario 1.** A real attack chain often looks like: brute-force until successful (Scenario 2 leading into Scenario 1). Right now these are two separate alerts rather than one correlated "this IP brute-forced its way in" alert — a natural v2 improvement.
- **Scenario 1's "outside the private range" boundary is naive.** It doesn't account for legitimate remote work, VPN egress ranges, or admin jump boxes, so it would produce false positives outside a lab environment.
- **No IP reputation enrichment.** None of the three alerts check whether the source IP is a known-bad address before escalating — every qualifying event goes straight to a human, which doesn't scale with real alert volume.
- **Scenario 3 doesn't distinguish authorized from unauthorized changes.** A legitimate IT admin adding someone to Domain Admins as part of approved change management would trigger the exact same alert as a real compromise — in a real environment this alert would need to be cross-referenced against a change-management ticket system.
- **Scenario 1's automated response is not actually automated end-to-end.** Shuffle's built-in Active Directory app fails on every call with `ValueError: unsupported hash type MD4` — its NTLM bind requires computing an MD4 hash, which modern secure runtimes disable by default since MD4 is cryptographically broken. This was confirmed as a platform-level bug (not a config error) by testing both a read-only action and the disable action, and by ruling out a hidden authentication-type setting in Shuffle's Active Directory app (the field set is fixed: server, port, domain, login_user, password, base_dn, use_ssl — no Simple/NTLM toggle exists). The practical fix in this project was to notify the analyst to disable the account manually instead. A real fix would replace this integration with Microsoft Sentinel + Logic Apps, or a custom PowerShell/WinRM-based runbook, neither of which depend on Shuffle's broken AD app.
