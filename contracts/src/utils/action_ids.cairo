%lang starknet

// =====================================================================================
// File: contracts/src/utils/action_ids.cairo
// =====================================================================================

// ───────────────────────────────────────────────────────────────────────────────────────
// Each “action” that you want to track should have a unique felt value.  
// Example:
//   ACTION_TRANSFER = 1
//   ACTION_MINT     = 2
//   ACTION_BURN     = 3
//   ACTION_SELL     = 4
//   …etc.
// Increment by 1 for each new action so logs stay consistent.
// ───────────────────────────────────────────────────────────────────────────────────────

/// User transferred tokens (or called “transfer” on your token contract)
const ACTION_TRANSFER: felt = 1;

/// User minted new tokens (if your contract has a mint function)
const ACTION_MINT: felt = 2;

/// User burned tokens
const ACTION_BURN: felt = 3;

/// (Example) User made a sale on marketplace
const ACTION_SELL: felt = 4;

// … Add more ACTION_* lines as needed for each distinct operation you care about.
