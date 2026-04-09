# CredCheck CI/CD - Exercise

CredCheck is a Salesforce ISV that ships a 1GP managed package (namespace: `credcheck`) to subscriber orgs. The package provides automated credential verification for healthcare organizations.

## Environment Overview

| Environment | Namespace | Branch | Purpose |
|-------------|-----------|--------|---------|
| Developer scratch orgs | credcheck | feature/* | Individual dev work |
| QA | CredCheck_QA | qa | QA testing before packaging |
| Staging | (none) | staging | Customer-like testing, no namespace |
| Packaging org | credcheck | master | Source of truth for managed package |
| Subscriber orgs | credcheck | (installed) | Customer production environments |

## Your Task

There is an open pull request on this repo that adds a new GitHub Actions workflow: `deploy-production.yml`. The workflow is meant to deploy the CredCheck managed package to the packaging org.

The workflow has issues: bugs that will cause failures, security problems, and best-practice violations.

**Your job:**

1. Check out the PR branch
2. Find and fix the issues in `.github/workflows/deploy-production.yml`
3. Push your fixes
4. The **validate-deploy-workflow** CI check must pass

The validation checks for 10 specific issues. Fix as many as you can.

## Context

For reference, the project includes:

- Working CI workflows in `.github/workflows/` (`ci-dev.yml`, `ci-qa.yml`, `ci-staging.yml`)
- Project configuration: `sfdx-project.json`, `cumulusci.yml`, `package.json`
- Destructive changes metadata in `assets/destructiveChanges/`
- Custom metadata with placeholder secrets in `force-app/main/customMetadata/`
- Scratch org setup script in `assets/scripts/bash/setup_scratch_org.sh`
