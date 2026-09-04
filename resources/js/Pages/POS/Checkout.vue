<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { router, usePage } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Badge from '@/Components/UI/Badge.vue'

const page = usePage()
const { success, error } = useToast()
const props = defineProps({
  customers: { type: Array, default: () => [] },
  settings: { type: Object, default: () => ({}) },
  lastSale: { type: Object, default: null },
})

const cart = ref([])
const customerId = ref('')
const paymentMethod = ref('cash')
const discount = ref(0)
const discountType = ref('amount')
const notes = ref('')
const paidAmount = ref(0)
const processing = ref(false)
const paidInputRef = ref(null)
const showReceipt = ref(false)
const lastSale = ref(props.lastSale)

onMounted(() => {
  if (lastSale.value) {
    showReceipt.value = true
    if (props.settings.auto_print) {
      nextTick(() => setTimeout(() => printReceipt(), 500))
    }
    return
  }
  cart.value = JSON.parse(localStorage.getItem('pos_cart') || '[]')
  customerId.value = localStorage.getItem('pos_customer') || ''
  discount.value = Number(localStorage.getItem('pos_discount') || 0)
  discountType.value = localStorage.getItem('pos_discount_type') || 'amount'
  if (!cart.value.length) {
    router.visit('/pos')
    return
  }
  nextTick(() => paidInputRef.value?.focus())
})

const subtotal = computed(() => cart.value.reduce((s, i) => s + i.qty * i.price, 0))
const discountValue = computed(() => discountType.value === 'percent' ? subtotal.value * Number(discount.value) / 100 : Number(discount.value))
const grandTotal = computed(() => Math.max(0, subtotal.value - discountValue.value))
const change = computed(() => Math.max(0, Number(paidAmount.value) - grandTotal.value))
const isPaidEnough = computed(() => Number(paidAmount.value) >= grandTotal.value)

const quickAmounts = computed(() => {
  const total = grandTotal.value
  if (total <= 0) return []
  const amounts = [total]
  if (total % 1000 !== 0) amounts.push(Math.ceil(total / 1000) * 1000)
  amounts.push(Math.ceil(total / 10000) * 10000)
  amounts.push(Math.ceil(total / 50000) * 50000)
  amounts.push(Math.ceil(total / 100000) * 100000)
  return [...new Set(amounts)].filter(a => a >= total).slice(0, 5)
})

function setQuickAmount(amount) { paidAmount.value = amount }

const receiptWidth = computed(() => {
  const w = Number(props.settings.paper_width) || 80
  return Math.max(280, Math.min(800, w * (80 / 30)))
})

function formatRp(n) { return Number(n || 0).toLocaleString('id-ID') }

function formatDate(d) {
  if (!d) return '-'
  const dt = new Date(d)
  return dt.toLocaleDateString('id-ID', { day: '2-digit', month: '2-digit', year: 'numeric' }) + ' ' + dt.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
}

function paymentLabel(m) {
  const map = { cash: 'Tunai', card: 'Kartu', qris: 'QRIS', transfer: 'Transfer' }
  return map[m?.toLowerCase()] || m
}

function printReceipt() {
  const el = document.getElementById('receipt-content')
  if (!el) return
  const w = window.open('', '_blank', 'width=400,height=600')
  w.document.write(`
    <!DOCTYPE html>
    <html><head><title>Cetak Struk</title>
    <style>
      @page { margin: 0; }
      body { margin:0; padding:0; font-family: ${props.settings.font_family || 'monospace'}; font-size: ${props.settings.font_size || 7}px; line-height: ${Number(props.settings.spacing_line || 80) / 10}px; }
      .receipt { width: ${receiptWidth.value}px; padding: 8px; white-space: pre-wrap; word-break: break-word; }
      .center { text-align: center; }
      .bold { font-weight: bold; }
      .line { border-top: 1px dashed #000; margin: 4px 0; }
      table { width: 100%; border-collapse: collapse; }
      td { padding: 1px 0; }
      .right { text-align: right; }
    </style></head><body>
    <div class="receipt">${el.innerHTML}</div>
    </body></html>
  `)
  w.document.close()
  w.print()
  w.close()
}

async function processPayment() {
  if (processing.value) return
  if (!isPaidEnough.value) { error('Uang bayar kurang'); return }
  if (!cart.value.length) { error('Keranjang kosong'); return }

  processing.value = true
  localStorage.removeItem('pos_cart')
  localStorage.removeItem('pos_customer')
  localStorage.removeItem('pos_discount')
  localStorage.removeItem('pos_discount_type')

  try {
    await router.post('/pos/checkout', {
      type: 'sell',
      customer_id: customerId.value || null,
      discount: discountValue.value,
      tax_amount: 0,
      paid_amount: Number(paidAmount.value),
      notes: notes.value,
      items: cart.value.map(i => ({ product_id: i.id, quantity: i.qty, unit_price: i.price })),
      payment: { method: paymentMethod.value, amount: Number(paidAmount.value) },
    }, {
      preserveState: false,
      onFinish: () => { processing.value = false },
    })
  } catch (e) {
    error('Gagal memproses transaksi')
    processing.value = false
  }
}

function closeReceipt() {
  showReceipt.value = false
  lastSale.value = null
  router.visit('/pos')
}
</script>

<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center gap-3">
        <button @click="router.visit('/pos')" class="px-3 py-1.5 border border-border rounded-md text-sm hover:bg-accent">&larr; Kembali ke POS</button>
        <h1 class="text-xl font-bold">Checkout</h1>
        <Badge v-if="!lastSale" label="Menu Page" variant="success" />
        <Badge v-else label="Transaksi Selesai" variant="success" />
      </div>
    </template>

    <div v-if="page.props.errors?.items && !lastSale" class="max-w-5xl mx-auto mb-4">
      <div class="bg-destructive/10 border border-destructive/20 text-destructive rounded-lg px-4 py-3 text-sm">
        {{ page.props.errors.items }}
      </div>
    </div>

    <!-- ==================== PAYMENT FORM ==================== -->
    <div v-if="!lastSale" class="grid lg:grid-cols-2 gap-6 max-w-5xl mx-auto">
      <Card title="Ringkasan Keranjang">
        <div class="space-y-2 max-h-[50vh] overflow-y-auto">
          <div v-for="item in cart" :key="item.id" class="flex justify-between py-2 border-b border-border text-sm">
            <div class="min-w-0 flex-1">
              <p class="font-medium truncate">{{ item.name }}</p>
              <p class="text-xs text-muted-foreground">{{ item.qty }} x Rp {{ formatRp(item.price) }}</p>
            </div>
            <span class="font-medium ml-3 whitespace-nowrap">Rp {{ formatRp(item.qty * item.price) }}</span>
          </div>
        </div>
        <div class="mt-4 space-y-1 text-sm border-t border-border pt-3">
          <div class="flex justify-between"><span class="text-muted-foreground">Subtotal</span><span>Rp {{ formatRp(subtotal) }}</span></div>
          <div v-if="discountValue > 0" class="flex justify-between"><span class="text-muted-foreground">Diskon</span><span class="text-destructive">- Rp {{ formatRp(discountValue) }}</span></div>
          <div class="flex justify-between font-bold text-lg pt-2 border-t border-border"><span>Total</span><span class="text-primary">Rp {{ formatRp(grandTotal) }}</span></div>
        </div>
      </Card>

      <Card title="Pembayaran">
        <div class="space-y-4">
          <div>
            <label class="text-sm font-medium">Pelanggan</label>
            <select v-model="customerId" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background">
              <option value="">Pelanggan Umum</option>
              <option v-for="c in customers" :key="c.id" :value="String(c.id)">{{ c.name }}</option>
            </select>
          </div>
          <div>
            <label class="text-sm font-medium">Metode Bayar</label>
            <select v-model="paymentMethod" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background">
              <option value="cash">Tunai</option>
              <option value="card">Kartu</option>
              <option value="qris">QRIS</option>
              <option value="transfer">Transfer</option>
            </select>
          </div>
          <div>
            <label class="text-sm font-medium">Uang Bayar</label>
            <input ref="paidInputRef" type="number" v-model.number="paidAmount" :min="grandTotal"
              class="w-full mt-1 border border-input rounded-md px-3 py-2 text-lg font-medium" placeholder="Masukkan uang bayar" />
            <div v-if="paidAmount > 0" :class="['text-sm mt-1 font-medium', isPaidEnough ? 'text-green-600' : 'text-destructive']">
              {{ isPaidEnough ? 'Kembalian: Rp ' + formatRp(change) : 'Kurang: Rp ' + formatRp(grandTotal - paidAmount) }}
            </div>
          </div>
          <div v-if="quickAmounts.length > 1" class="flex flex-wrap gap-2">
            <button v-for="amt in quickAmounts" :key="amt" @click="setQuickAmount(amt)"
              :class="['px-3 py-1.5 text-xs rounded-lg border transition-colors', paidAmount === amt ? 'bg-primary text-primary-foreground border-primary' : 'border-border hover:bg-accent']">
              {{ amt === grandTotal ? 'Pas' : 'Rp ' + formatRp(amt) }}
            </button>
          </div>
          <div>
            <label class="text-sm font-medium">Catatan</label>
            <textarea v-model="notes" rows="2" class="w-full mt-1 border border-input rounded-md px-3 py-2" placeholder="Catatan (opsional)"></textarea>
          </div>
          <div class="flex gap-2 pt-2">
            <button @click="router.visit('/pos')" :disabled="processing" class="flex-1 py-2.5 border border-border rounded-lg hover:bg-accent disabled:opacity-50">Batal</button>
            <button @click="processPayment" :disabled="!isPaidEnough || processing" class="flex-1 py-2.5 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 font-medium">
              {{ processing ? 'Memproses...' : 'Proses Bayar' }}
            </button>
          </div>
        </div>
      </Card>
    </div>

    <!-- ==================== RECEIPT MODAL ==================== -->
    <div v-if="showReceipt && lastSale" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" @click.self="closeReceipt">
      <div class="bg-card rounded-xl shadow-2xl max-h-[95vh] overflow-hidden flex flex-col w-full" :style="{ maxWidth: receiptWidth + 120 + 'px' }">
        <!-- Header -->
        <div class="flex items-center justify-between px-6 py-4 border-b border-border">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full bg-green-100 flex items-center justify-center">
              <svg class="w-6 h-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
            </div>
            <div>
              <h3 class="font-semibold">Transaksi Berhasil!</h3>
              <p class="text-xs text-muted-foreground">{{ lastSale.invoice_no }}</p>
            </div>
          </div>
          <button @click="closeReceipt" class="text-muted-foreground hover:text-foreground text-xl">&times;</button>
        </div>

        <!-- Receipt Content -->
        <div class="overflow-y-auto p-6 flex justify-center">
          <div id="receipt-content"
            :style="{ width: receiptWidth + 'px', fontFamily: settings.font_family || 'monospace', fontSize: settings.font_size + 'px', lineHeight: Number(settings.spacing_line || 80) / 10 + 'px' }"
            class="bg-white text-black p-4 border border-gray-300 shadow-inner text-left whitespace-pre-wrap break-words">

            <div class="center bold" style="font-size: 1.3em;">{{ settings.store_name || 'TOKO' }}</div>
            <div class="center">{{ settings.store_address }}</div>
            <div class="center">Telp: {{ settings.store_phone }}</div>
            <div class="center">{{ settings.receipt_header }}</div>
            <div class="line"></div>

            <table><tr><td>No</td><td>: {{ lastSale.invoice_no }}</td></tr>
            <tr><td>Kasir</td><td>: {{ lastSale.cashier }}</td></tr>
            <tr><td>Tanggal</td><td>: {{ formatDate(lastSale.created_at) }}</td></tr></table>

            <div class="line"></div>

            <table style="width:100%">
              <tr v-for="(item, idx) in lastSale.items" :key="idx">
                <td style="width:100%">
                  <span class="bold">{{ item.product_name }}</span><br/>
                  <span>{{ item.qty }} x Rp{{ formatRp(item.price) }}</span>
                </td>
                <td class="right bold" style="white-space:nowrap">Rp{{ formatRp(item.subtotal) }}</td>
              </tr>
            </table>

            <div class="line"></div>

            <table style="width:100%">
              <tr><td>Subtotal</td><td class="right">Rp{{ formatRp(lastSale.subtotal) }}</td></tr>
              <tr v-if="Number(lastSale.discount) > 0"><td>Diskon</td><td class="right">- Rp{{ formatRp(lastSale.discount) }}</td></tr>
              <tr v-if="Number(lastSale.tax) > 0"><td>Pajak</td><td class="right">+ Rp{{ formatRp(lastSale.tax) }}</td></tr>
              <tr><td class="bold" style="font-size:1.15em">TOTAL</td><td class="right bold" style="font-size:1.15em">Rp{{ formatRp(lastSale.total) }}</td></tr>
            </table>

            <div class="line"></div>

            <table style="width:100%">
              <tr><td>Bayar ({{ paymentLabel(lastSale.payment?.method) }})</td><td class="right">Rp{{ formatRp(lastSale.paid) }}</td></tr>
              <tr><td class="bold">Kembalian</td><td class="right bold">Rp{{ formatRp(lastSale.change_amount) }}</td></tr>
            </table>

            <div class="line"></div>
            <div class="center">{{ settings.receipt_footer }}</div>
            <div class="center bold">=== TERIMA KASIH ===</div>
          </div>
        </div>

        <!-- Actions -->
        <div class="px-6 py-4 border-t border-border flex gap-3">
          <button @click="closeReceipt" class="flex-1 py-2.5 border border-border rounded-lg hover:bg-accent text-sm font-medium">Tutup &amp; Kembali</button>
          <button @click="printReceipt" class="flex-1 py-2.5 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 text-sm font-medium flex items-center justify-center gap-2">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/></svg>
            Cetak Struk
          </button>
        </div>
      </div>
    </div>
  </AppLayout>
</template>
