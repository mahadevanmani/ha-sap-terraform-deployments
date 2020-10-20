variable "provider_type" {
  description = "Used provider for the deployment"
  type        = string
}

variable "deployment_name" {
  description = "Suffix string added to some of the infrastructure resources names. If it is not provided, the terraform workspace string is used as suffix"
  type        = string
  default     = ""
}

variable "reg_code" {
  description = "If informed, register the product using SUSEConnect"
  default     = ""
}

variable "reg_email" {
  description = "Email used for the registration"
  default     = ""
}

variable "reg_additional_modules" {
  description = "Map of the modules to be registered. Module name = Regcode, when needed."
  type        = map(string)
  default     = {}
}

variable "ha_sap_deployment_repo" {
  description = "Repository url used to install development versions of HA/SAP deployment packages. If the SLE version is not present in the URL, it will be automatically detected"
  type        = string
  default     = ""
}

variable "additional_packages" {
  description = "extra packages which should be installed"
  type        = list
  default     = []
}

variable "public_key_location" {
  description = "Path to a SSH public key used to connect to the created machines"
  type        = string
  default     = ""
}

variable "private_key_location" {
  description = "Path to a SSH private key used to connect to the created machines"
  type        = string
  default     = ""
}

variable "authorized_keys" {
  description = "List of additional authorized SSH public keys paths to access the created machines with the used admin user (root in this case)"
  type        = list(string)
  default     = []
}

variable "authorized_user" {
  description = "Authorized user for the given authorized_keys"
  type        = string
}

variable "bastion_enabled" {
  description = "Create a VM to work as a bastion to avoid the usage of public ip addresses and manage the ssh connection to the other machines"
  type        = bool
  default     = true
}

variable "bastion_host" {
  description = "Bastion host address"
  type        = string
  default     = ""
}

variable "bastion_public_key" {
  description = "Path to a SSH public key used to connect to the bastion. If it's not set the key provided in public_key_location will be used"
  type        = string
  default     = ""
}

variable "bastion_private_key" {
  description = "Path to a SSH private key used to connect to the bastion. If it's not set the key provided in private_key_location will be used"
  type        = string
  default     = ""
}

variable "provisioner" {
  description = "Used provisioner option. Available options: salt. Let empty to not use any provisioner"
  default     = "salt"
}

variable "provisioning_log_level" {
  description = "Provisioning process log level. For salt: https://docs.saltstack.com/en/latest/ref/configuration/logging/index.html"
  type        = string
  default     = "error"
}

variable "background" {
  description = "Run the provisioner execution in background if set to true finishing terraform execution"
  type        = bool
  default     = false
}

variable "monitoring_enabled" {
  description = "Enable centralized monitoring via Prometheus/Grafana/Loki"
  type        = bool
  default     = false
}

variable "monitoring_srv_ip" {
  description = "Monitoring server address"
  type        = string
  default     = ""
}

variable "qa_mode" {
  description = "Enable test/qa mode (disable extra packages usage not coming in the image)"
  type        = bool
  default     = false
}
