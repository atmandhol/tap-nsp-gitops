# tap-nsp-gitops
This repo contains resources that I want to create in my Developer namespaces on my TAP cluster using GitOps and Namespace Provisioner (NSP).

This tutorial is using the following:
- `Tanzu Application Platform` 1.4
  - I am using GKE as infra of choice.
- `Namespace Provisioner` for TAP for provisioning resources in our developer namespaces.
  - Namespace Provisioner (NSP) is installed as part of TAP 1.4 profile installation.
- `Google Secrets Manager` for storing all our secrets.
- `External Secrets Operator` (ESO) to pull the secrets from Google Secrets Manager into our TAP Cluster.
  - ESO is shipped as a Package in TAP 1.4 and can be installed manually.

## External Secrets Operator Setup

We will install the External secrets operator on our TAP cluster and connect it to our Google Secrets Manager so we can pull all our secrets in our cluster securely.

### Pre-requisites
- GCP account and a Service account JSON key that has access to Google Secrets Manager to read the secrets.

### Install External Secrets Operator

It is already shipped as a package in TAP 1.4, so we can install is using the following command
```bash
tanzu package install external-secrets-package --package-name external-secrets.apps.tanzu.vmware.com --version 0.6.1+tap.2 --namespace tap-install
```

### Create a Secret with GCP Service Account JSON creds for ESO

Run the following command to create a generic secret.
```bash
kubectl create secret generic google-secret-manager-secret --namespace external-secrets --from-file ${PATH-TO-YOUR-JSON-FILE}
```

Label the secret for ESO to know what kind of secret it is.
```bash
kubectl label secret google-secret-manager-secret --namespace external-secrets type=gcpsm
```

Create the ClusterSecretStore. `GCP-PROJECT` is the name of the Google Cloud Platform project and `key` is the name of the key in secret, normally its the same as the name of the JSON file. 

```bash
ytt -f https://raw.githubusercontent.com/atmandhol/tap-nsp-gitops/main/tap/01-cluster-secret-store-gcp.yaml -v gcp_project=${GCP-PROJECT} -v key=$(kubectl get secret google-secret-manager-secret -n external-secrets -o json | jq -r .data | jq -r 'keys' | jq -r '.[0]') |
 kubectl apply -f -
```

## Namespace Provisioner Setup

```yaml
namespace_provisioner:
  # We are setting this to false as we will manage the desired-namespaces configmap using GitOps. All the namespaces we want to create and their params are in ns folder in the https://github.com/atmandhol/tap-nsp-gitops.git repo.
  controller: false
  additional_sources:
  # Add scanners and scanpolicies
  - git:
      ref: origin/main
      subPath: scan
      url: https://github.com/atmandhol/tap-nsp-gitops.git
    path: _ytt_lib/scansetup
  # Add parameterized tekton test pipeline
  - git:
      ref: origin/main
      subPath: test
      url: https://github.com/atmandhol/tap-nsp-gitops.git
    path: _ytt_lib/testsetup
  # Add default resource constraints on your namespaces and pods
  - git:
      ref: origin/main
      subPath: constraints
      url: https://github.com/atmandhol/tap-nsp-gitops.git
    path: _ytt_lib/resourceconstraintssetup
  # Extras
  - git:
      ref: origin/main
      subPath: extras
      url: https://github.com/atmandhol/tap-nsp-gitops.git
    path: _ytt_lib/extras
```

## Manage Desired namespaces via GitOps

We will use `kapp App` to sync the desired namespaces from our GitOps repo to our TAP cluster. Namespace provisioner also uses kapp and owns the `desired-namespaces` ConfigMap on the cluster. We will add an annotation `kapp.k14s.io/exists: ""` to the Namespace provisioner default `desired-namespaces` ConfigMap using a Package overlay so the 2 `kapp Apps` don't fight over ownership issues.

### Create an Overlay secret

```bash
kubectl apply -f https://raw.githubusercontent.com/atmandhol/tap-nsp-gitops/main/tap/02-desired-namespace-overlay.yaml
```
### Update the TAP Config with NSP Package Overlay

Add the following to the tap values config

```yaml
package_overlays:
- name: namespace-provisioner
  secrets:
  - name: desired-namespaces-overlay
```

### Create the kapp App that will sync desired-namespaces from GitOps repo

We will now create a Carvel App that:
- Creates the `desired-namespaces` ConfigMap from this GitOps Repo and owns that ConfigMap.
- Creates all the namespaces mentioned in the `desired-ns-list.yaml` in the `ns` folder in our GitOps repo.

```bash
kubectl apply -f https://github.com/atmandhol/tap-nsp-gitops/raw/main/apps/01-desired-namespaces-sync.yaml
```
