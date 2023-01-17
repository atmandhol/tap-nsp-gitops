# tap-nsp-gitops
This repo contains resources that I want to create in my Developer namespaces on my TAP cluster using GitOps and Namespace Provisioner (NSP).

This tutorial is using the following:
- Tanzu Application Platform 1.4 (I am using GKE as infra)
- Namespace Provisioner for TAP (Installed as part of TAP 1.4 profile installation)
- Google Secrets Manager
- External Secrets Operator (Is shipped as a Package in TAP 1.4 and can be installed manually as follows)
```
tanzu package install external-secrets-package --package-name external-secrets.apps.tanzu.vmware.com --version 0.6.1+tap.2 --namespace tap-install
```

## Namespace Provisioner TAP Config

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
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: desired-namespaces-overlay
  namespace: tap-install
  annotations:
    kapp.k14s.io/change-rule: "delete after deleting tap"
stringData:
  annotate-desired-namespaces-configmap-with-exists.yaml: |
    #@ load("@ytt:overlay", "overlay")
    #@overlay/match by=overlay.subset({"metadata":{"name":"desired-namespaces"}, "kind": "ConfigMap"})
    ---
    metadata:
      annotations:
        #@overlay/match missing_ok=True
        kapp.k14s.io/exists: ""
EOF
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