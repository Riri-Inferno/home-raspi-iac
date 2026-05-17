variable "account_id" {
  type        = string
  description = "Cloudflare Account ID. Identifier, not secret."
  default     = "626318c8e13be78d91dbb56330cc71e5"
}

variable "zone_id" {
  type        = string
  description = "Cloudflare Zone ID for riri-inferno.com. Identifier, not secret."
  default     = "9eb9dc36b4e0fb39efda0fa5632d8e79"
}

variable "zone_name" {
  type    = string
  default = "riri-inferno.com"
}
