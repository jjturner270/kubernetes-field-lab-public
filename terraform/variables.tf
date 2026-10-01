variable "hcloud_token" {
  description = "Hetzner Cloud API token. Prefer HCLOUD_TOKEN env var."
  type        = string
  sensitive   = true
  default     = null
}

variable "admin_cidr" {
  description = "Public workstation CIDR permitted to SSH and reach the Kubernetes API, e.g. 203.0.113.4/32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr))
    error_message = "admin_cidr must be valid CIDR notation, e.g. 203.0.113.4/32."
  }
}

variable "location" {
  description = "Hetzner Cloud location."
  type        = string
  default     = "ash"
}

variable "server_type" {
  description = "Hetzner server type for all three nodes."
  type        = string
  default     = "cpx21"
}

variable "image" {
  description = "Server image."
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_public_key_path" {
  description = "Local SSH public key injected into all servers."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Local SSH private key used by generated Ansible inventory."
  type        = string
  default     = "~/.ssh/id_ed25519"
}
