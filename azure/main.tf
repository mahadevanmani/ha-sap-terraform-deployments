module "local_execution" {
  source  = "../generic_modules/local_exec"
  enabled = var.pre_deployment
}

# This locals entry is used to store the IP addresses of all the machines.
# Autogenerated addresses example based in 10.74.0.0/24
# Iscsi server: 10.74.0.4
# Monitoring: 10.74.0.5
# Hana ips: 10.74.0.10, 10.74.0.11
# Hana cluster vip: 10.74.0.12
# Hana cluster vip secondary: 10.74.0.13
# DRBD ips: 10.74.0.20, 10.74.0.21
# DRBD cluster vip: 10.74.0.22
# Netweaver ips: 10.74.0.30, 10.74.0.31, 10.74.0.32, 10.74.0.33
# Netweaver virtual ips: 10.74.0.34, 10.74.0.35, 10.74.0.36, 10.74.0.37
# If the addresses are provided by the user will always have preference
locals {
  iscsi_ip      = var.iscsi_srv_ip != "" ? var.iscsi_srv_ip : cidrhost(local.subnet_address_range, 4)
  monitoring_ip = var.monitoring_srv_ip != "" ? var.monitoring_srv_ip : cidrhost(local.subnet_address_range, 5)

  hana_ip_start              = 10
  hana_ips                   = length(var.hana_ips) != 0 ? var.hana_ips : [for ip_index in range(local.hana_ip_start, var.hana_count + local.hana_ip_start) : cidrhost(local.subnet_address_range, ip_index)]
  hana_cluster_vip           = var.hana_cluster_vip != "" ? var.hana_cluster_vip : cidrhost(local.subnet_address_range, var.hana_count + local.hana_ip_start)
  hana_cluster_vip_secondary = var.hana_cluster_vip_secondary != "" ? var.hana_cluster_vip_secondary : cidrhost(local.subnet_address_range, var.hana_count + local.hana_ip_start + 1)

  drbd_ip_start    = 20
  drbd_ips         = length(var.drbd_ips) != 0 ? var.drbd_ips : [for ip_index in range(local.drbd_ip_start, local.drbd_ip_start + 2) : cidrhost(local.subnet_address_range, ip_index)]
  drbd_cluster_vip = var.drbd_cluster_vip != "" ? var.drbd_cluster_vip : cidrhost(local.subnet_address_range, local.drbd_ip_start + 2)

  netweaver_xscs_server_count = var.netweaver_enabled ? (var.netweaver_ha_enabled ? 2 : 1) : 0
  netweaver_count             = local.netweaver_xscs_server_count + var.netweaver_app_server_count

  netweaver_ip_start    = 30
  netweaver_ips         = length(var.netweaver_ips) != 0 ? var.netweaver_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + local.netweaver_count) : cidrhost(local.subnet_address_range, ip_index)]
  netweaver_virtual_ips = length(var.netweaver_virtual_ips) != 0 ? var.netweaver_virtual_ips : [for ip_index in range(local.netweaver_ip_start + local.netweaver_count, local.netweaver_ip_start + (local.netweaver_count * 2)) : cidrhost(local.subnet_address_range, ip_index)]

  # Check if iscsi server has to be created
  use_sbd       = var.hana_cluster_fencing_mechanism == "sbd" || var.drbd_cluster_fencing_mechanism == "sbd" || var.netweaver_cluster_fencing_mechanism == "sbd"
  iscsi_enabled = var.sbd_storage_type == "iscsi" && ((var.hana_count > 1 && var.hana_ha_enabled) || var.drbd_enabled || (local.netweaver_count > 1 && var.netweaver_ha_enabled)) && local.use_sbd ? true : false

  # Obtain machines os_image value
  hana_os_image       = var.hana_os_image != "" ? var.hana_os_image : var.os_image
  iscsi_os_image      = var.iscsi_os_image != "" ? var.iscsi_os_image : var.os_image
  monitoring_os_image = var.monitoring_os_image != "" ? var.monitoring_os_image : var.os_image
  drbd_os_image       = var.drbd_os_image != "" ? var.drbd_os_image : var.os_image
  netweaver_os_image  = var.netweaver_os_image != "" ? var.netweaver_os_image : var.os_image
}

module "common_variables" {
  source                 = "../generic_modules/common_variables"
  provider_type          = "azure"
  reg_code               = var.reg_code
  reg_email              = var.reg_email
  reg_additional_modules = var.reg_additional_modules
  ha_sap_deployment_repo = var.ha_sap_deployment_repo
  additional_packages    = var.additional_packages
  public_key_location    = var.public_key_location
  private_key_location   = var.private_key_location
  authorized_keys        = var.authorized_keys
  authorized_user        = var.admin_user
  provisioner            = var.provisioner
  provisioning_log_level = var.provisioning_log_level
  background             = var.background
  monitoring_enabled     = var.monitoring_enabled
  monitoring_srv_ip      = var.monitoring_enabled ? local.monitoring_ip : ""
  qa_mode                = var.qa_mode
}

module "drbd_node" {
  source              = "./modules/drbd_node"
  common_variables    = module.common_variables.configuration
  az_region           = var.az_region
  drbd_count          = var.drbd_enabled == true ? 2 : 0
  vm_size             = var.drbd_vm_size
  drbd_image_uri      = var.drbd_image_uri
  os_image            = local.drbd_os_image
  resource_group_name = local.resource_group_name
  network_subnet_id   = local.subnet_id
  sec_group_id        = azurerm_network_security_group.mysecgroup.id
  storage_account     = azurerm_storage_account.mytfstorageacc.primary_blob_endpoint
  bastion_enabled     = var.bastion_enabled
  bastion_host        = module.bastion.public_ip
  bastion_private_key = local.bastion_private_key
  cluster_ssh_pub     = var.cluster_ssh_pub
  cluster_ssh_key     = var.cluster_ssh_key
  admin_user          = var.admin_user
  host_ips            = local.drbd_ips
  fencing_mechanism   = var.drbd_cluster_fencing_mechanism
  sbd_storage_type    = var.sbd_storage_type
  iscsi_srv_ip        = join("", module.iscsi_server.iscsisrv_ip)
  nfs_mounting_point  = var.drbd_nfs_mounting_point
  nfs_export_name     = var.netweaver_sid
  drbd_cluster_vip    = local.drbd_cluster_vip
}

module "netweaver_node" {
  source                      = "./modules/netweaver_node"
  common_variables            = module.common_variables.configuration
  az_region                   = var.az_region
  xscs_server_count           = var.netweaver_enabled ? local.netweaver_xscs_server_count : 0
  app_server_count            = var.netweaver_enabled ? var.netweaver_app_server_count : 0
  xscs_vm_size                = var.netweaver_xscs_vm_size
  app_vm_size                 = var.netweaver_app_vm_size
  xscs_accelerated_networking = var.netweaver_xscs_accelerated_networking
  app_accelerated_networking  = var.netweaver_app_accelerated_networking
  data_disk_caching           = var.netweaver_data_disk_caching
  data_disk_size              = var.netweaver_data_disk_size
  data_disk_type              = var.netweaver_data_disk_type
  netweaver_image_uri         = var.netweaver_image_uri
  os_image                    = local.netweaver_os_image
  resource_group_name         = local.resource_group_name
  network_subnet_id           = local.subnet_id
  sec_group_id                = azurerm_network_security_group.mysecgroup.id
  storage_account             = azurerm_storage_account.mytfstorageacc.primary_blob_endpoint
  bastion_enabled             = var.bastion_enabled
  bastion_host                = module.bastion.public_ip
  bastion_private_key         = local.bastion_private_key
  cluster_ssh_pub             = var.cluster_ssh_pub
  cluster_ssh_key             = var.cluster_ssh_key
  admin_user                  = var.admin_user
  netweaver_sid               = var.netweaver_sid
  netweaver_product_id        = var.netweaver_product_id
  netweaver_inst_folder       = var.netweaver_inst_folder
  netweaver_extract_dir       = var.netweaver_extract_dir
  netweaver_swpm_folder       = var.netweaver_swpm_folder
  netweaver_sapcar_exe        = var.netweaver_sapcar_exe
  netweaver_swpm_sar          = var.netweaver_swpm_sar
  netweaver_sapexe_folder     = var.netweaver_sapexe_folder
  netweaver_additional_dvds   = var.netweaver_additional_dvds
  netweaver_nfs_share         = var.drbd_enabled ? "${local.drbd_cluster_vip}:/${var.netweaver_sid}" : var.netweaver_nfs_share
  storage_account_name        = var.netweaver_storage_account_name
  storage_account_key         = var.netweaver_storage_account_key
  storage_account_path        = var.netweaver_storage_account
  host_ips                    = local.netweaver_ips
  virtual_host_ips            = local.netweaver_virtual_ips
  fencing_mechanism           = var.netweaver_cluster_fencing_mechanism
  sbd_storage_type            = var.sbd_storage_type
  ha_enabled                  = var.netweaver_ha_enabled
  iscsi_srv_ip                = join("", module.iscsi_server.iscsisrv_ip)
  hana_ip                     = var.hana_ha_enabled ? local.hana_cluster_vip : element(local.hana_ips, 0)
}

module "hana_node" {
  source                        = "./modules/hana_node"
  common_variables              = module.common_variables.configuration
  az_region                     = var.az_region
  hana_count                    = var.hana_count
  hana_instance_number          = var.hana_instance_number
  vm_size                       = var.hana_vm_size
  host_ips                      = local.hana_ips
  scenario_type                 = var.scenario_type
  resource_group_name           = local.resource_group_name
  network_subnet_id             = local.subnet_id
  sec_group_id                  = azurerm_network_security_group.mysecgroup.id
  storage_account               = azurerm_storage_account.mytfstorageacc.primary_blob_endpoint
  storage_account_name          = var.storage_account_name
  storage_account_key           = var.storage_account_key
  enable_accelerated_networking = var.hana_enable_accelerated_networking
  sles4sap_uri                  = var.sles4sap_uri
  hana_cluster_vip              = local.hana_cluster_vip
  hana_cluster_vip_secondary    = var.hana_active_active ? local.hana_cluster_vip_secondary : ""
  ha_enabled                    = var.hana_ha_enabled
  hana_inst_master              = var.hana_inst_master
  hana_inst_folder              = var.hana_inst_folder
  hana_platform_folder          = var.hana_platform_folder
  hana_sapcar_exe               = var.hana_sapcar_exe
  hana_archive_file             = var.hana_archive_file
  hana_extract_dir              = var.hana_extract_dir
  hana_fstype                   = var.hana_fstype
  cluster_ssh_pub               = var.cluster_ssh_pub
  cluster_ssh_key               = var.cluster_ssh_key
  bastion_enabled               = var.bastion_enabled
  bastion_host                  = module.bastion.public_ip
  bastion_private_key           = local.bastion_private_key
  hana_data_disks_configuration = var.hana_data_disks_configuration
  os_image                      = local.hana_os_image
  admin_user                    = var.admin_user
  fencing_mechanism             = var.hana_cluster_fencing_mechanism
  sbd_storage_type              = var.sbd_storage_type
  iscsi_srv_ip                  = join("", module.iscsi_server.iscsisrv_ip)
  hwcct                         = var.hwcct
}

module "monitoring" {
  source              = "./modules/monitoring"
  common_variables    = module.common_variables.configuration
  monitoring_enabled  = var.monitoring_enabled
  az_region           = var.az_region
  vm_size             = var.monitoring_vm_size
  resource_group_name = local.resource_group_name
  network_subnet_id   = local.subnet_id
  sec_group_id        = azurerm_network_security_group.mysecgroup.id
  storage_account     = azurerm_storage_account.mytfstorageacc.primary_blob_endpoint
  monitoring_uri      = var.monitoring_uri
  os_image            = local.monitoring_os_image
  monitoring_srv_ip   = local.monitoring_ip
  bastion_enabled     = var.bastion_enabled
  bastion_host        = module.bastion.public_ip
  bastion_private_key = local.bastion_private_key
  admin_user          = var.admin_user
  hana_targets        = concat(local.hana_ips, var.hana_ha_enabled ? [local.hana_cluster_vip] : [local.hana_ips[0]]) # we use the vip for HA scenario and 1st hana machine for non HA to target the active hana instance
  drbd_targets        = var.drbd_enabled ? local.drbd_ips : []
  netweaver_targets   = var.netweaver_enabled ? local.netweaver_virtual_ips : []
}

module "iscsi_server" {
  source              = "./modules/iscsi_server"
  common_variables    = module.common_variables.configuration
  iscsi_count         = local.iscsi_enabled ? 1 : 0
  az_region           = var.az_region
  vm_size             = var.iscsi_vm_size
  resource_group_name = local.resource_group_name
  network_subnet_id   = local.subnet_id
  sec_group_id        = azurerm_network_security_group.mysecgroup.id
  storage_account     = azurerm_storage_account.mytfstorageacc.primary_blob_endpoint
  iscsi_srv_uri       = var.iscsi_srv_uri
  os_image            = local.iscsi_os_image
  bastion_enabled     = var.bastion_enabled
  bastion_host        = module.bastion.public_ip
  bastion_private_key = local.bastion_private_key
  host_ips            = [local.iscsi_ip]
  lun_count           = var.iscsi_lun_count
  iscsi_disk_size     = var.iscsi_disk_size
  admin_user          = var.admin_user
}
