# 0009: Checked native money and largest-remainder allocation

- Status: Accepted
- Date: 2026-10-24

OweLoop targets native Android/iOS. Non-negative transaction amounts range from
zero to PostgreSQL bigint's maximum, 9,223,372,036,854,775,807 minor units;
expenses and payer contributions must be positive. Parsing and intermediate
products/sums use Dart BigInt, with range checks before conversion to native int.
No wrapping, clamping, or floating-point conversion is permitted. Database
overflow rejects the transaction; a balance outside the supported signed range
fails closed. Browser financial arithmetic is not a supported release target.

Proportional splits use Hamilton's largest-remainder method: compute each exact
integer quotient, then award the remaining units by descending fractional
remainder. Ties use ascending durable group-member ID. Zero weights always get
zero. Returned rows are ordered by member ID independently of input order.
Existing persisted allocations remain immutable; the policy applies to new
previews and submissions. Equal shares retain the existing member-ID tie rule.
