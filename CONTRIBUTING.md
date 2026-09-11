# Contributing

The selftest is the contract. If `.github/workflows/selftest.yml` passes on your
branch, your change is reviewable. It needs no cloud credentials and no account
with anybody, so you can run the whole thing on a laptop:

```bash
cd examples/selftest
terraform init
terraform apply -auto-approve
sed -i 's/allow-443/allow-8080/' main.tf
terraform plan -refresh-only -detailed-exitcode   # expect exit 2
```

Exit 2 means drift was detected. Exit 0 means the detector missed it, which is the
only failure mode this project really has.

## Things I would genuinely like help with

These are real gaps, not busywork invented to look welcoming.

**A GCP job.** The matrix has Azure and AWS because those are the two I run. The
workflow's shape is provider-agnostic; someone who actually uses `google` provider
day to day would write a better job than I would guess at.

**Drift that is expected.** Some resources drift by design: autoscaler counts, tags
written by a policy engine, anything a controller owns. Right now every diff opens a
PR. An ignore list, keyed by resource address and attribute, would stop the noise
that eventually gets a bot muted.

**A second opinion on the exit codes.** `terraform plan -refresh-only
-detailed-exitcode` returns 0, 1 or 2, and the workflow treats 1 as a hard failure.
There are provider errors that arguably should be reported as drift rather than as a
broken run. I have not thought this through properly.

**Telling me the PR body is wrong.** The table in the README describes what the diff
can show for three resource types. I tested three. If a provider you use renders
something different, open an issue with the actual output and I will fix the table.

## What I will not merge

Anything that makes the tool fix drift automatically. That is a deliberate design
decision, explained in the README: the whole value is that a human reads the diff
and decides whether the code or the console was right. A tool that silently reverts
a change someone made at 3am during an incident is worse than no tool.

## Style

No linter, no CLA, no template to fill in. Small commits with a message that says
why. If the change touches behaviour, the selftest should show it.

Questions are fine as issues. So is "this is wrong and here is why".
