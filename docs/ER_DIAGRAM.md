# Clivelle database relationship overview

\`\`\`mermaid
erDiagram
  Users ||--o{ Addresses : saves
  Users ||--o{ AuthSessions : signs_in
  Users ||--o{ OtpVerifications : verifies
  Users ||--o{ Carts : owns
  Carts ||--o{ CartItems : contains
  Categories ||--o{ Products : groups
  Products ||--o{ ProductImages : displays
  Products ||--|| Inventory : tracks
  Products ||--o{ InventoryMovements : records
  Users ||--o| Wishlists : owns
  Wishlists ||--o{ WishlistItems : contains
  Products ||--o{ WishlistItems : saved_as
  Users ||--o{ Orders : places
  Orders ||--|{ OrderItems : contains
  Products o|--o{ OrderItems : referenced_by
  Orders ||--o{ PaymentTransactions : paid_through
  Orders ||--o{ OrderCoupons : applies
  Coupons ||--o{ OrderCoupons : redeemed_on
  Users ||--o{ Reviews : writes
  Products ||--o{ Reviews : receives
  Orders ||--o{ Shipments : fulfilled_by
  Shipments ||--o{ ShipmentEvents : tracks
  Users ||--o{ AdminUserRoles : assigned
  AdminRoles ||--o{ AdminUserRoles : grants
  Users o|--o{ AuditLogs : performs
\`\`\`

## Design notes

- Orders retain a JSON address snapshot so later address edits do not change historical deliveries.
- Order items retain SKU, product name, image URL, unit price and quantity snapshots so catalogue edits do not rewrite purchase history.
- Payment provider references and idempotency keys are stored separately from order identifiers.
- Inventory movements provide an audit trail; stock changes should be made transactionally by the API.
- Customer/admin authorization is enforced by the API, not by hiding frontend controls.
- \`SchemaMigrations\` records applied schema versions.
