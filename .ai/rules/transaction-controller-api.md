---
paths:
  - 'app/Http/Controllers/{PosController,Api/TransactionController,Api/ParkedTransactionController}.php'
---

# Transaction Controller Api

## POS discount is line-level only; tx discount = 0 from mobile
SaleService/TransactionService/ParkedTransactionService compute total = Σ(qty*price − item.discount) − tx_discount. Mobile (pos_screen.dart) sends line discounts in items, so it must send transaction-level discount: 0 (it used to send cart.totalDiscount → double-counted). Web keeps a cart-level discount (resolved amount) with items at discount 0. When restoring a park on mobile, the tx discount is folded into the first line item.
