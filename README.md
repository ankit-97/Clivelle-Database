# Clivelle Database

SQL Server / Azure SQL schema and development seed data for the Clivelle storefront.

## Repository contents

- \`database/migrations/001_initial_schema.sql\` — initial relational schema.
- \`database/seeds/development_seed.sql\` — idempotent category and role seed data.
- \`docs/ER_DIAGRAM.md\` — high-level entity relationship overview.

## Requirements

- Microsoft SQL Server 2019+ or Azure SQL Database.
- A dedicated development database for local testing.
- A migration/deployment identity with permission to create tables, indexes and constraints.

## Local setup

1. Create an empty database, for example \`ClivelleDev\`.
2. Open the database in SQL Server Management Studio or Azure Data Studio.
3. Run \`database/migrations/001_initial_schema.sql\`.
4. Run \`database/seeds/development_seed.sql\`.
5. Verify the objects exist and the \`dbo.SchemaMigrations\` table records \`001_initial_schema\`.

Run the migration against a new development database first. The script guards object creation so it can be re-run after a partial setup, but this is not a substitute for a formal migration runner or tested rollback plan.

## Main entities

Users and authentication, addresses, categories/products/images, inventory and movements, carts, wishlists, orders and immutable order-item snapshots, payment transactions, coupons, reviews, newsletter subscribers, shipments, administrator roles, and audit logs.

## Backend integration

The Clivelle Node.js API should connect using a server-side connection string stored in the hosting provider's secret manager. Never place SQL credentials, payment secrets, OTP provider credentials, or signing keys in browser JavaScript, the mobile bundle, or a committed \`.env\` file.

The API must enforce ownership checks for customer records, use parameterized SQL queries, validate all input, and use database transactions for order placement, inventory reservation, and payment state changes.

## Authentication and privacy

- Store password hashes only; use a modern password-hashing algorithm such as Argon2id if password login is enabled.
- Store OTP hashes, expire OTPs quickly, limit attempts and resend frequency, and never log OTP values.
- Store refresh-token hashes rather than raw refresh tokens.
- Treat email and phone as independently verifiable identifiers.
- Keep customer PII out of application logs and audit details.
- Use least-privilege database credentials and TLS connections.
- Define retention, deletion, consent, privacy notice, and backup policies before launch.

## Important production decisions still required

1. Select and configure the OTP/email/SMS provider.
2. Select a payment gateway and implement server-side signature/webhook verification.
3. Select product image/object storage and CDN.
4. Define tax, shipping, cancellation, return and refund rules.
5. Decide inventory reservation expiry and order lifecycle rules.
6. Configure backups, monitoring, alerting, and disaster recovery.
7. Review privacy, consumer-protection, GST, and payment compliance requirements with qualified professionals.

This repository provides the database foundation only. It does not create a live API, authenticate customers, process payments, or deploy a production database by itself.
