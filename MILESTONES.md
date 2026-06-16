# mini-7575-vault — Public Milestones

This file tracks public project milestones and acceptance criteria.
It intentionally avoids day-by-day scheduling details.

---

## Scope

`mini-7575-vault` is a reduced ERC-7575 implementation:

- multi-asset settlement via multiple vaults sharing one share token
- synchronous deposit/redeem as the core baseline
- one reduced investment-layer slice (Async or Yield)

Out of scope for this repo:

- full production KYC/permit stack
- complete ERC-7540/7887 state machines
- off-chain orchestration systems

---

## Current Sprint Goal

This week focuses on one target only:

- a runnable synchronous `deposit`/`redeem` flow
- boundary coverage for zero values, invalid receiver/owner, and preview consistency

Done when:

- `deposit` and `redeem` pass end-to-end tests
- edge-case tests for core reverts are passing
- `forge test` can run cleanly as the current baseline
- Progress: delegated redeem authorization added with 3 focused tests and local checks (`forge test` + Slither) passing.
- Progress: 6/18 decimal normalization for single-vault conversions implemented with dedicated round-trip and preview consistency tests.
- Progress: `SafeTokenTransfers` guards deposit/redeem against fee-on-transfer style balance drift.
- Progress: vault active flag, pause controls, and ERC-165 `supportsInterface` for IERC7575.

---

## Milestones

### Milestone A — Settlement Hardening

Focus:

- safe transfer checks against fee-on-transfer style accounting drift
- zero-amount and boundary reverts
- deterministic preview/execution consistency

Done when:

- `Vault` deposit/mint/withdraw/redeem paths are implemented
- safe transfer checks are wired into asset in/out flows
- edge-case tests pass for core boundary conditions

### Milestone B — ShareToken Core

Focus:

- vault register/unregister lifecycle
- cross-vault normalized asset aggregation
- deployment/register automation via factory

Done when:

- `unregisterVault` enforces zero-balance safety constraint
- `getTotalNormalizedAssets` is implemented and tested
- factory flow can deploy and register vaults reproducibly

### Milestone C — Investment Slice (Reduced)

Focus:

- implement one path only: Async or Yield

Done when:

- selected path runs end-to-end in tests
- at least three focused tests cover primary flow and one edge case

### Milestone D — Wrap-up and Reproducibility

Focus:

- testnet reproducibility docs
- optional upgrade demo
- final walkthrough quality

Done when:

- deployment steps are documented and reproducible
- optional upgrade demo is available (if included)
- architecture and design trade-offs are clearly documented

---

## Quality Targets

- 30+ Foundry tests including edge cases
- at least one fuzz test
- clear README architecture and usage instructions
- concise SECURITY notes for settlement-layer risks
