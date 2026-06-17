# Security Notes — Settlement Layer (Week 1 Baseline)

This document describes known risks, mitigations, and **out-of-scope** gaps for the current
single-vault `deposit` / `redeem` baseline. It is not a formal audit report.

For vulnerability PoCs and audit-style writeups, see the companion
[smart-contract-security-lab](https://github.com/huichain/smart-contract-security-lab).

---

## Scope

**In scope (implemented):**

- Synchronous `deposit` and `redeem` for one asset per `Vault` instance
- Fixed decimal scaling: asset decimals ≤ 18, shares normalized to 18 decimals
- `SafeTokenTransfers` on asset in/out
- Owner-controlled `pause` / `unpause` and `setVaultActive`
- Delegated redeem via `approveRedeemer` + allowance

**Out of scope (not implemented yet):**

- Shared `ShareToken` across multiple vaults (Milestone B)
- `mint` / `withdraw` ERC-4626-style paths
- `minDeposit` and deposit caps
- Exchange-rate / first-depositor inflation model (fixed 1:1 scaling per vault)
- KYC, permit, upgradeability, investment/async layers

---

## Threat Model

| Threat | Severity (baseline) | Mitigation / status |
|--------|---------------------|---------------------|
| Fee-on-transfer / deflationary tokens cause accounting drift | High if unmitigated | `SafeTokenTransfers` reverts on balance mismatch |
| Donation / direct transfer to vault skews `totalAssets` | Low (baseline) | Shares minted only via `deposit`; `totalAssets` reads live balance — no share inflation attack in fixed-scaling design, but donated assets are not claimable as extra shares |
| Rounding traps on 6-decimal assets | Medium | `convertToAssets` floors; redeeming dust shares (`< scalingFactor`) reverts `ZeroAssets` — documented, tested in `EdgeCases.t.sol` |
| Unauthorized redeem | High if unmitigated | Owner must be `msg.sender` or approved operator with sufficient allowance |
| Deposits while vault inactive | Medium | `deposit` reverts `VaultNotActive`; `redeem` still allowed when inactive (by design — users can exit) |
| Global freeze | Medium | Owner `pause()` blocks both deposit and redeem |
| Malicious asset (>18 decimals) | Low | Constructor reverts `UnsupportedAssetDecimals` |
| Centralization / owner abuse | Informational | Single `Ownable` owner can pause or deactivate deposits — expected for this portfolio baseline |

---

## Design Choices (Security-Relevant)

### Fixed scaling vs exchange rate

Shares are `assets * 10^(18 - assetDecimals)`. There is no dynamic exchange rate and no
first-depositor inflation guard — acceptable for a teaching baseline, **not** for production TVL.

### Inactive vs paused

- **Inactive:** blocks new deposits only; existing share holders can redeem.
- **Paused:** blocks both deposit and redeem until `unpause`.

Integrators should treat these as distinct operational modes.

### Share accounting

Shares are internal ledger balances (`shareBalance`), not an ERC-20 yet. Milestone B will
introduce a shared `ShareToken` — until then, cross-vault portability does not exist.

---

## Testing & Analysis

| Check | Status |
|-------|--------|
| Foundry tests | 41 passing (`Vault`, `EdgeCases`, `VaultControls`, `SafeTokenTransfers`) |
| Fuzz | 3 tests — preview/deposit and preview/redeem parity (256 runs each) |
| Line coverage (`src/`) | Vault ~95%, SafeTokenTransfers 100% (see README) |
| Slither | CI job in `.github/workflows/test.yml` |

Run locally:

```bash
forge test -vv
forge coverage --report summary
```

---

## Known Limitations / Follow-Ups (Week 2+)

1. **ShareToken + registry** — required before multi-asset ERC-7575 settlement is real.
2. **`minDeposit`** — not enforced; micro-deposits possible on 18-decimal assets.
3. **`mint` / `withdraw`** — not implemented; integrators must use deposit/redeem only.
4. **Rebasing / ERC-777** — not supported; use standard ERC-20 only.
5. **Owner key compromise** — no timelock or multisig in baseline.

---

## Reporting

This is a learning/portfolio project. For serious deployments, obtain an independent audit.
If you find an issue in this repo, open a GitHub issue with a minimal Foundry PoC.
