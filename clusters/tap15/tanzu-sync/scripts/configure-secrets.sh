#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail
#set -o xtrace

# function usage() {
#   cat << EOF
# $0 :: configure Tanzu Sync for use with External Secrets Operator (ESO)

# Required Environment Variables:
# - AWS_ACCOUNT_ID -- Account ID owning the named IAM Policy
# - EKS_CLUSTER_NAME -- cluster on which TAP is being installed

# Optional:
# - IAM_ROLE_NAME_FOR_TANZU_SYNC -- name of IAM Role (to be created) which will be used to access Tanzu Sync secrets
# - IAM_ROLE_NAME_FOR_TAP -- name of IAM Role (to be created) which will be used to access TAP sensitive values

# EOF
# }

function usage() {
  cat << EOF
$0 :: configure Tanzu Sync for use with External Secrets Operator (ESO)

Required Environment Variables:
- GCP_PROJECT -- Google Cloud project where the GKE cluster is
- GKE_CLUSTER_NAME -- cluster on which TAP is being installed

Optional:
- SA_FOR_TANZU_SYNC -- name of the Service Account (to be created) which will be used to access Tanzu Sync secrets
- SA_FOR_TAP -- name of the Service Account (to be created) which will be used to access TAP sensitive values

EOF
}

# for envvar in AWS_ACCOUNT_ID EKS_CLUSTER_NAME ; do
#   if [[ ! -v ${envvar} ]]; then
#     usage
#     echo "Expected env var ${envvar} to be set, but was not."
#     exit 1
#   fi
# done

SA_FOR_TANZU_SYNC=${SA_FOR_TANZU_SYNC:-tanzu-sync-secrets}
SA_FOR_TAP=${SA_FOR_TAP:-tap-install-secrets}

# configure
# (see: tanzu-sync/app/config/.tanzu-managed/schema.yaml)
ts_values_path=tanzu-sync/app/values/tanzu-sync-eso.yaml
cat > ${ts_values_path} << EOF
---
secrets:
  eso:
    gcp:
      tanzu_sync_secrets:
        serviceAccount: ${SA_FOR_TANZU_SYNC}@${GCP_PROJECT}.iam.gserviceaccount.com
    remote_refs:
      sync_git_ssh:
        ssh_private_key:
          key: sync-git-ssh
          property: ssh-privatekey
        ssh_known_hosts:
          key: sync-git-ssh
          property: ssh-knownhosts
      install_registry_dockerconfig:
        dockerconfigjson:
          key: tanzunet-dockerconfig
EOF

## Removed from the above file
# aws:
#   tanzu_sync_secrets:
#     roleARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME_FOR_TANZU_SYNC}


echo "wrote ESO configuration for Tanzu Sync to: ${ts_values_path}"

tap_install_values_path=cluster-config/values/tap-install-eso-values.yaml
cat > ${tap_install_values_path} << EOF
---
tap_install:
  secrets:
    eso:
      gcp:
        tanzu_sync_secrets:
          serviceAccount: ${SA_FOR_TAP}@${GCP_PROJECT}.iam.gserviceaccount.com
      remote_refs:
        tap_sensitive_values:
          sensitive_tap_values_yaml:
            key: sensitive-values
EOF

echo "wrote ESO configuration for TAP install to: ${tap_install_values_path}"

## Removed from the above file
# aws:
#   tap_install_secrets:
#     roleARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME_FOR_TAP}
