variable "instances" {
  description = "Map of instances to create. Easy to add or remove nodes by editing this map."
  type = map(object({
    cpu    = optional(number, 2)
    memory = optional(string, "2048MiB")
    ipv4   = string
  }))
  default = {
    "DMZ" = {
      ipv4 = "10.0.0.10"
    }
    "DB" = {
      ipv4 = "10.0.0.31"
    }
    "rke2-master01" = {
      memory = "4096MiB"
      ipv4   = "10.0.0.21"
    }
    "rke2-master02" = {
      memory = "4096MiB"
      ipv4   = "10.0.0.23"
    }
    "rke2-master03" = {
      memory = "4096MiB"
      ipv4   = "10.0.0.25"
    }
    "rke2-agent01" = {
      ipv4 = "10.0.0.22"
    }
    "rancher" = {
      memory = "4096MiB"
      ipv4   = "10.0.0.30"
    }
  }
}
