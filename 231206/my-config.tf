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
variable "web_instance_count" {
  description = "Number of web instances"
  default     = 1
}
variable "files_instance_count" {
  description = "Number of files instances"
  default     = 1
}


provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

#---

# Создание SSH-ключа на локальной машине

# Проверка наличия директории для ssh key и создание её, если отсутствует
locals {
  ssh_key_dir = "ansible/ssh_key"
}

resource "null_resource" "create_ssh_key_dir" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "mkdir -p ${local.ssh_key_dir}"
  }
}

# Создание SSH-ключа и сохранение его в директории ${local.ssh_key_dir}
resource "null_resource" "create_ssh_key" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "rm -f ${local.ssh_key_dir}/id_rsa && rm -f ${local.ssh_key_dir}/id_rsa.pub && ssh-keygen -t rsa -b 4096 -N '' -f ${local.ssh_key_dir}/id_rsa -q"
  }
}

# Чтение содержимого публичного ключа
data "local_file" "ssh_public_key" {
  depends_on = [null_resource.create_ssh_key]
  filename   = "${path.module}/ansible/ssh_key/id_rsa.pub"
}
#---

# Проверка наличия директории для "inventory" и создание её, если отсутствует
locals {
  inventory_dir = "./ansible"
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
  count        = var.web_instance_count
  name         = "web${format("%02d", count.index + 1)}"
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
    ssh-keys = "ubuntu:${data.local_file.ssh_public_key.content}"

    # ssh-keys = "ubuntu:${file("${local.ssh_key_dir}/id_rsa.pub")}"
    # "yandex.cloud/instance-no-ip" = "true"
  }

  scheduling_policy {
    preemptible = true
  }
}

#---

resource "yandex_compute_instance" "files" {
  count        = var.files_instance_count
  name         = "files${format("%02d", count.index + 1)}"
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
    ssh-keys = "ubuntu:${data.local_file.ssh_public_key.content}"

    # ssh-keys = "ubuntu:${file("${local.ssh_key_dir}/id_rsa.pub")}"
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

resource "local_file" "write_inventory" {
  filename = "${local.inventory_dir}/hosts.yml"
  content  = replace(yamlencode({
    all = {
      children = {
        web = {
          hosts = {
            for instance in yandex_compute_instance.web : instance.name => {
              ansible_host               = instance.network_interface.0.nat_ip_address
              private_ip                = instance.network_interface.0.ip_address
              ansible_ssh_private_key_file = "${local.ssh_key_dir}/id_rsa"
              ansible_user              = "ubuntu"
              #ansible_ssh_common_args   = "-o StrictHostKeyChecking=no"
            }
          }
        }
        files = {
          hosts = {
            for instance in yandex_compute_instance.files : instance.name => {
              ansible_host               = instance.network_interface.0.nat_ip_address
              private_ip                = instance.network_interface.0.ip_address
              ansible_ssh_private_key_file = "${local.ssh_key_dir}/id_rsa"
              ansible_user              = "ubuntu"
              #ansible_ssh_common_args   = "-o StrictHostKeyChecking=no"
            }
          }
        }
      }
    }
  }), "\"", "")
}

resource "null_resource" "make_hosts_non_executable" {
  triggers = {
    file_content = local_file.write_inventory.content
  }

  provisioner "local-exec" {
    command = "chmod -x ${local.inventory_dir}/hosts.yml"
  }
}
