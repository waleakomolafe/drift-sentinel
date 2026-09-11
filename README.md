# Drift Sentinel

![selftest](https://github.com/waleakomolafe/drift-sentinel/actions/workflows/selftest.yml/badge.svg)

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

Drift Sentinel is a **reusable workflow**. You call it; you do not copy it. That means a
fix here reaches you without you re-copying anything.

Create `.github/workflows/drift.yml` in your repo:

```yaml
name: drift

on:
  schedule:
    - cron: "0 2 * * *"
  workflow_dispatch:

jobs:
  drift:
    uses: waleakomolafe/drift-sentinel/.github/workflows/drift-sentinel.yml@v1
    with:
      directories: >-
        [
          {"name":"azure","dir":"envs/prod/azure","cloud":"azure"},
          {"name":"aws","dir":"envs/prod/aws","cloud":"aws"}
        ]
      aws_region: us-east-1
    secrets: inherit
```

Change the `dir` values to your environment directories. That is the whole setup.

### Inputs

| input | required | default | what it is |
|---|---|---|---|
| `directories` | yes | — | JSON array of `{name, dir, cloud}`. `cloud` is `azure`, `aws`, or `none` if credentials are already present |
| `terraform_version` | no | `1.9.8` | version passed to `setup-terraform` |
| `aws_region` | no | `""` | region for the AWS credential step |

### Credentials

OIDC federation, so there are no long-lived cloud keys:

**Azure** — a federated credential on an app registration
([docs](https://learn.microsoft.com/azure/developer/github/connect-from-azure)).
Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.

**AWS** — an IAM role trusting GitHub's OIDC provider
([docs](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)).
Secret: `AWS_ROLE_ARN`.

Give the plan identity **read-only** access. It never applies anything.

Then run it once by hand from the Actions tab rather than waiting for the cron.

## Exit codes

`-detailed-exitcode` is doing the real work:

| code | meaning | what the workflow does |
|---|---|---|
| 0 | no drift | job passes, silent |
| 1 | terraform errored | **job fails** — an error must never be reported as "no drift" |
| 2 | drift found | opens the PR, then fails the job |

Conflating 1 and 2 is the most common way this kind of check goes quietly dead.


## Is it actually tested?

Yes, on every push, with no cloud credentials.

`.github/workflows/selftest.yml` builds real Terraform state using the `local`
provider, then edits the managed file **behind Terraform's back** -- the same
mechanism as somebody editing an NSG in the Azure portal, minus the subscription.
It then asserts all three things that matter:

| assertion | why it's there |
|---|---|
| clean state returns exit code **0** | a detector that always cries drift is useless |
| drifted state returns exit code **2** | the actual detection |
| the rendered plan **names the drifted rule** | proves the PR body would be readable, not empty |

If that badge is red, this repo is broken. That is the point of it.


### What the PR body can show

Terraform renders whatever the provider exposes. That varies, and it is worth knowing
before you rely on the diff:

| resource | what the PR body shows |
|---|---|
| `azurerm_network_security_group` | every attribute, including the rule name and port |
| `aws_security_group` | every attribute |
| `local_file` (used by the selftest) | content **hashes** only, never the content |

So for the resources this is actually aimed at, the diff names the change. For
hash-backed resources it can only tell you *that* something changed. The selftest
asserts the weaker, honest version, because asserting the stronger one against
`local_file` would have been a test that passes by lying.

## Help wanted

Four things I would like a hand with, and one thing I will not merge, are written
out in [CONTRIBUTING.md](CONTRIBUTING.md). The short version: a GCP job, an ignore
list for drift that is expected, and anyone willing to tell me the exit-code
handling is wrong.

## Prior art

The pull-request-as-control idea comes from two people whose public work I read:
[Patrick Koch](https://www.linkedin.com/in/patrick-koch-azure/)'s Azure landing-zone
material, and Ewuji Oluwaseyi John's Terraform Azure FinOps pull-request guardrail.
I pointed the same idea at drift.

## Licence

MIT. Use it, fork it, tell me what's wrong with it.
