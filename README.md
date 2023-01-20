# tap-nsp-gitops
This repo contains resources that I want to create in my Developer namespaces on my TAP cluster using GitOps and Namespace Provisioner (NSP).

This tutorial is using the following:
- `Tanzu Application Platform` (TAP) 1.4
  - I am using GKE as infra of choice.
- `Namespace Provisioner` (NSP) for TAP for provisioning resources in our developer namespaces.
  - Namespace Provisioner is installed as part of TAP 1.4 profile installation.
- `Google Secrets Manager` (GSM) for storing all our secrets.
- `External Secrets Operator` (ESO) to pull the secrets from Google Secrets Manager into our TAP Cluster.
  - ESO is shipped as a Package in TAP 1.4 and can be installed manually.

> NOTE: This repo is currently not taking care of any TAP installation. It assumes the user already has a TAP 1.4 cluster.

## Usage
Fork/Clone this repo and update your fork with your changes. This repo serves as a base to give users a headstart.

## External Secrets Operator Setup

We will now install the External secrets operator on our TAP cluster and connect it to our [Google Secrets Manager](https://external-secrets.io/v0.7.2/provider/google-secrets-manager/) so we can pull all our secrets in our cluster securely. If you are using [another external secrets manager](https://external-secrets.io/v0.7.2/provider/aws-secrets-manager/) that is supported by External Secrets Operator, update the [`tap/01-cluster-secret-store.yaml`](tap/01-cluster-secret-store.yaml) file to match the spec of your provider of choice.

### Pre-requisites
- GCP account and a Service account JSON key that has access to Google Secrets Manager to read the secrets.

### Install External Secrets Operator (ESO)

It is already shipped as a package in TAP 1.4, so we can install is using the following command
```bash
tanzu package install external-secrets-package --package-name external-secrets.apps.tanzu.vmware.com --version 0.6.1+tap.2 --namespace tap-install
```

### GCP Service Account authentication for ESO

Run the following command to create a generic secret.
```bash
kubectl create secret generic google-secret-manager-secret --namespace external-secrets --from-file ${PATH-TO-YOUR-JSON-FILE}
```

Label the secret for ESO so that it knows what kind of secret it is. i.e. in this case a GCP Service Account for Google Secrets Manager.
```bash
kubectl label secret google-secret-manager-secret --namespace external-secrets type=gcpsm
```

Create the ClusterSecretStore. `GCP-PROJECT` is the name of the Google Cloud Platform project and `key` is the name of the key in secret, normally its the same as the name of the JSON file. 

```bash
ytt -f https://raw.githubusercontent.com/atmandhol/tap-nsp-gitops/main/tap/01-cluster-secret-store.yaml -v gcp_project=${GCP-PROJECT} -v key=$(kubectl get secret google-secret-manager-secret -n external-secrets -o json | jq -r .data | jq -r 'keys' | jq -r '.[0]') |
 kubectl apply -f -
```

## Namespace Provisioner Setup
Next step is to update the Namespace Provisioner config so we can pull in the following additional sources which contains all the resources we want to create in our namespaces. You can choose to omit some of these resources if it does not fit your needs or update the `ytt` templated resource yaml files in the following folders to match your needs.

These following paths in this GitOps repo are imported with the following NSP config:
* [scan](scan/) folder contains 
  * A `lax` and `strict` Scan Policies for Grype, Snyk, CarbonBlack and Prisma scanners in TAP 1.4. 
  * All the secrets like [`snyk-token-secret`](scan/02-snyk-scanner.yaml) that needs to be created for the scanners to work and these secrets are synced from our external secrets manager using `ExternalSecret` CR using the ESO setup that we did in the previous step.
* [test](test/) folder contains 
  * A single `ytt` templated, parameterized tekton test Pipeline to run tests on the `testing_scanning` supply chain.
  * The base `image` to use in the Tekton Pipeline and the `cmd` to run in the container are both passed as params in [`desired-namespaces`](ns/desired-ns-list.yaml) ConfigMap.
* [constraints](constraints/) folder contains 
  * A default [LimitRange](constraints/01-limit-range.yaml) object that is applied to all namespaces, but is overridable using the parameters in the [`desired-namespaces`](ns/desired-ns-list.yaml) ConfigMap.
* [extras](extras/) folder contains all random stuff that does not really fit in one of the above and its fun for testing.

Update the TAP values with the following config for NSP.
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

We will use `kapp App` [located here](apps/01-desired-namespaces-sync.yaml) to sync the desired namespaces from our GitOps repo to our TAP cluster. Namespace provisioner also uses kapp App called `provisioner` and owns the `desired-namespaces` ConfigMap on the cluster (A behavior that will be fixed in TAP 1.5). We will add an annotation `kapp.k14s.io/exists: ""` to the Namespace provisioner OOTB `desired-namespaces` ConfigMap using a Package overlay so the 2 `kapp Apps` don't fight over ownership issues.

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

We are now ready to create our kapp App that:
- Creates the [desired-namespaces](ns/desired-namespaces-configmap.yaml) ConfigMap from this GitOps Repo and owns that ConfigMap.
- Creates all the namespaces mentioned in the [desired-ns-list.yaml](ns/desired-ns-list.yaml) in the `ns` folder in our GitOps repo.
- Creates all the [Scanner Package Install](ns/scanner-install.yaml) for all namespace mentioned in the [desired-ns-list.yaml](ns/desired-ns-list.yaml) as the PackageInstall for Scanner are not currently Cluster Scoped and not properly Namespaced either.

```bash
kubectl apply -f https://github.com/atmandhol/tap-nsp-gitops/raw/main/apps/01-desired-namespaces-sync.yaml
```
