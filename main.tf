
# Find the catalog containing the Ubuntu vApp template
data "vcd_catalog" "ubuntu_catalog" {
  org  = "COT-1"
  name = "Eslam"
}

# Find the Ubuntu 22 template
data "vcd_catalog_vapp_template" "ubuntu" {
  org        = "COT-1"
  catalog_id = data.vcd_catalog.ubuntu_catalog.id
  name       = "Ubuntu-25-10-live-server"
}

# Create VMs inside the existing OM-Project01 vApp

######################omdb01#################################################
resource "vcd_vapp_vm" "omdb01" {
  org              = "COT-1"
  vdc              = "K8s"
  vapp_name        = "OM-Project01"
  name             = "omdb01"
  computer_name = "omdb01"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  vm_name_in_template = "Ubuntu-25-10-l"

  # CPU: 2 sockets, 1 core per socket
  cpus      = 2
  cpu_cores = 1

  # Memory: 2 GB (MB)
  memory = 2048

  
  # Enable Customization
customization { 
  force                      = false
  enabled                    = true
  allow_local_admin_password = true
  auto_generate_password     = false
  admin_password             = "4FrD&3d+u"
  initscript = <<-EOT
    #!/bin/bash
    if [ "$1" = "postcustomization" ]; then
      hostnamectl set-hostname omdb01
      cat >> /etc/hosts <<'HOSTS'
    10.10.10.70 omdb01
    10.10.10.71 ommc01
    10.10.10.72 omrmq01
    10.10.10.73 omapp01
    10.10.10.74 omweb01
    HOSTS
    fi
  EOT

  }



  # Connect to the organization network named OM-Project01.
  # Use type = "vapp" instead if OM-Project01 is a vApp network.
  network {
    type               = "org"
    name               = "OM-Project01"
    ip_allocation_mode = "MANUAL"
    ip                 = "10.10.10.70"
    is_primary         = true
    connected          = true
  }

  power_on = true
}
##############################################################################




######################ommc01#################################################
resource "vcd_vapp_vm" "ommc01" {
  org              = "COT-1"
  vdc              = "K8s"
  vapp_name        = "OM-Project01"
  name             = "ommc01"
  computer_name = "ommc01"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  vm_name_in_template = "Ubuntu-25-10-l"

  # CPU: 2 sockets, 1 core per socket
  cpus      = 2
  cpu_cores = 1

  # Memory: 2 GB (MB)
  memory = 2048


  # Enable Customization
customization {
  force                      = false
  enabled                    = true
  allow_local_admin_password = true
  auto_generate_password     = false
  admin_password             = "4FrD&3d+u"
  initscript = <<-EOT
    #!/bin/bash
    if [ "$1" = "postcustomization" ]; then
      hostnamectl set-hostname ommc01
      cat >> /etc/hosts <<'HOSTS'
    10.10.10.70 omdb01
    10.10.10.71 ommc01
    10.10.10.72 omrmq01
    10.10.10.73 omapp01
    10.10.10.74 omweb01
    HOSTS
    fi
  EOT

  }



  # Connect to the organization network named OM-Project01.
  # Use type = "vapp" instead if OM-Project01 is a vApp network.
  network {
    type               = "org"
    name               = "OM-Project01"
    ip_allocation_mode = "MANUAL"
    ip                 = "10.10.10.71"
    is_primary         = true
    connected          = true
  }

  power_on = true
}
##############################################################################

######################omrmq01#################################################
resource "vcd_vapp_vm" "omrmq01" {
  org              = "COT-1"
  vdc              = "K8s"
  vapp_name        = "OM-Project01"
  name             = "omrmq01"
  computer_name = "omrmq01"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  vm_name_in_template = "Ubuntu-25-10-l"

  # CPU: 2 sockets, 1 core per socket
  cpus      = 2
  cpu_cores = 1

  # Memory: 2 GB (MB)
  memory = 2048


  # Enable Customization
customization {
  force                      = false
  enabled                    = true
  allow_local_admin_password = true
  auto_generate_password     = false
  admin_password             = "4FrD&3d+u"
  initscript = <<-EOT
    #!/bin/bash
    if [ "$1" = "postcustomization" ]; then
      hostnamectl set-hostname omrmq01
      cat >> /etc/hosts <<'HOSTS'
    10.10.10.70 omdb01
    10.10.10.71 ommc01
    10.10.10.72 omrmq01
    10.10.10.73 omapp01
    10.10.10.74 omweb01
    HOSTS
    fi
  EOT

  }



  # Connect to the organization network named OM-Project01.
  # Use type = "vapp" instead if OM-Project01 is a vApp network.
  network {
    type               = "org"
    name               = "OM-Project01"
    ip_allocation_mode = "MANUAL"
    ip                 = "10.10.10.72"
    is_primary         = true
    connected          = true
  }

  power_on = true
}
##############################################################################

######################omapp01#################################################
resource "vcd_vapp_vm" "omapp01" {
  org              = "COT-1"
  vdc              = "K8s"
  vapp_name        = "OM-Project01"
  name             = "omapp01"
  computer_name = "omapp01"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  vm_name_in_template = "Ubuntu-25-10-l"

  # CPU: 2 sockets, 1 core per socket
  cpus      = 2
  cpu_cores = 1

  # Memory: 2 GB (MB)
  memory = 2048


  # Enable Customization
customization {
  force                      = false
  enabled                    = true
  allow_local_admin_password = true
  auto_generate_password     = false
  admin_password             = "4FrD&3d+u"
  initscript = <<-EOT
    #!/bin/bash
    if [ "$1" = "postcustomization" ]; then
      hostnamectl set-hostname omapp01
      cat >> /etc/hosts <<'HOSTS'
    10.10.10.70 omdb01
    10.10.10.71 ommc01
    10.10.10.72 omrmq01
    10.10.10.73 omapp01
    10.10.10.74 omweb01
    HOSTS
    fi
  EOT

  }



  # Connect to the organization network named OM-Project01.
  # Use type = "vapp" instead if OM-Project01 is a vApp network.
  network {
    type               = "org"
    name               = "OM-Project01"
    ip_allocation_mode = "MANUAL"
    ip                 = "10.10.10.73"
    is_primary         = true
    connected          = true
  }

  power_on = true
}
##############################################################################

######################omweb01#################################################
resource "vcd_vapp_vm" "omweb01" {
  org              = "COT-1"
  vdc              = "K8s"
  vapp_name        = "OM-Project01"
  name             = "omweb01"
  computer_name = "omweb01"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  vm_name_in_template = "Ubuntu-25-10-l"

  # CPU: 2 sockets, 1 core per socket
  cpus      = 2
  cpu_cores = 1

  # Memory: 2 GB (MB)
  memory = 2048


  # Enable Customization
customization {
  force                      = false
  enabled                    = true
  allow_local_admin_password = true
  auto_generate_password     = false
  admin_password             = "4FrD&3d+u"
  initscript = <<-EOT
    #!/bin/bash
    if [ "$1" = "postcustomization" ]; then
      hostnamectl set-hostname omweb01
      cat >> /etc/hosts <<'HOSTS'
    10.10.10.70 omdb01
    10.10.10.71 ommc01
    10.10.10.72 omrmq01
    10.10.10.73 omapp01
    10.10.10.74 omweb01
    HOSTS
    fi
  EOT

  }



  # Connect to the organization network named OM-Project01.
  # Use type = "vapp" instead if OM-Project01 is a vApp network.
  network {
    type               = "org"
    name               = "OM-Project01"
    ip_allocation_mode = "MANUAL"
    ip                 = "10.10.10.74"
    is_primary         = true
    connected          = true
  }

  power_on = true
}
##############################################################################




