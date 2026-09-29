# ADGuard Detections (Splunk SPL)

Each detection below is saved in Splunk as a scheduled alert. The queries live here too so the repo shows exactly what was built.

**Before using:** replace `YOUR_HOME_IP` with your real public IP (the same one in `allowed_ip`). This is the stand-in for "the office IP" - logins from it are treated as trusted.

**Field names:** Splunk field names are case-sensitive. After your first search, expand one event and confirm the names below (`EventCode`, `Logon_Type`, `Source_Network_Address`, `user`, `ComputerName`). If one differs, use the name Splunk shows.

---

## Scenario 1 - Anomalous Remote Logon (ATT&CK T1078, T1021.001)

- **Alert name:** `adguard-anomalous-remote-logon`
- **Schedule:** cron `* * * * *`, time range Last 5 minutes, trigger once if results > 0, throttle 10 minutes
- **Why:** a successful RDP-type logon (4624, Logon_Type 10 or 7) from any address that is not the private network, not localhost and not the trusted office/home IP.

```spl
index=adguard_ad EventCode=4624 Logon_Type IN (7,10) Source_Network_Address=*
NOT Source_Network_Address IN ("-","127.0.0.1","::1","10.0.0.*","YOUR_HOME_IP")
| stats count by _time, ComputerName, Source_Network_Address, user, Logon_Type
```

## Scenario 2 - Brute-Force Login Attempt (ATT&CK T1110)

- **Alert name:** `adguard-brute-force-attempt`
- **Schedule:** cron `* * * * *`, time range Last 5 minutes, trigger once if results > 0, throttle 10 minutes
- **Why:** 5 or more failed logons (4625) for the same account from the same source inside 5 minutes is guessing, not a typo.

```spl
index=adguard_ad EventCode=4625
| stats count by ComputerName, Source_Network_Address, user
| where count>=5
```

## Scenario 3 - Privilege Escalation (ATT&CK T1098)

- **Alert name:** `adguard-privilege-escalation`
- **Schedule:** cron `* * * * *`, time range Last 15 minutes, trigger once if results > 0, throttle 30 minutes
- **Why:** any member added to Domain Admins (4728) matters, so there is no threshold.

```spl
index=adguard_ad EventCode=4728 "Domain Admins"
| table _time, host, Account_Name, Group_Name, Member_Name
```

If a column comes out empty, expand the event, find the exact field name in the left sidebar, and use that. Fallback: `| table _time, host, Message`.
