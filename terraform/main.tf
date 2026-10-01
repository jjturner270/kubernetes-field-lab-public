locals {
  nodes = {
    "control-01" = {
      role       = "control"
      private_ip = "10.10.0.10"
    }
    "worker-01" = {
      role       = "worker"
      private_ip = "10.10.0.11"
    }
    "worker-02" = {
      role       = "worker"
      private_ip = "10.10.0.12"
    }
  }
}

resource "hcloud_ssh_key" "lab" {
  name       = "kubernetes-field-lab"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "hcloud_network" "k8s" {
  name     = "kubernetes-field-lab"
  ip_range = "10.10.0.0/16"
}

resource "hcloud_network_subnet" "k8s" {
  network_id   = hcloud_network.k8s.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.10.0.0/24"
}

resource "hcloud_firewall" "k8s" {
  name = "kubernetes-field-lab"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = [var.admin_cidr]
    description = "SSH from operator workstation"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = [var.admin_cidr, "10.10.0.0/16"]
    description = "Kubernetes API"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "any"
    source_ips  = ["10.10.0.0/16"]
    description = "Node-to-node TCP on private network"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "any"
    source_ips  = ["10.10.0.0/16"]
    description = "Node-to-node UDP on private network"
  }

  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = [var.admin_cidr, "10.10.0.0/16"]
    description = "ICMP diagnostics"
  }
}

resource "hcloud_server" "node" {
  for_each = local.nodes

  name        = each.key
  image       = var.image
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.lab.id]
  firewall_ids = [hcloud_firewall.k8s.id]

  labels = {
    project = "kubernetes-field-lab"
    role    = each.value.role
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  depends_on = [
    hcloud_network_subnet.k8s
  ]
}

resource "hcloud_server_network" "node" {
  for_each = local.nodes

  server_id  = hcloud_server.node[each.key].id
  network_id = hcloud_network.k8s.id
  ip         = each.value.private_ip

  depends_on = [
    hcloud_network_subnet.k8s
  ]
}
