---
paths:
  - 'app/Repositories/*.php'
---

# Repositories

## Sync price/cost aliases on every product write
Products table has dual columns: price/cost (read by Java + C# desktop) and selling_price/cost_price (written by Laravel forms/API). ProductRepository::withPriceAliases() syncs both directions on create/update — never write one without the other. The POS "update harga" endpoint goes through the repository, not Product::update directly.
