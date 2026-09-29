# ADGuard Lab Notebook

Rules: never write passwords here. Write the time you start and stop every session, every error message word-for-word, and what fixed it. These notes become your interview stories.

## Session log

| Date | Start | Stop | Parts worked on | VMs stopped (deallocated)? |
|---|---|---|---|---|
| | | | | |

## Errors and fixes

| Date | Where (laptop / DC / Target / Splunk VM / web) | Exact error message | What I tried | What fixed it |
|---|---|---|---|---|
| | | | | |

## Deliberate lab shortcuts (and what production would do instead)

| Shortcut | Why I took it | Production version |
|---|---|---|
| `.local` domain name | Lab convention | Routable-but-unused domain suffix |
| Password never expires on jsmith | Avoid lockouts mid-lab | Password policy + MFA |
| Domain admin account used for Shuffle LDAP | Simplicity | Least-privilege service account |
| LDAP (389, unencrypted) opened to Any for minutes | Shuffle IPs are not fixed | LDAPS + VPN/Private Link |
| 1-minute alert schedule | Fast testing | 5-15 minutes |

## Cost log

| Date | Credit remaining (Portal > Cost Management) |
|---|---|
| | |
