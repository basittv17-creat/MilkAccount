# Offline database foundation

## Delivered in phase 1
- SQLite database file: `milk_account.db`.
- Foreign-key enforcement, WAL journaling and a busy timeout.
- Versioned schema with a migration hook; future upgrades must preserve existing data.
- Accounts table with a stable UUID primary key and a separate sequential, unique account number.
- Milk entries store quantity in grams and money in integer paisa to avoid floating-point currency errors.
- Advances distinguish money given to a customer from money received from a customer.
- Foreign keys prevent orphan milk/advance records; deletion is restricted rather than silently cascading.
- Indexes support account-name search and account/date ledger queries.

## Important scope
This phase creates and tests the storage foundation only. It does not yet connect the database to screens or implement account creation, milk entry, balances, reports, backups, or cloud sync. The database is intended for the Android app first; Web persistence needs a separate browser-compatible SQLite adapter before the Web app uses this repository.

## Data rules
- Store timestamps as ISO-8601 strings.
- Store money as integer paisa.
- Store milk quantity as integer grams.
- Keep account UUIDs stable; account numbers are display identifiers and must not be used as foreign keys.
- Do not delete accounts with transaction history.
