terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "3.14.1"
    }
  }
}

provider "vcd" {
  url      = "https://vdc.rayacloud.com/api"
  user     = "omar"
  password = "*******"

  auth_type = "integrated"

  org = "COT-1"
  vdc = "K8s"

  allow_unverified_ssl = true
}
