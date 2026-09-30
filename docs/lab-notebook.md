# ADGuard Lab Notebook

Built in one continuous sprint on Azure for Students. This is the real record of what happened, in order — not a cleaned-up version. Passwords are never written here, only usernames and account names where relevant.

## Session log

| Date | Start | Stop | Parts worked on | VMs stopped (deallocated)? |
|---|---|---|---|---|
| [fill in your actual date] | [fill start time] | [fill stop time] | Parts 0 → G, full build in one session | Yes — manually via Azure Portal, no auto-shutdown schedule (removed by choice) |

## Errors and fixes — the full sequence, in the order they actually happened

| # | Where | Exact error message | What I tried | What fixed it |
|---|---|---|---|---|
| 1 | Terraform apply (Part B) | `RequestDisallowedByAzure: ... This policy maintains a set of best available regions where your subscription can deploy resources` on `pip-adguard-splunk` in `centralindia` | Read the error for the reason | `terraform destroy` (safe — nothing configured inside VMs yet), changed `location` in `terraform.tfvars`. Azure's own error output on a later attempt revealed the subscription's actual allowed-region list: `koreacentral`, `eastasia`, `uaenorth`, `malaysiawest`, `indiasouthcentral`. Switched to `indiasouthcentral`. |
| 2 | Terraform apply (Part B, 2nd attempt) | `OperationNotAllowed: The specified disk size 64 GB is smaller than the size of the corresponding disk in the VM image: 127 GB` on both Windows VMs | Had explicitly set `disk_size_gb = 64` in `vms.tf` as a planned cost optimization | Removed `disk_size_gb` entirely from both Windows `os_disk` blocks — Windows Server 2022's image has a fixed 127 GB minimum and Azure will not allow shrinking it. Kept `disk_size_gb = 64` on the Linux Splunk VM only, where it's legal (bigger than the ~30 GB default). |
| 3 | Same apply | `LocationNotAvailableForResourceType: The provided location 'indiasouthcentral' is not available for resource type 'Microsoft.DevTestLab/schedules'` | Compared the resource type's supported-region list against the subscription's allowed-region list from error #1 | Added a separate `shutdown_schedule_location` variable (independent from the main `location`), set to `eastasia` — the only region present in both lists besides `koreacentral`/`uaenorth`. |
| 4 | Same apply | `404 ResourceNotFound: The Resource 'Microsoft.Network/virtualNetworks/vnet-adguard' ... was not found` on the NSG-subnet association, immediately after the VNet log showed `Creation complete` | Re-ran `terraform apply` with no file changes | Resolved itself — an Azure API propagation delay, not a real configuration error. |
| 5 | Terraform apply | `OperationNotAllowed: Operation could not be completed as it results in exceeding approved standardBSFamily Cores quota. Current Limit: 4, Current Usage: 4, Additional Required: 2` while creating the DC | Considered requesting a quota increase (would likely take too long for a one-day build) | Resized `vm-adguard-dc01` and `vm-adguard-target` from `Standard_B2s` (2 vCPU) to `Standard_B1ms` (1 vCPU, 2 GB RAM — chosen over `B1s` for the extra RAM at the same quota cost). Total: Splunk (2) + DC (1) + Target (1) = 4 cores, exactly at the limit. |
| 6 | Not yet hit, caught by review | `file("~/.ssh/id_rsa.pub")` in `vms.tf` | N/A — caught before running, since Terraform does not expand `~` into the home directory on Windows by itself | Wrapped it as `file(pathexpand("~/.ssh/id_rsa.pub"))` — `pathexpand()` is a Terraform built-in that does the expansion correctly cross-platform. |
| 7 | Decision, not an error | N/A — personal preference | Didn't want auto-shutdown interrupting a long working session | Removed all three `azurerm_dev_test_global_vm_shutdown_schedule` blocks from `vms.tf` entirely. Traded away the safety net in exchange for full manual control — VMs are now stopped by hand via the Azure Portal at the end of each session, with no automatic backstop. |
| 8 | Slack app install via Shuffle (Part F5) | Slack: `Shuffle SOAR Bot could not be installed. Invalid permissions requested` | Retried the one-click login button multiple times | It's a broken permissions request on Shuffle's side, not fixable by retrying. Created a dedicated Slack app manually (api.slack.com/apps → Blank app → `ADGuard Bot`), added Bot Token Scopes `chat:write` and `chat:write.public`, added Redirect URL `https://shuffler.io/set_authentication`, then authenticated in Shuffle using the manual Client ID / Client Secret / Scopes form instead of one-click login. |
| 9 | Slack Redirect URL field, Slack app config | "must be valid" on `https://shuffler.io/set_authentication` | Re-typed instead of pasting (ruling out invisible copy-paste characters) | Turned out to just need to be typed cleanly / retried — resolved without a further code change. |
| 10 | Shuffle's scope picker (Part F5) | `chat:write.public` typed into Shuffle's own Scopes field showed "No options" and would not save as a tag | Tried pressing Enter to force it in as free text | Left it out of Shuffle's local scopes box — the actual permission grant lives in Slack's own Bot Token Scopes (already configured correctly there), so Shuffle's local field not accepting it doesn't remove the permission. Documented `/invite @ADGuard Bot` as a manual fallback if a message ever failed with `not_in_channel`. |
| 11 | Shuffle Slack `chat_postmessage` action test (Part F5) | `"success": false, "reason": "Iteration count more than 10 ... got an unexpected keyword argument 'link_...'"` | Confirmed Channel ID and Text fields were correctly filled in first | This is a bug in Shuffle's own Slack app code, not a config issue. Deleted the Slack node entirely; replaced it with a **Slack Incoming Webhook** (Slack app → Incoming Webhooks → Add New Webhook to Workspace → `#adguard-alerts`) called via a Shuffle **Http** node (POST, JSON body, runtime arguments inserted into the JSON text). Worked immediately. |
| 12 | Shuffle canvas wiring (Part F6) | Not an error — a logic mistake: both `Splunk-alert-in` and `User-action` were connected *into* `Alert-notification` instead of a straight chain | Reviewed the canvas visually | Deleted the wrong connection, redrew it so the flow reads `Splunk-alert-in` → `Alert-notification` → `User-action` in a straight line. |
| 13 | User Input node config (Part F6) | Not an error — wrong input method selected (`Subflow` checked, "No Workflow Selected") | N/A | Unchecked `Subflow`, checked `Email`, entered a real email address. |
| 14 | User Input node, "Required Input-Questions" | Confusion over "No Input-Questions found. Click to add them!" — clicking it opened the wrong panel entirely (workflow-level Editing Workflow settings: name, tags, git backup, publishing) | Accidentally clicked the workflow's own edit-workflow pencil instead | Closed that panel without saving. Left "Required Input-Questions" empty — Shuffle's Email input option auto-generates Approve/Decline links without needing a manually defined question here. |
| 15 | Testing the User Input node | No approval email ever arrived, even after multiple reruns | Checked spam folder | Used the `frontend_continue` URL visible directly in the node's own JSON result as a manual substitute for clicking a real email link — confirmed functionally equivalent for testing purposes. Email delivery itself remains an open item (see Future improvements). |
| 16 | Shuffle Active Directory app authentication (Part F7) | `"success": false, "exception": "ValueError - unsupported hash type MD4"` — on both "Get user attributes" (read-only) and "Disable user" actions | Tried UPN-format login (`adguardadmin@adguard.local`, blank Domain field) instead of the split domain/username fields; checked the App Authentication list for a hidden Simple/NTLM toggle (none exists — fields are fixed: server, port, domain, login_user, password, base_dn, use_ssl) | Root-caused: Shuffle's AD app authenticates via NTLM internally, which requires computing an MD4 hash of the password; modern secure runtimes disable MD4 outright since it's a broken legacy algorithm. This is a hard platform bug, not fixable from the config side. Confirmed by testing the read-only action too, which fails identically — ruling out anything specific to the disable action. Pivoted design: deleted the AD node, replaced it with a second Http→Slack-webhook node that posts a "MANUAL ACTION REQUIRED" message instead, and disabled the account by hand in ADUC. Closed the temporary LDAP (389) NSG rule immediately afterward since it was no longer needed. |

## Deliberate lab shortcuts (and what production would do instead)

| Shortcut | Why I took it | Production version |
|---|---|---|
| `.local` domain name | Lab convention | Routable-but-unused domain suffix |
| Password never expires on jsmith | Avoid lockouts mid-lab | Password policy + MFA |
| Domain admin account used for the (ultimately broken) Shuffle LDAP bind | Simplicity — never got far enough to swap it out before hitting the MD4 bug | Least-privilege service account, LDAPS only |
| LDAP (389, unencrypted) opened to Any for a short window during F7 testing | Shuffle's outbound IPs aren't a fixed, documented range | LDAPS + VPN/Private Link, or avoid this integration path entirely |
| No auto-shutdown schedule | Chose full manual control over a long single-day session | Auto-shutdown or a proper cost-alert/automation policy |
| 1-minute alert schedules on all 3 Splunk alerts | Fast testing turnaround | 5–15 minute realistic intervals |
| Scenario 1's final response is semi-automated (notify-then-manual), not fully automated as originally designed | Forced by the Shuffle AD platform bug, not a deliberate choice | A working AD automation path (Sentinel+Logic Apps, or a custom PowerShell/WinRM runbook) |

## Cost log

| Date | Credit remaining (Portal → Cost Management) |
|---|---|
| [fill in — check before you start] | |
| [fill in — check at end of session] | |

## What I'd do differently next time

- Check the subscription's actual region and quota limits (via a small test deployment or the Portal's Quotas page) *before* writing any Terraform, rather than discovering both limits mid-`apply`.
- Verify Shuffle's Slack and Active Directory apps against a throwaway test workflow before relying on them inside the real build — both had independent, unrelated bugs that cost real time to isolate.
- Keep this notebook open and updated *during* each part instead of reconstructing it afterward — timestamps in the Session log and Cost log above are still placeholders for this reason.
