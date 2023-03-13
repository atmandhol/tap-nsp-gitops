# tap-nsp-gitops
This repo contains instructions on how to deploy TAP using GitOps and create resources in your Developer namespace on your TAP cluster using Namespace Provisioner (NSP) in full GitOps mode.

## Usage
Fork/Clone this repo and update your fork with your changes. This repo serves as a base to give users a headstart.

This tutorial is using the following:
- `Tanzu Application Platform` (TAP) 1.5 RC
- `Namespace Provisioner` (NSP) for TAP for provisioning resources in our developer namespaces.
  - Namespace Provisioner is installed as part of TAP 1.5 profile installation.
- `Google Secrets Manager` (GSM) for storing all our secrets.
- `External Secrets Operator` (ESO) to pull the secrets from Google Secrets Manager into our TAP Cluster.

## GKE cluster setup
For this setup, we need a 
- GKE cluster and a kubeconfig to it. If using gcloud command, kubeconfig is automatically added to `~/.kube/config`.
- [Workload identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) enabled on the GKE cluster.
- Install Cluster Essentials on it.

You can use a method of your choice to get this infrastructure up, I will be using [tappr](https://github.com/atmandhol/tappr), A CLI I made that helps in K8s cluster creation and TAP installation and management.

if using `tappr` (need version >=0.13.0), run the following command to create a GKE cluster in the project where your gcloud is pointing to. This cluster will have workload identity enabled by default.
```bash
tappr cluster create gke --cluster-name {cluster-name} --channel RAPID
tappr tap install-cluster-essentials
```

## Create required secrets in Google Secrets Manager

* Create a secret named `sync-git-ssh` containing the SSH private key that has access to this git repo and associated known hosts:
```json
{
  "ssh-privatekey": "-----BEGIN OPENSSH PRIVATE KEY-----\nb3B................................................................tZW\nQyN................................................................6XZ\nMQA................................................................x+w\nAAA................................................................0pR\na6I..........................xQF\n-----END OPENSSH PRIVATE KEY-----\n",
  "ssh-knownhosts": "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
}
```
* Next, a secret with creds for Tanzu Network so we can install TAP. Create a secret `tanzunet-dockerconfig` in Google secrets manager with following value:
```json
{
  "auths": {
    "registry.tanzu.vmware.com": {
      "username": "user@vmware.com",
      "password": ""
    }
  }
}
```
* Finally, create a YAML format secret called `sensitive-values` in Google Secrets manager with all the sensitive values you have for your setup. Bare-minimum is the registry credentials that has pull/push access to a repo.

 ```yaml
# Use your creds
shared:
  image_registry:
    project_path: "gcr.io/adhol-playground/tap"
    username: "_json_key"
    password: |
      { ... put actual service account JSON, here ... }
```

## Install TAP from this GitOps repo
The following set of commands will do the following:
* Create a tanzu_sync app that
  * Install External Secrets Operator
  * Installs TAP Package Repository and required Sync secrets
  * Installs required Tanzu Network secret
  * Creates a GitOps managed TAP install app
* Creates GCP IAM service accounts for Sync app and setup the Kubernetes Service Accounts created by the Sync app with Workload identity pointing to those GCP IAM service accounts.
* Pulls the secrets created in previous setup from Google secrets manager using the External secrets operator.
* Starts TAP installation based on the values provided in the `clusters/tap15/cluster-config/values/tap-values.yaml`.
* Installs a TAP Install Sync App that keep the cluster state in sync with the values in the GitOps repo.

```bash
# Update this with your values
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=adhol@vmware.com
export INSTALL_REGISTRY_PASSWORD=""
# KUBECONTEXT of the k8s cluster created above
export KAPP_KUBECONFIG_CONTEXT=""
export GCP_PROJECT=adhol-playground
# Cluster name used while creating the GKE cluster
export GKE_CLUSTER_NAME=""
export GKE_CLUSTER_REGION=us-east4
export TAP_VERSION=1.5.0-build.37
cd clusters/tap15
./tanzu-sync/scripts/bootstrap.sh
./tanzu-sync/scripts/configure.sh
git add cluster-config/ tanzu-sync/
git commit -m "fix: Configure install of TAP 1.5.0"
git push
./tanzu-sync/scripts/gcp/create-sa.sh
./tanzu-sync/scripts/deploy.sh
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
