locals {
  secret-managment-project = "prj-dinum-p-secret-mgnt-aaf4"
}

resource "google_service_account" "service_account" {
  account_id   = "sa-${var.dataset_name}"
  display_name = "Service Account created by terraform for ${var.project_id}"
  project      = var.project_id
}

resource "google_project_iam_member" "bigquery_editor_bindings" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "bigquery_user_bindings" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "dataflow_worker_bindings" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_service_account_iam_member" "gce-default-account-iam" {
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.service_account.email}"
  service_account_id = google_service_account.service_account.name
}

resource "google_project_iam_custom_role" "dataflow-custom-role" {
  project     = var.project_id
  role_id     = "dataflow_custom_role"
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

resource "google_project_iam_member" "service_account_bindings_storage_admin" {
  project  = var.project_id
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "service_account_bindings_storage_viewer" {
  project  = var.project_id
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "service_account_bindings_dataflow_admin" {
  project  = var.project_id
  role     = "roles/dataflow.admin"
  member   = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "service_account_bindings_dataflow_worker" {
  project  = var.project_id
  role     = "roles/dataflow.worker"
  member   = "serviceAccount:${google_service_account.service_account.email}"
}

####
# Bucket
####

resource "google_storage_bucket" "bucket" {
  project                     = var.project_id
  name                        = "bucket-${var.dataset_name}"
  location                    = var.region
  storage_class               = "REGIONAL"
  uniform_bucket_level_access = true
  force_destroy               = true
}

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
  name             = "df-job-${var.dataset_name}-${each.key}"
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
            jobName : "df-${var.dataset_name}-${lower(replace(each.key, "_", "-"))}",
            containerSpecGcsPath : "gs://dataflow-templates-${var.region}/latest/flex/Jdbc_to_BigQuery_Flex",
            parameters : {
              driverJars : "gs://bucket-${var.dataset_name}/ojdbc8-21.7.0.0.jar,gs://bucket-${var.dataset_name}/postgresql-42.2.6.jar",
              driverClassName : "${var.type_database == "oracle" ? "oracle.jdbc.driver.OracleDriver" : "org.postgresql.Driver"}",
              connectionURL : data.google_secret_manager_secret_version.jdbc-url-secret.secret_data,
              query : each.value.query,
              outputTable : "${var.project_id}:${var.dataset_name}.${each.value.bigquery_location}",
              bigQueryLoadingTemporaryDirectory : "gs://bucket-${var.dataset_name}/tmp",
              isTruncate : var.isTruncate,
              stagingLocation : "gs://dataflow-staging-${var.region}-419271540634/staging",
              serviceAccount : google_service_account.service_account.email,
            },
            environment : {
              numWorkers : 1,
              tempLocation : "gs://bucket-${var.dataset_name}/tmp",
              subnetwork : "regions/${var.region}/subnetworks/subnet-for-vpn",
              serviceAccountEmail: google_service_account.service_account.email,
            }
          }
        }
      )
    )
  }
}
