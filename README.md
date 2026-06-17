# gcp-dataflow-to-bigquery
Module terraform pour transférer des tables on premise vers BigQuery

Les tables et leur schéma doivent exister pour que le job fonctionne.  
Pour cela :
- Selectionner les tables à migrer depuis Dbeaver et faire générer du SQL -> DDL
- Mettre le contenu dans un fichier ddl.sql en ne gardant que le structure des requêtes inscrites dans le module
- Utiliser SQL translator depuis GCP afin de convertir en google SQL
- exécuter la requête qui va créer les tables.

Exemple d'utilisation du module :
```
module "cagou-dataflow" {
  source                = "git::https://github.com/gouv-nc-data/gcp-dataflow-to-bigquery.git//?ref=v1.1"
  project_id            = module.dass-datawarehouse.project_id
  group_name            = local.dass_group_name
  region                = var.region
  dataset_name          = "cagou"
  schedule              = "2 * * 1-5" # les minutes sont gérées par le module
  type_database         = "oracle"
  notification_channels = module.dass-datawarehouse.notification_channels
  jdbc-url-secret-name  = "cagou-jdbc-url-secret-prefix-jdbc"
  queries = {
    "T_MEMBRE" = {
      bigquery_location = "T_MEMBRE",
      query             = "SELECT ID_MEMBRE, ID_COMM_GEST, TITULAIRE, ID_TITRE, ID_COMMUNE, FONCTION, ID_CIVILITE, ID_CODE_POSTAL, PVS, PVN, PVI, VERSION_NUM, DATCRE, DATMAJ, USERCRE, USERMAJ FROM CAGOU.T_MEMBRE"
    },
    "T_REPRESENTANT" = {
      bigquery_location = "T_REPRESENTANT",
      query             = "SELECT ID_REPRESENTANT, ID_STATUT_REP, ID_CIVILITE_REP, NUMCAF_REP, ID_ADR_REP, DATECRE, DATEMAJ, USERCRE, USERMAJ, VERSIONNUM FROM CAGOU.T_REPRESENTANT"
    }
  }
}
```

Attention mettre le schema dans le from de la requête.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloud_scheduler_job.job](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_scheduler_job) | resource |
| [google_monitoring_alert_policy.errors](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |
| [google_project_iam_custom_role.dataflow-custom-role](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_custom_role) | resource |
| [google_project_iam_member.dataflow_custom_worker_bindings](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.project_roles](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.cloudschedulerapi](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.dataflowapi](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.secretmanagerapi](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.gce-default-account-iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_storage_bucket.bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_secret_manager_secret_version.jdbc-url-secret](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_dataset_name"></a> [dataset\_name](#input\_dataset\_name) | nom du projet | `string` | n/a | yes |
| <a name="input_group_name"></a> [group\_name](#input\_group\_name) | Google groupe associé au projet | `string` | n/a | yes |
| <a name="input_isTruncate"></a> [isTruncate](#input\_isTruncate) | Si true, vide la table cible, si false, ajoute les données à l'existant | `string` | `"true"` | no |
| <a name="input_jdbc-url-secret-name"></a> [jdbc-url-secret-name](#input\_jdbc-url-secret-name) | nom du secret contenant l'url de connexion jdbc à la BDD | `string` | n/a | yes |
| <a name="input_notification_channels"></a> [notification\_channels](#input\_notification\_channels) | canal de notification pour les alertes sur dataproc | `list(string)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | id du projet | `string` | n/a | yes |
| <a name="input_queries"></a> [queries](#input\_queries) | n/a | `map(map(string))` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | n/a | `string` | `"europe-west1"` | no |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | expression cron de schedule du job | `string` | n/a | yes |
| <a name="input_secret_management_project_id"></a> [secret\_management\_project\_id](#input\_secret\_management\_project\_id) | ID du projet contenant les secrets. | `string` | `"prj-dinum-p-secret-mgnt-aaf4"` | no |
| <a name="input_subnetwork_name"></a> [subnetwork\_name](#input\_subnetwork\_name) | Nom du sous-réseau à utiliser pour les workers Dataflow. | `string` | `"subnet-for-vpn"` | no |
| <a name="input_type_database"></a> [type\_database](#input\_type\_database) | type de base de données: oracle ou postgresql | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->