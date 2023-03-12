#!/usr/bin/env bash

#set -o errexit -o nounset -o pipefail
set -o xtrace

SA_FOR_TANZU_SYNC=${SA_FOR_TANZU_SYNC:-tanzu-sync-secrets}
SA_FOR_TAP=${SA_FOR_TAP:-tap-install-secrets}

gcloud iam service-accounts create ${SA_FOR_TANZU_SYNC} --display-name="Service Account which will be used to access Tanzu Sync secrets"
gcloud iam service-accounts create ${SA_FOR_TAP} --display-name="Service Account which will be used to access Tanzu Sync secrets"

gcloud projects add-iam-policy-binding ${GCP_PROJECT} --member="serviceAccount:${SA_FOR_TANZU_SYNC}@${GCP_PROJECT}.iam.gserviceaccount.com" --role='roles/secretmanager.secretAccessor'
gcloud projects add-iam-policy-binding ${GCP_PROJECT} --member="serviceAccount:${SA_FOR_TAP}@${GCP_PROJECT}.iam.gserviceaccount.com" --role='roles/secretmanager.secretAccessor'

gcloud projects add-iam-policy-binding ${GCP_PROJECT} --member="serviceAccount:${SA_FOR_TANZU_SYNC}@${GCP_PROJECT}.iam.gserviceaccount.com" --role='roles/iam.serviceAccountTokenCreator'
gcloud projects add-iam-policy-binding ${GCP_PROJECT} --member="serviceAccount:${SA_FOR_TAP}@${GCP_PROJECT}.iam.gserviceaccount.com" --role='roles/iam.serviceAccountTokenCreator'

gcloud iam service-accounts add-iam-policy-binding ${SA_FOR_TANZU_SYNC}@${GCP_PROJECT}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${GCP_PROJECT}.svc.id.goog[tanzu-sync/tanzu-sync-secrets]"

gcloud iam service-accounts add-iam-policy-binding ${SA_FOR_TAP}@${GCP_PROJECT}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${GCP_PROJECT}.svc.id.goog[tap-install/tap-install-secrets]"
