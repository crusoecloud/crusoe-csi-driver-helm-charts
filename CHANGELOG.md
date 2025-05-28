
## v0.7.0

### Breaking Changes

* The default `crusoe.secrets.crusoeApiKeys.accessKeyPath` and `crusoe.secrets.crusoeApiKeys.secretKeyPath` have changed to `CRUSOE_ACCESS_KEY` and `CRUSOE_SECRET_KEY` respectively.
  * Users with an existing Crusoe API key secret who have not explicitly specified both values will need to update the secret name and key paths in their `values.yaml` accordingly. 