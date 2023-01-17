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
  additional_sources:
  # Add scanners and scanpolicies
  - git:
      ref: origin/main
      subPath: scan
      url: https://github.com/atmandhol/tap-nsp-gitops.git
    path: _ytt_lib/scansetup
```