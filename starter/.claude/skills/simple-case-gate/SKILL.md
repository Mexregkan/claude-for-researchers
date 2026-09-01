---
name: simple-case-gate
description: Gate proposed research mechanisms, proof strategies, ansatzes, and universal identities on the simplest admissible nondegenerate case before testing harder cases; diagnose, repair, or stop when that case fails.
---

# Simple-case gate

Use this whenever proposing or evaluating a mathematical or physical mechanism,
proof architecture, ansatz, recursion, or claim intended to hold across a family.

## Non-negotiable rule

Identify the simplest admissible nondegenerate case and make the exact proposal work
there before increasing order, weight, depth, rank, spin, loop number, or the number of
free parameters. A genuine failure in that case forbids trying harder cases in the hope
that added complexity will repair a proposal that was claimed to work in every case.

## Gate

1. State the proposal and its domain precisely. If a simple case is excluded, derive the
   exclusion from the proposal rather than adding it after seeing a failure.
2. Choose the lowest-complexity case inside that domain. Verify that it is nondegenerate
   and that the test is sensitive to the proposed mechanism.
3. Test the complete proposal, with the same definitions, normalization, and conventions
   intended for the general case. Preserve the first exact residual or counterexample.
4. If it fails, stop escalation. Diagnose whether the cause is an implementation error,
   convention mismatch, degeneracy, false auxiliary assumption, or failure of the idea.
5. Either modify the proposal for a principled reason that explains the residual and
   retest the modified proposal on the same simple case, or abandon/narrow the claim.
6. Proceed to harder cases only after the simple gate passes. A modified proposal is a
   new proposal and must pass the gate again from the beginning.

## Forbidden responses to failure

- Moving directly to a higher order, weight, depth, rank, spin, or loop number.
- Adding parameters or correction terms available only in the harder case without first
  deriving why they must already resolve the simple residual.
- Calling the failed case “too simple” unless it is proved to lie outside the stated domain.
- Replacing the exact failed gate with a looser numerical, projected, or averaged test.

Report the gate case, why it is admissible and nondegenerate, the exact result, and what
the result licenses. A pass licenses the next case; it does not prove the general claim.
