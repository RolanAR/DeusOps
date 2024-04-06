# настройки провайдера

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

variable "token" {
  description = "Yandex Cloud API token"
}
variable "cloud_id" {
  description = "Yandex Cloud ID"
}
variable "folder_id" {
  description = "Yandex Cloud Folder ID"
}
variable "zone" {
  description = "Yandex Cloud Zone"
}

provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

#---

# Проверка наличия директории "inventory" и создание её, если отсутствует
locals {
  inventory_dir = "ansible/k8s/"
}

resource "null_resource" "create_inventory_dir" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "mkdir -p ${local.inventory_dir}"
  }
}

#---

resource "yandex_compute_instance" "web" {
  count        = 1
  name         = "web-${count.index + 1}"
  description  = "web ${count.index + 1}"
  zone         = "ru-central1-a"

  resources {
    core_fraction = 5
    cores  = 2
    memory = 2
  }


  boot_disk {
    initialize_params {
      image_id = "fd808e721rc1vt7jkd0o"
      size     = 15 # Размер диска в гигабайтах
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    # "yandex.cloud/instance-no-ip" = "true"
  }

  scheduling_policy {
    preemptible = true
  }
}

#---

resource "yandex_compute_instance" "files" {
  count        = 1
  name         = "files-${count.index + 1}"
  description  = "files ${count.index + 1}"
  zone         = "ru-central1-a"

  resources {
    core_fraction = 5
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd808e721rc1vt7jkd0o"
      size     = 15 # Размер диска в гигабайтах

    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling_policy {
    preemptible = true
  }
}

#---

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

#---

# Запись IP-адресов ВМ в файл hosts.txt для ансибл
resource "local_file" "write_inventory" {
  filename = "${local.inventory_dir}/hosts.txt"
  content  = <<EOF
[web]
${join("\n", [for instance in yandex_compute_instance.web : "${instance.name} ansible_host=${instance.network_interface.0.nat_ip_address} private_ip=${instance.network_interface.0.ip_address} ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'"])}

[files]
${join("\n", [for instance in yandex_compute_instance.files : "${instance.name} ansible_host=${instance.network_interface.0.nat_ip_address} private_ip=${instance.network_interface.0.ip_address} ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'"])}

EOF
}

# [ingresses]
# ${join("\n", [for instance in yandex_compute_instance.ingresses : "${instance.name} ansible_host=${instance.network_interface.0.nat_ip_address} private_ip=${instance.network_interface.0.ip_address} ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'"])}


