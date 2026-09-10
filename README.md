# Drift Sentinel

Scheduled Terraform drift detection that **opens a pull request instead of an alert**.

A Slack message nobody reads is not a control. A pull request somebody has to close is.

---

## The problem this solves

`terraform plan` tells you what your code *would* change.
`terraform plan -refresh-only` tells you what somebody **already changed without it**.

That second one is the drift that pages you at 3am, six weeks after the fact — and the
reason it takes six weeks is that nothing was looking. Drift detection at apply time only
runs when you were going to change that resource anyway.

Real example, Azure. Someone fixes a live outage by adding an NSG rule in the portal. The
fix is *correct* — it stopped the bleeding. It never goes back into code. Six weeks later
a deploy fails in a way that makes no sense, because the state file says two rules and
production has three.

```
$ terraform plan -refresh-only

Note: Objects have changed outside of Terraform

  ~ resource "azurerm_network_security_group" "web" {
        name = "nsg-web-prod"
      + security_rule {
        + name                   = "tmp-allow-8080"
        + priority               = 310
        + destination_port_range = "8080"
        }
    }
```

## What it does

| | |
|---|---|
| **Runs on a schedule** | nightly cron, not only when you happen to apply |
| **Both clouds** | one workflow, an Azure leg and an AWS leg, in a matrix |
| **Opens a PR** | with the rendered `terraform show` diff, labelled `needs-decision` |
| **Fails the job** | on purpose — a green pipeline with drift in it is a lie |
| **Never auto-reconciles** | see below |

## Why it does not auto-apply

The obvious next step is to have it reconcile automatically. Don't.

Auto-reconciling reverts the change silently — including the change that was **correct**
and stopped an outage. It converts a visible problem into an invisible one, and the next
person hits the same incident with the fix mysteriously gone. Worse, it trains everyone
to ignore drift, because "the robot handles it".

The point of drift detection is not to erase drift. It is to force a decision:
bring the change into code, or revert it deliberately.

## Setup

1. Copy `.github/workflows/drift-sentinel.yml` into your repo.
2. Point the matrix `dir` values at your environment directories.
3. Configure OIDC federation so no long-lived cloud keys are needed:

**Azure** — a federated credential on an app registration
([docs](https://learn.microsoft.com/azure/developer/github/connect-from-azure)).
Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.

**AWS** — an IAM role trusting GitHub's OIDC provider
([docs](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)).
Secret: `AWS_ROLE_ARN`. Variable: `AWS_REGION`.

4. Give the plan identity **read-only** access. It never applies anything.
5. Run it once by hand from the Actions tab rather than waiting for the cron.

## Exit codes

`-detailed-exitcode` is doing the real work:

| code | meaning | what the workflow does |
|---|---|---|
| 0 | no drift | job passes, silent |
| 1 | terraform errored | **job fails** — an error must never be reported as "no drift" |
| 2 | drift found | opens the PR, then fails the job |

Conflating 1 and 2 is the most common way this kind of check goes quietly dead.

## Prior art

The pull-request-as-control idea comes from two people whose public work I read:
[Patrick Koch](https://www.linkedin.com/in/patrick-koch-azure/)'s Azure landing-zone
material, and Ewuji Oluwaseyi John's Terraform Azure FinOps pull-request guardrail.
I pointed the same idea at drift.

## Licence

MIT. Use it, fork it, tell me what's wrong with it.
