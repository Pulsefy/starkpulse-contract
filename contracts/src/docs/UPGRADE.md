# Upgrade Process Documentation

This documentation outlines how to upgrade a Starknet contract using `replace_class_syscall`, ensuring the contract remains upgradable, storage-compatible, and consistent across versions.

---

## Steps to Upgrade the Contract

The `replace_class_syscall` function in Starknet allows you to replace the entire class (code and ABI) of a contract with a new class hash while retaining the same contract address and existing storage. This enables you to update the contract’s logic (e.g., add new features or fix bugs) without disrupting its deployed instance or losing stored data.

### Here’s how to perform an upgrade:

---


### Step 1: Develop the New Contract Version
- Write the new version of the contract with updates or new features.
- **Requirements:**
  - Retain existing storage variables (e.g., `admin`, `version`) in the same order and type.
  - Include the `upgrade` function to enable future upgrades.
  - Append any new storage variables (e.g., `new_value`) after the existing ones.
- **Example:**
  ```rust
  #[storage]
  struct Storage {
      admin: ContractAddress,
      version: u256,
      new_value: felt, // new variable
  }
---


### Step 2: Ensure Storage Compatibility
- `replace_class_syscall` preserves the existing storage.
- Do not change or reorder admin or version.
- New storage fields must be added at the end.


---


### Step 3: Compile the new contract

---


### Step 4: Declare the new clash hash on Starknet
- use the `upgrade` method
- Required inputs:
    - `new_class_hash`: The class hash from Step 4.
    - `new_version`: Greater than the current version.

---


### Step 5: Handle Initialization (If needed)
- Add a migrate function to initialize new fields if necessary:

```rust
fn migrate(ref self: ContractState) {
    self.new_value.write(0);
}
```

- The migrate function should be called when the new class hash has been upgraded

```rust
#[abi(embed_v0)]
fn upgrade(ref self: ContractState, new_class_hash: ClassHash, new_version: u256) {
     // Admin-only access control can be added here
     replace_class_syscall(new_class_hash);
     self.version.write(new_version);
 }
```
---

### Step 6: Verify the Upgrade
- Call `get_version()` to verify the version number is updated.
- Test new functionality like `set_value()` and `get_value()`.
- Confirm the `Upgraded` event was emitted (use a block explorer).

---