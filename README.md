# CredCheck CI/CD

CredCheck is a Salesforce ISV that ships a 1GP managed package (namespace: `credcheck`) to subscriber orgs. The package provides automated credential verification for healthcare organizations.

## Environment Overview

| Environment | Namespace | Branch | Purpose |
|-------------|-----------|--------|---------|
| Developer scratch orgs | credcheck | feature/* | Individual dev work |
| QA | CredCheck_QA | qa | QA testing before packaging |
| Staging | (none) | staging | Customer-like testing, no namespace |
| Packaging org | credcheck | master | Source of truth for managed package |
| Subscriber orgs | credcheck | (installed) | Customer production environments |

## CI/CD

Pull requests run the `validate` job (formatting, source conversion). Pushes to `main` also run the `deploy` job against the packaging org.

## Project Structure

```
force-app/
  fflib/           # Enterprise patterns library
  main/
    classes/       # Apex controllers and services
    customMetadata # Package configuration
assets/
  scripts/bash/    # Org setup and deploy scripts
  destructiveChanges/  # Metadata removal definitions
config/            # Scratch org definitions
```
