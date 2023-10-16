Namespace provisioner TAP values configuration

```yaml
namespace_provisioner:
  controller: false
  gitops_install:
    url: https://github.com/atmandhol/tap-nsp-gitops.git
    subPath: desired-namespace/1201-run-test-japaneast-aks
    ref: origin/hisol
    # secretRef:
    #   name: namespace-provisioner-git-auth
    #   namespace: tap-install
    #   create_export: true
  # overlay_secrets:
  # - name: workload-git-auth-overlay
  #   namespace: tap-install
  #   create_export: true
  additional_sources:
  - git:
      url: https://github.com/atmandhol/tap-nsp-gitops.git
      subPath: template/common
      ref: origin/hisol
      # secretRef:
      #   name: namespace-provisioner-git-auth2
      #   namespace: tap-install
      #   create_export: true
    path: _ytt_lib/0001_common
  - git:
      url: https://github.com/atmandhol/tap-nsp-gitops.git
      subPath: template/run
      ref: origin/hisol
      # secretRef:
      #   name: namespace-provisioner-git-auth3
      #   namespace: tap-install
      #   create_export: true
    path: _ytt_lib/1201-run-test-japaneast-aks
```