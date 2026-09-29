# ADGuard

A self-built detection & response lab on Azure: Active Directory + Splunk (SIEM) + Shuffle (SOAR), fully defined as code, detecting 3 realistic attack patterns.

## What this actually is

A tiny fake company network — one server that manages logins (Domain Controller) and one "employee" computer (Target Machine) — watched by a security tool (Splunk) that's been taught to recognize 3 specific bad things happening, wired to an automatic responder (Shuffle + Slack) that asks a human before taking action.

## Architecture

![architecture diagram](diagram.png)
<!-- put your exported draw.io diagram image here -->

| VM | OS | Role |
|---|---|---|
| `vm-adguard-dc01` | Windows Server 2022 | Domain Controller (`adguard.local`) |
| `vm-adguard-target` | Windows Server 2022 | Domain-joined test machine |
| `vm-adguard-splunk` | Ubuntu 22.04 | Splunk Enterprise (SIEM) |

## What it detects

| # | Scenario | ATT&CK Technique | Automated response? |
|---|---|---|---|
| 1 | Anomalous Remote Logon | T1078, T1021.001 | Yes — full Shuffle/Slack playbook, disables the account after human approval |
| 2 | Brute-Force Login Attempt | T1110 | No, by design — see Design Decisions below |
| 3 | Privilege Escalation (Domain Admins addition) | T1098 | No, by design — see Design Decisions below |

Full mapping and honest coverage-gap notes: [`docs/mitre-attack-mapping.md`](docs/mitre-attack-mapping.md)

## Incident reports

Every test run is documented as a formal NIST SP 800-61-style incident report, not a build log: [`docs/incident-response-report-template.md`](docs/incident-response-report-template.md)

## Design decisions — the "why" behind each choice

| Decision | Reasoning |
|---|---|
| `Standard_B2s` for both Windows VMs | Cheapest Azure size that doesn't lag under RDP + AD DS/GUI workloads |
| `Standard_B2ms` for Splunk | Splunk needs more RAM than the Windows boxes; this is the cheapest size that meets that |
| Single subnet, NSG at the subnet level | One shared firewall surface, appropriately sized for a 3-VM lab |
| Port 9997 (Splunk receiving) scoped to VNet only, never public | Forwarder traffic never needs to leave the private network |
| Port 389 (LDAP) and the "any IP" RDP rule kept as commented-out, temporary blocks | Neither should be a permanent, silently-committed open door — they're opened deliberately, for minutes at a time, with the git history as a record |
| Scenarios 2 and 3 have NO automated response | A real brute-force response is usually an account-lockout policy plus a ticket, not an immediate bot-driven disable; a real Domain Admins addition needs cross-referencing against change management before any action, since it can't be distinguished from a legitimate change using Splunk data alone. Automating everything the same way would be the less mature design choice. |
| `.local` domain suffix | Lab convention, not a production recommendation — a real AD deployment should use a routable-but-unused domain suffix instead |

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) — lets your terminal log into Azure (`az login`)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5 — builds/destroys the infrastructure from code
- An SSH keypair: `ssh-keygen -t rsa -b 4096` — used to log into the Splunk VM
- Your current public IP (check whatismyip.com) — needed for the `allowed_ip` variable

## Usage

```bash
# one-time setup
cp terraform.tfvars.example terraform.tfvars
# now edit terraform.tfvars: fill in allowed_ip and admin_password

az login
terraform init      # downloads the Azure plugin Terraform needs
terraform plan       # PREVIEW what will be built — always check this before applying
terraform apply       # actually builds the resource group, network, firewall, and 3 VMs
```

**Then do the manual, inside-the-VM work** (AD DS install, Splunk config, Shuffle workflow) — this isn't something Terraform does; see the full step-by-step guide for that part.

### Day-to-day: pause and resume WITHOUT losing your work

Once you've started configuring things inside the VMs (from the AD DS install onward), **do not run `terraform destroy` between sessions** — it deletes the VM's hard disk along with the VM, which erases everything you configured inside it.

Instead:
- **Pausing for the day:** Azure Portal → select all 3 VMs → **Stop**. This stops compute billing but keeps every disk, and everything on it, intact.
- **Resuming:** Azure Portal → select the VMs → **Start**. Everything is exactly as you left it.

```bash
# ONLY when the entire project is completely finished and recorded:
terraform destroy
```

## Testing the detections (temporarily widening the firewall)

The `TEMP-Allow-RDP-Any` and `TEMP-Allow-LDAP-Shuffle` rules in `nsg.tf` are commented out by default.

1. Remove the `#` from the start of each line in the rule block you need.
2. `terraform apply`
3. Run your test.
4. Put the `#` back on each line.
5. `terraform apply` again to close the door.

`git log nsg.tf` will show the full history of every time this happened and for how long.

## Git workflow — when to commit, and what

Commit in small, meaningful chunks as you go, not as one giant commit at the end. Suggested sequence:

```bash
git init
git add .gitignore
git commit -m "Add gitignore to protect secrets"

git add providers.tf variables.tf
git commit -m "Add Terraform provider config and variables"

git add network.tf
git commit -m "Add resource group, VNet, and subnet"

git add nsg.tf
git commit -m "Add NSG: RDP/SSH/Splunk-web locked to my IP, Splunk-recv scoped to VNet only"

git add vms.tf outputs.tf
git commit -m "Add DC, target, and Splunk VMs with auto-shutdown schedules"

# --- after you finish the manual AD DS setup (Part C) ---
git add docs/
git commit -m "Add MITRE ATT&CK mapping and incident report template"

git add README.md
git commit -m "Add project README"

# --- whenever you temporarily open/close a TEMP rule to run a test ---
git add nsg.tf
git commit -m "Temporarily open RDP to test Scenario 1 detection"
# ...run your test...
git add nsg.tf
git commit -m "Close RDP rule after Scenario 1 test"

git remote add origin https://github.com/<your-username>/adguard.git
git branch -M main
git push -u origin main
```

**What NOT to commit, ever:** `terraform.tfvars` (your real password/IP), `.terraform/` and `*.tfstate` files (Terraform's internal state, can contain sensitive info) — the `.gitignore` file already blocks all of these automatically, but never override it.

**What goes IN the repo, visible on GitHub:** every `.tf` file, `terraform.tfvars.example`, the `docs/` folder, this README, and your exported diagram image.

## Cost notes

- All VMs use burstable B-series sizing and Standard SSD disks — the cheapest usable tier.
- Windows Server 2022's OS disk is fixed at 127 GB by the image itself — Azure does not allow shrinking it, so this isn't a lever for saving cost on the two Windows VMs. Splunk's Ubuntu disk is set to 64 GB explicitly (up from the ~30 GB default) since Splunk's own data needs room.
- Azure for Students subscriptions are often restricted to a small, specific set of allowed regions (not the full region list) — if `terraform apply` rejects your `location`, the error message tells you the exact regions your subscription can use. The auto-shutdown schedule feature has its own, separate, smaller supported-region list from regular VMs — that's why it has its own `shutdown_schedule_location` variable rather than always matching your VMs' region.
- Standard SKU public IPs bill a small hourly amount (~$0.005/hr each) even while the VM is stopped — this is the tradeoff for using Stop instead of Destroy to preserve your work between sessions.
- Auto-shutdown is enabled on every VM as a backstop against forgetting to stop them manually.
