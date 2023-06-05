Namespace provisioner TAP values configuration

```yaml
namespace_provisioner:
  controller: false
  additional_sources:
  - git:
      ref: origin/hitachi
      subPath: namespace
      url: https://github.com/atmandhol/tap-nsp-gitops.git
  gitops_install:
    ref: origin/hitachi
    subPath: install
    url: https://github.com/atmandhol/tap-nsp-gitops.git
```