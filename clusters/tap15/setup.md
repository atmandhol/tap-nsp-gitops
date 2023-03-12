## Tanzu Sync (w/ External Secrets Operator)

### Pre-Requisites

- gcloud CLI : https://cloud.google.com/sdk/docs/install
- a GKE cluster with Workload Identity Enabled. Docs on how to enable Workload Identity : https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity

### Pre-Installation

0. Verify the current terminal session is properly authenticated and targeting the correct cluster
   ```console
   $ gcloud info
    ...
    Account: [...]
    Project: [...]
    ...
   ```

1. In Google Secrets Manager, save credentials for Tanzu Sync:
   1. create a secret containing the SSH private key that has access to this git repo and associated known hosts:
      ```json
      {
        "ssh-privatekey": "-----BEGIN OPENSSH PRIVATE KEY-----\nb3B................................................................tZW\nQyN................................................................6XZ\nMQA................................................................x+w\nAAA................................................................0pR\na6I..........................xQF\n-----END OPENSSH PRIVATE KEY-----\n",
        "ssh-knownhosts": "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
      }
      ```
      - By default, this secret's name must be: `sync-git-ssh`.

   2. create a secret containing the credentials for the OCI registry hosting TAP software:
      ```json
      {
        "auths": {
          "registry.tanzu.vmware.com": {
            "username": "adhol@vmware.com",
            "password": ""
          }
        }
      }
      ```
      - Using the defaults, this secret's name is: `tanzunet-dockerconfig`.

2. In AWS Secrets Manager, save the "sensitive values" for Tanzu Application Platform :
   1. create a secret which will contain _all_ sensitive values for the TAP install. \
      At a minimum this would be credentials to an OCI registry with read/write perms for `shared.image_registry`.
      Example: using GCR as build registry:
       ```
       shared:
         image_registry:
           project_path: "gcr.io/adhol-playground/tap"
           username: "_json_key"
           password: |
             { ... put actual service account JSON, here ... }
       ```
      - Using the defaults, this secret's name is: `sensitive-values`.

3. In Google Cloud IAM, create two Service accounts that will grant read access to secrets
   for your cluster: one for Tanzu Sync secrets; the other TAP install values:
   ```console
   $ ./tanzu-sync/scripts/gcp/create-sa.sh
   ```
