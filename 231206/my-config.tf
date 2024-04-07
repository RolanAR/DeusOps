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
resource "yandex_vpc_network" "network" {
  name = "k8s-network"
}

resource "yandex_kubernetes_cluster" "cluster" {
  name = "k8s-cluster"
  network_id = yandex_vpc_network.network.id

  version = "1.19"

  node_pool {
    name = "default-pool"
    subnet_id = yandex_vpc_subnet.subnet.id
    instance_type = "compute-t2.micro"
    initial_node_count = 2
  }
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "k8s-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.0.0.0/24"]
}



# # Создание SSH-ключа на локальной машине

# # Проверка наличия директории для ssh key и создание её, если отсутствует
# locals {
#   ssh_key_dir = "ansible/ssh_key"
# }

# resource "null_resource" "create_ssh_key_dir" {
#   triggers = {
#     always_run = timestamp()
#   }

#   provisioner "local-exec" {
#     command = "mkdir -p ${local.ssh_key_dir}"
#   }
# }

# # Создание SSH-ключа и сохранение его в директории ${local.ssh_key_dir}
# resource "null_resource" "create_ssh_key" {
#   triggers = {
#     always_run = timestamp()
#   }

#   provisioner "local-exec" {
#     command = "ssh-keygen -t rsa -b 4096 -N '' -f ${local.ssh_key_dir}/id_rsa"
#   }
# }

# # Чтение содержимого публичного ключа
# data "local_file" "ssh_public_key" {
#   depends_on = [null_resource.create_ssh_key]
#   filename   = "${path.module}/ansible/ssh_key/id_rsa.pub"
# }
# #---

# # Проверка наличия директории для "inventory" и создание её, если отсутствует
# locals {
#   inventory_dir = "ansible/"
# }

# resource "null_resource" "create_inventory_dir" {
#   triggers = {
#     always_run = timestamp()
#   }

#   provisioner "local-exec" {
#     command = "mkdir -p ${local.inventory_dir}"
#   }
# }

# #---

# resource "yandex_compute_instance" "web" {
#   count        = var.web_instance_count
#   name         = "web${format("%02d", count.index + 1)}"
#   description  = "web ${count.index + 1}"
#   zone         = "ru-central1-a"

#   resources {
#     core_fraction = 5
#     cores  = 2
#     memory = 2
#   }


#   boot_disk {
#     initialize_params {
#       image_id = "fd808e721rc1vt7jkd0o"
#       size     = 15 # Размер диска в гигабайтах
#     }
#   }

#   network_interface {
#     subnet_id = yandex_vpc_subnet.subnet-1.id
#     nat       = true
#   }

#   metadata = {
#     ssh-keys = "ubuntu:${data.local_file.ssh_public_key.content}"

#     # ssh-keys = "ubuntu:${file("${local.ssh_key_dir}/id_rsa.pub")}"
#     # "yandex.cloud/instance-no-ip" = "true"
#   }

#   scheduling_policy {
#     preemptible = true
#   }
# }

# #---

# resource "yandex_compute_instance" "files" {
#   count        = var.files_instance_count
#   name         = "files${format("%02d", count.index + 1)}"
#   description  = "files ${count.index + 1}"
#   zone         = "ru-central1-a"

#   resources {
#     core_fraction = 5
#     cores  = 2
#     memory = 2
#   }

#   boot_disk {
#     initialize_params {
#       image_id = "fd808e721rc1vt7jkd0o"
#       size     = 15 # Размер диска в гигабайтах

#     }
#   }

#   network_interface {
#     subnet_id = yandex_vpc_subnet.subnet-1.id
#     nat       = true
#   }

#   metadata = {
#     ssh-keys = "ubuntu:${data.local_file.ssh_public_key.content}"

#     # ssh-keys = "ubuntu:${file("${local.ssh_key_dir}/id_rsa.pub")}"
#   }

#   scheduling_policy {
#     preemptible = true
#   }
# }

# #---

# resource "yandex_vpc_network" "network-1" {
#   name = "network1"
# }

# resource "yandex_vpc_subnet" "subnet-1" {
#   name           = "subnet1"
#   zone           = "ru-central1-a"
#   network_id     = yandex_vpc_network.network-1.id
#   v4_cidr_blocks = ["192.168.10.0/24"]
# }

# #---

# # Запись IP-адресов ВМ в файл hosts.yml для ансибл
# resource "local_file" "write_inventory" {
#   filename = "${local.inventory_dir}/hosts.yml"
#   content  = yamlencode({
#     all = {
#       children = {
#         web = {
#           hosts = {
#             for instance in yandex_compute_instance.web : instance.name => {
#               ansible_host               = instance.network_interface.0.nat_ip_address
#               private_ip                = instance.network_interface.0.ip_address
#               ansible_ssh_private_key_file = "${local.ssh_key_dir}/id_rsa"
#               ansible_user              = "ubuntu"
#               ansible_ssh_common_args   = "-o StrictHostKeyChecking=no"
#             }
#           }
#         }
#         files = {
#           hosts = {
#             for instance in yandex_compute_instance.files : instance.name => {
#               ansible_host               = instance.network_interface.0.nat_ip_address
#               private_ip                = instance.network_interface.0.ip_address
#               ansible_ssh_private_key_file = "${local.ssh_key_dir}/id_rsa"
#               ansible_user              = "ubuntu"
#               ansible_ssh_common_args   = "-o StrictHostKeyChecking=no"
#             }
#           }
#         }
#       }
#     }
#   })
# }

