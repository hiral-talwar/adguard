# variables.tf
# ----------------------------------------------------------------------------
# WHAT THIS FILE DOES: defines the "fill in the blanks" for the rest of the
# project. Every other .tf file uses these variables instead of hardcoded
# values, which is exactly what let you rename the whole project to
# "ADGuard" just by changing values here / in terraform.tfvars, instead of
# editing every file by hand.
# ----------------------------------------------------------------------------

variable "resource_group_name" {
  description = "The Azure 'folder' that holds every resource this project creates."
  type        = string
  default     = "rg-adguard"
}

variable "location" {
  description = "Which Azure region to build in. Pick whichever is physically closest to you — lower latency for RDP/SSH."
  type        = string
  default     = "centralindia"
}

variable "project_prefix" {
  description = "Short name stamped onto every resource so they're easy to find and group together."
  type        = string
  default     = "adguard"
}

variable "allowed_ip" {
  description = <<-EOT
    YOUR current public IP address, in CIDR form, e.g. "203.0.113.4/32".
    This is what the firewall (NSG) uses to only let YOU in — not the
    entire internet. Find yours at whatismyip.com. If your home internet
    changes your IP (common), you'll need to update this and re-run
    `terraform apply` to stay able to connect.
  EOT
  type        = string
}

variable "admin_username" {
  description = "The local administrator username on all three VMs."
  type        = string
  default     = "adguardadmin"
}

variable "admin_password" {
  description = "The local administrator password on the two Windows VMs. Set this in terraform.tfvars — NEVER type it directly into this file, and NEVER commit terraform.tfvars to GitHub."
  type        = string
  sensitive   = true
}

variable "auto_shutdown_time" {
  description = "A 24-hour clock time (HHmm) that all VMs will auto-shutdown at, as a safety net in case you forget to stop them yourself."
  type        = string
  default     = "0200"
}

variable "auto_shutdown_timezone" {
  description = "Timezone name for the auto-shutdown time above, e.g. 'India Standard Time', 'Eastern Standard Time'."
  type        = string
  default     = "India Standard Time"
}

variable "shutdown_schedule_location" {
  description = <<-EOT
    Azure region for the auto-shutdown SCHEDULE resources only — this is
    intentionally separate from `location` (where your actual VMs live).
    The auto-shutdown feature has its own, smaller list of supported
    regions, different from where you're allowed to deploy VMs. If this
    default errors for you, check the "List of available regions for
    the resource type" in the error message Azure gives you, and pick
    one from that list that's ALSO in the small set of regions your
    subscription is allowed to use (Terraform will tell you that list
    too, in an earlier error, if you hit one).
  EOT
  type        = string
  default     = "eastasia"
}
