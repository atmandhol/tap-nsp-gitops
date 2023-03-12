#!/usr/bin/env bash

#set -o errexit -o nounset -o pipefail
set -o xtrace

SA_FOR_TANZU_SYNC=${SA_FOR_TANZU_SYNC:-tanzu-sync-secrets}
SA_FOR_TAP=${SA_FOR_TAP:-tap-install-secrets}

gcloud projects remove-iam-policy-binding ${GCP_PROJECT} --member="serviceAccount:${SA_FOR_TANZU_SYNC}@${GCP_PROJECT}.iam.gserviceaccount.com" --role='roles/secretmanager.secretAccessor'
gcloud projects remove-iam-policy-binding ${GCP_PROJECT} --member="serviceAccount:${SA_FOR_TAP}@${GCP_PROJECT}.iam.gserviceaccount.com" --role='roles/secretmanager.secretAccessor'

gcloud iam service-accounts delete ${SA_FOR_TANZU_SYNC}@${GCP_PROJECT}.iam.gserviceaccount.com -q
gcloud iam service-accounts delete ${SA_FOR_TAP}@${GCP_PROJECT}.iam.gserviceaccount.com -q

