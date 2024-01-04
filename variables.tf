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
  type        = bool
  default     = true
  description = "Si vrai, vide la table cible, si faux, ajoute les données à l'existant"
}
