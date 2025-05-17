# Optimizing Database Sync with Last Sync Time in Flutter (sqflite)

This guide describes how to optimize your database sync in a Flutter app by storing the last sync time for each table in a local SQLite table called `config`.

---

## 1. Create a `config` Table

In your local SQLite database (using `sqflite`), create a table:

- **key** (`TEXT PRIMARY KEY`)
- **value** (`TEXT`)

---

## 2. Update `DatabaseHelper` Class

- **Create the `config` table** in the `_createDB` method.
- **Add methods**:
  - `Future<String?> getConfigValue(String key)`
  - `Future<void> setConfigValue(String key, String value)`
- **Usage Example**:  
  Store and retrieve the last sync time for each table (e.g., `last_sync_all_products`, `last_sync_orders`, etc.).

---

## 3. Update Sync Logic (`SyncService`)

- **Read the last sync time** from the `config` table before fetching from Supabase.
- **Use** `.gte('updated_at', lastSyncTime)` **in the Supabase query**.
- **After syncing**, update the last sync time in the `config` table.

---

## 4. Robustness

- Ensure the solution handles the case where there is **no previous sync time** (e.g., use a default value or fetch all records).

---