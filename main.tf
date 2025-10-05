locals {
  secret-managment-project = var.secret_management_project_id
  safe-ds-name = substr(lower(replace(var.dataset_name, "_", "-")),0,24)
}

resource "google_service_account" "service_account" {
  account_id   = "sa-df-${local.safe-ds-name}"
  display_name = "Service Account created by terraform for ${var.project_id}"
  project      = var.project_id
}

resource "google_project_iam_member" "project_roles" {
  for_each = toset([
    "roles/bigquery.dataEditor",
    "roles/bigquery.user",
    "roles/dataflow.worker",
    "roles/storage.objectAdmin",
    "roles/storage.objectViewer",
    "roles/dataflow.admin"
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_service_account_iam_member" "gce-default-account-iam" {
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.service_account.email}"
  service_account_id = google_service_account.service_account.name
}

resource "google_project_iam_custom_role" "dataflow-custom-role" {
  project     = var.project_id
  role_id     = "dataflow_custom_role_${var.dataset_name}"
  title       = "Dataflow Custom Role"
  description = "Role custom pour pouvoir créer des job dataflow depuis scheduler"
  permissions = ["iam.serviceAccounts.actAs", "dataflow.jobs.create", "storage.objects.create", "storage.objects.delete",
    "storage.objects.get", "storage.objects.getIamPolicy", "storage.objects.list"]
}

resource "google_project_iam_member" "dataflow_custom_worker_bindings" {
  project    = var.project_id
  role       = "projects/${var.project_id}/roles/${google_project_iam_custom_role.dataflow-custom-role.role_id}"
  member     = "serviceAccount:${google_service_account.service_account.email}"
  depends_on = [google_project_iam_custom_role.dataflow-custom-role]
}

####
# Bucket
####

resource "google_storage_bucket" "bucket" {
  project                     = var.project_id
  name                        = "bucket-df-${local.safe-ds-name}"
  location                    = var.region
  storage_class               = "REGIONAL"
  uniform_bucket_level_access = true
  force_destroy               = true
}

# resource "null_resource" "ojdbc_driver" {
#   provisioner "local-exec" {
#     command = "curl https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/21.7.0.0/ojdbc8-21.7.0.0.jar | gsutil cp - ${google_storage_bucket.bucket.url}/ojdbc8-21.7.0.0.jar"
#   }
# }

####
# Dataflow
####
resource "google_project_service" "dataflowapi" {
  project = var.project_id
  service = "dataflow.googleapis.com"
}

resource "google_project_service" "secretmanagerapi" {
  project = var.project_id
  service = "secretmanager.googleapis.com"
}

resource "google_project_service" "cloudschedulerapi" {
  project = var.project_id
  service = "cloudscheduler.googleapis.com"
}

data "google_secret_manager_secret_version" "jdbc-url-secret" {
  project = local.secret-managment-project
  secret  = var.jdbc-url-secret-name
}

resource "google_cloud_scheduler_job" "job" {
  for_each         = var.queries
  project          = var.project_id
  name             = "df-job-${local.safe-ds-name}-${lower(replace(each.key, "_", "-"))}"
  schedule         = "${index(keys(var.queries), each.key) % 60} ${var.schedule}"
  time_zone        = "Pacific/Noumea"
  attempt_deadline = "320s"
  depends_on = [ google_project_service.cloudschedulerapi ]

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = "https://dataflow.googleapis.com/v1b3/projects/${var.project_id}/locations/${var.region}/flexTemplates:launch"
    oauth_token {
      service_account_email = google_service_account.service_account.email
    }
    body = base64encode(
      jsonencode(
        {
          launchParameter : {
            jobName : "df-${local.safe-ds-name}-${lower(replace(each.key, "_", "-"))}",
            containerSpecGcsPath : "gs://dataflow-templates-${var.region}/latest/flex/Jdbc_to_BigQuery_Flex",
            parameters : {
              driverJars : "gs://${google_storage_bucket.bucket.name}/ojdbc8-21.7.0.0.jar,gs://${google_storage_bucket.bucket.name}/postgresql-42.2.6.jar",
              driverClassName : "${var.type_database == "oracle" ? "oracle.jdbc.driver.OracleDriver" : "org.postgresql.Driver"}",
              connectionURL : data.google_secret_manager_secret_version.jdbc-url-secret.secret_data,
              query : each.value.query,
              outputTable : "${var.project_id}:${var.dataset_name}.${each.value.bigquery_location}",
              bigQueryLoadingTemporaryDirectory : "gs://${google_storage_bucket.bucket.name}/tmp",
              # createDisposition : "CREATE_IF_NEEDED", # ça ne crée pas le schéma auto, donc il faut qd meme créer la table avant
              isTruncate : var.isTruncate,
              stagingLocation : "gs://${google_storage_bucket.bucket.name}/staging",
              serviceAccount : google_service_account.service_account.email,
            },
            environment : {
              numWorkers : 1,
              tempLocation : "gs://${google_storage_bucket.bucket.name}/tmp",
              subnetwork : "regions/${var.region}/subnetworks/${var.subnetwork_name}",
              serviceAccountEmail: google_service_account.service_account.email,
            }
          }
        }
      )
    )
  }
}

###############################
# Supervision
###############################
resource "google_monitoring_alert_policy" "errors" {
  display_name = "Errors in logs alert policy on ${var.dataset_name}"
  project      = var.project_id
  combiner     = "OR"
  conditions {
    display_name = "Error condition"
    condition_matched_log {
      filter = "severity=ERROR AND resource.type=dataflow_step AND logName=(\"projects/${var.project_id}/logs/dataflow.googleapis.com%2Fjob-message\" OR \"projects/${var.project_id}/logs/dataflow.googleapis.com%2Flauncher\")"
    }
  }

  notification_channels = var.notification_channels
  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "86400s" # 1 jour
  }
}
