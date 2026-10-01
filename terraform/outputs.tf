output "server_ips" {
  value = {
    for name, server in hcloud_server.node :
    name => {
      public  = server.ipv4_address
      private = local.nodes[name].private_ip
      role    = local.nodes[name].role
    }
  }
}

output "control_public_ip" {
  value = hcloud_server.node["control-01"].ipv4_address
}

output "ansible_inventory" {
  value = <<-EOT
[control]
control-01 ansible_host=${hcloud_server.node["control-01"].ipv4_address} private_ip=10.10.0.10

[workers]
worker-01 ansible_host=${hcloud_server.node["worker-01"].ipv4_address} private_ip=10.10.0.11
worker-02 ansible_host=${hcloud_server.node["worker-02"].ipv4_address} private_ip=10.10.0.12

[k8s:children]
control
workers

[k8s:vars]
ansible_user=root
ansible_ssh_private_key_file=${pathexpand(var.ssh_private_key_path)}
ansible_python_interpreter=/usr/bin/python3
  EOT
}
