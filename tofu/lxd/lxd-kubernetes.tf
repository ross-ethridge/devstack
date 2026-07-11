terraform {
  required_providers {
    lxd = {
      source = "terraform-lxd/lxd"
      version = "~> 2.0"
    }
  }
}

provider "lxd" {
  generate_client_certificates = true
  accept_remote_certificate    = true

  remote {
    name     = "app1"
    address  = var.lxd_server
    token = var.tofu_client
    default  = true
  }
}

locals {
  # Deterministic static IPs on lxdbr0 (10.71.212.0/24, gw .1).
  # VIP 10.71.212.50 is the kube-vip control-plane endpoint (not assigned to any VM).
  control_plane_ips = ["10.71.212.11", "10.71.212.12", "10.71.212.13"]
  worker_ips        = ["10.71.212.21", "10.71.212.22", "10.71.212.23"]
}

resource "lxd_instance" "control_plane" {
  count = 3
  name  = "cp${count.index + 1}"
  image = "ubuntu:24.04"
  type  = "virtual-machine"

  limits = {
    "cpu"    = 2
    "memory" = "4GB"
  }

  config = {
    "user.user-data" = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - ${file("~/.ssh/id_ecdsa.pub")}
    EOF
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "default"
      size = "20GB"
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network        = "lxdbr0"
      "ipv4.address" = local.control_plane_ips[count.index]
    }
  }
}

resource "lxd_instance" "worker" {
  count = 3
  name  = "w${count.index + 1}"
  image = "ubuntu:24.04"
  type  = "virtual-machine"

  limits = {
    "cpu"    = 2
    "memory" = "4GB"
  }

  config = {
    "user.user-data" = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - ${file("~/.ssh/id_ecdsa.pub")}
    EOF
  }


  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "default"
      size = "20GB"
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network        = "lxdbr0"
      "ipv4.address" = local.worker_ips[count.index]
    }
  }
}
