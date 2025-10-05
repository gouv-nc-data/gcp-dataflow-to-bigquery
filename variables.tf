variable "project_id" {
  type        = string
  description = "id du projet"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "group_name" {
  type        = string
  description = "Google groupe associé au projet"
}

variable "schedule" {
  type        = string
  description = "expression cron de schedule du job"
}

variable "queries" {
  type = map(map(string))
}

variable "jdbc-url-secret-name" {
  type        = string
  description = "nom du secret contenant l'url de connexion jdbc à la BDD"
}

variable "dataset_name" {
  type        = string
  description = "nom du projet"
}

variable "type_database" {
  type        = string
  description = "type de base de données: oracle ou postgresql"
}

variable "notification_channels" {
  type        = list(string)
  description = "canal de notification pour les alertes sur dataproc"
}

variable "isTruncate" {
  type        = string
  default     = "true"
  description = "Si true, vide la table cible, si false, ajoute les données à l'existant"
}


variable "secret_management_project_id" {
  type        = string
  description = "ID du projet contenant les secrets."
  default     = "prj-dinum-p-secret-mgnt-aaf4"
}

variable "subnetwork_name" {
  type        = string
  description = "Nom du sous-réseau à utiliser pour les workers Dataflow."
  default     = "subnet-for-vpn"
}
