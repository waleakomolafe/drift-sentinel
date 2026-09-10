# Example layout

Drift Sentinel assumes one directory per environment per cloud:

```
envs/
  prod/
    azure/        # azurerm provider, remote state in a storage account
      main.tf
      backend.tf
    aws/          # aws provider, remote state in S3 + DynamoDB lock
      main.tf
      backend.tf
  nonprod/
    ...
```

Point the workflow's matrix at whichever of these you want watched:

```yaml
strategy:
  matrix:
    include:
      - name: azure
        dir: envs/prod/azure
      - name: aws
        dir: envs/prod/aws
```

Watch production first. Non-prod drifts constantly and by design — alerting on it
is how a check gets ignored.
