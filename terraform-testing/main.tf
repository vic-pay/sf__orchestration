# provider to connect to infrastructure
terraform {
  required_providers {
    lxd = {
      source = "terraform-lxd/lxd"
    }
  }
}

provider "lxd" {
  generate_client_certificates = true
  accept_remote_certificate    = true
  lxd_remote {
    name     = "lxd-local-server"
    scheme   = "https"
    address  = "127.0.0.1"
    password = "set_your_pass_here"
    default  = true
  }
}

# image resources
resource "lxd_cached_image" "ubuntu2004" {
  source_remote = "ubuntu"
  source_image = "20.04"
}

# containers
resource "lxd_container" "master-node" {
  config     = {}
  ephemeral  = false
  limits     = {
      "memory" = "1024MB"
      "cpu" = 2
  }
  name       = "master-node"
  profiles   = [
      "terraform_default",
  ]
  image      = lxd_cached_image.ubuntu2004.fingerprint
  wait_for_network = false
  device {
      name = "eth0"
      type = "nic"
      properties = {
           network = lxd_network.terraform_br.name
           "ipv4.address" = "10.0.4.70"
      }
  }
}
resource "lxd_container" "worker-node" {
config     = {}
  ephemeral  = false
  limits     = {
      "memory" = "1024MB"
      "cpu" = 2
  }
  name       = "worker-node"
  profiles   = [
      "terraform_default",
  ]
  image      = lxd_cached_image.ubuntu2004.fingerprint
  wait_for_network = false
  device {
      name = "eth0"
      type = "nic"
      properties = {
           network = lxd_network.terraform_br.name
           "ipv4.address" = "10.0.4.80"
      }
  }
}

# Profile
resource "lxd_profile" "terraform_default" {
    config      = {
      "linux.kernel_modules": "ip_tables,ip6_tables,netlink_diag,nf_nat,overlay"
      "raw.lxc": "lxc.apparmor.profile=unconfined\nlxc.cap.drop= \nlxc.cgroup.devices.allow=a\nlxc.mount.auto=proc:rw sys:rw"
      "security.privileged": "true"
      "security.nesting": "true"
    }
    description = "Default LXD profile created by terrraform"
    name        = "terraform_default"
    device {
        name       = "root"
        properties = {
            "path" = "/"
            "pool" = "terraform_pool"
        }
        type       = "disk"
    }
    device {
        name       = "eth0"
        properties = {
            "nictype" = "bridged"
            "parent" = lxd_network.terraform_br.name
        }
        type       = "nic"
    }
}
# Storage Pool
resource "lxd_storage_pool" "terraform_pool" {
  config = {
      source = "/var/snap/lxd/common/lxd/storage-pools/terraform_pool"
  }
  driver = "dir"
  name   = "terraform_pool"
}
# Bridge Network
resource "lxd_network" "terraform_br" {
  name = "terraform_br"
  description = "bridge interface for all containers to access hosts internet"
  config = {
    "ipv4.address" = "10.0.4.1/24"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
  }
}
output "second-ip" {
  value = lxd_container.master-node.ip_address
}
output "first-ip" {
  value = lxd_container.worker-node.ip_address
}
