## Tanzu Sync

### Install Tanzu Sync

1. Generate Tanzu Sync configuration file
   ```console
   $ ./tanzu-sync/scripts/configure.sh
   ```
   (review, commit, and push the configuration)

2. Deploy
   ```console
   $ ./tanzu-sync/scripts/deploy.sh
   ```

### Verification

- Verify TAP packages are installed 
  - `kubectl get pkgi -n tap-install`: all should say, "Reconcile succeeded"
