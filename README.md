# ADGuard — Simulate. Detect. Defend.

## What this is

A miniature company network I built from scratch to practice catching and responding to cyberattacks — the same way a real security team would, rather than just reading about how it's done. I set up a small Windows office network in the cloud, installed a tool that watches for suspicious activity, taught it to recognize three real attack patterns, and connected it to an automated alert and response system with a human still making the final call.

Think of it as a self-built training ground: I played both the attacker (triggering the suspicious activity) and the defender (building the system that catches it).

## Why I built it

Reading about cybersecurity concepts and actually building a working detection system are very different skills. Anyone can describe what a "brute-force attack" is; fewer people have set up the actual infrastructure, watched the real logs, written the detection rule themselves, and fixed what broke along the way. I wanted that hands-on proof, including the messy parts a tutorial usually skips.

## Architecture, in plain terms

- **A Domain Controller** — the "boss" server that manages every employee login and password for the fake company (this is what Active Directory, or **AD**, actually does — it's the identity system most real companies run on)
- **A Test Machine** — a normal "employee" computer, joined to that same company network
- **A Splunk server** — the security camera system. It's a **SIEM** (Security Information and Event Management tool), meaning it collects logs from every computer and lets you search through them to spot trouble
- **Shuffle + Slack** — the automated responder. Shuffle is a **SOAR** platform (Security Orchestration, Automation, and Response) — it watches for alerts and can act on them automatically; Slack is just where it sends notifications

All of this was built on **Microsoft Azure** (cloud hosting) using **Terraform** — instead of manually clicking through Azure's website to build each computer, I wrote a text file describing exactly what I wanted, and a program built it for me automatically. That means the whole environment can be torn down and rebuilt identically any time, and the file itself is a readable record of exactly what exists.

## What it actually catches

Each of these maps to a real technique listed in **MITRE ATT&CK**, an industry-standard, shared catalog of known attacker behaviors — full mapping with technique IDs is in `docs/mitre-attack-mapping.md`.

1. **Anomalous Remote Logon** — someone successfully logging in remotely from a location outside the trusted network
2. **Brute-Force Attempt** — five or more wrong-password login attempts against the same account within a minute (the signature of someone guessing passwords, not a typo)
3. **Privilege Escalation** — someone being added to the Domain Admins group, the single highest-privilege group in the whole network

The exact search queries used to detect each one, written in Splunk's query language (SPL), are documented in `detections/adguard-detections.md`.

## What happens when something fires

Splunk detects it → sends an alert to Shuffle → Shuffle posts to Slack and emails a "should we disable this account?" question to a human analyst → once approved, the response continues. The intent was full automation end-to-end; what actually happened (and why) is below.

## What I learned — including what broke

Almost nothing worked perfectly on the first try, and fixing each thing taught me more than a clean run would have. The full blow-by-blow, including every exact error message and fix, is in `docs/lab-notebook.md`.

- **Cloud quotas and region restrictions**: Azure rejected my first choice of region outright, then rejected my planned VM sizes for exceeding a CPU quota. I learned to read Azure's error messages carefully and resize the infrastructure to fit real constraints instead of assuming my original plan would just work.
- **A Windows-specific bug in my own code**: a file-path reference that works fine on Mac/Linux silently fails on Windows — only caught because I was testing on the actual platform I built for.
- **A broken third-party login flow**: Shuffle's one-click Slack login was broken on their end, so I built my own Slack app manually (its own OAuth credentials, permissions, and redirect URL) to work around it.
- **A genuine, unfixable platform bug**: Shuffle's Active Directory automation feature fails on every call due to an outdated cryptographic algorithm (MD4) that modern systems refuse to use for security reasons. I confirmed this wasn't my mistake by testing it two different ways, then redesigned that step so a human completes the final action manually instead of the automation silently failing. This is the part I'm most proud of — recognizing a real bug in someone else's software and adapting around it, rather than assuming I'd done something wrong.

## What I'd do differently, or add next

- Add a check that looks up whether a suspicious IP address has a known-bad reputation before ever alerting a human, to cut down noise
- Try Microsoft Sentinel (Azure's own security monitoring tool) as an alternative to the broken automation step
- Replace the admin-level login used for automation with a more limited, safer account
- Correlate the brute-force and anomalous-logon alerts together, since a real attack often looks like one leading into the other

## Where to find more detail

- **`docs/lab-notebook.md`** — every error message, exact fix, and screenshot references, in the order they happened
- **`docs/mitre-attack-mapping.md`** — full technique mapping and known coverage gaps
- **`docs/incident-response-report-template.md`** — each test written up as a formal incident report
- **`detections/adguard-detections.md`** — the actual Splunk search queries used
