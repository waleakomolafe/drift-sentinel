# A cloud-free rig that produces REAL drift, so the detection logic can be
# exercised in CI without any Azure or AWS credential.
#
# local_file is a genuine Terraform resource with genuine state. Editing the
# file outside Terraform is genuine drift -- the same mechanism as somebody
# editing an NSG in the Azure portal, just without the subscription.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "nsg_rules" {
  filename = "${path.module}/nsg-web-prod.json"
  content = jsonencode({
    name = "nsg-web-prod"
    security_rules = [
      { name = "allow-https", priority = 100, destination_port_range = "443" },
      { name = "allow-ssh", priority = 200, destination_port_range = "22" },
    ]
  })
}
