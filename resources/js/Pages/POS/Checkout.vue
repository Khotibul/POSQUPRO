<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { router, usePage } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Badge from '@/Components/UI/Badge.vue'

const page = usePage()
const { success, error } = useToast()
const props = defineProps({ customers: Array })

const cart = ref([])
const customerId = ref('')
const paymentMethod = ref('cash')
const discount = ref(0)
const discountType = ref('amount')
const notes = ref('')
const paidAmount = ref(0)
const processing = ref(false)
const paidInputRef = ref(null)

onMounted(() => {
  cart.value = JSON.parse(localStorage.getItem('pos_cart') || '[]')
  customerId.value = localStorage.getItem('pos_customer') || ''
  discount.value = Number(localStorage.getItem('pos_discount') || 0)
  discountType.value = localStorage.getItem('pos_discount_type') || 'amount'
  if (!cart.value.length) {
    router.visit('/pos')
    return
  }
  nextTick(() => {
    paidInputRef.value?.focus()
  })
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
  if (total % 1000 !== 0) {
    amounts.push(Math.ceil(total / 1000) * 1000)
  }
  amounts.push(Math.ceil(total / 10000) * 10000)
  amounts.push(Math.ceil(total / 50000) * 50000)
  amounts.push(Math.ceil(total / 100000) * 100000)
  return [...new Set(amounts)].filter(a => a >= total).slice(0, 5)
})

function setQuickAmount(amount) {
  paidAmount.value = amount
}

async function processPayment() {
  if (processing.value) return
  if (!isPaidEnough.value) { error('Uang bayar kurang'); return }
  if (!cart.value.length) { error('Keranjang kosong'); return }

  processing.value = true
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
      onSuccess: () => {
        localStorage.removeItem('pos_cart')
        localStorage.removeItem('pos_customer')
        localStorage.removeItem('pos_discount')
        localStorage.removeItem('pos_discount_type')
        success('Transaksi berhasil!')
        router.visit('/pos')
      },
      onFinish: () => { processing.value = false },
    })
  } catch (e) {
    error('Gagal memproses transaksi')
    processing.value = false
  }
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center gap-3">
        <button @click="router.visit('/pos')" class="px-3 py-1.5 border border-border rounded-md text-sm hover:bg-accent">← Kembali ke POS</button>
        <h1 class="text-xl font-bold">Checkout</h1>
        <Badge label="Menu Page" variant="success" />
      </div>
    </template>

    <div v-if="page.props.errors?.items" class="max-w-5xl mx-auto mb-4">
      <div class="bg-destructive/10 border border-destructive/20 text-destructive rounded-lg px-4 py-3 text-sm">
        {{ page.props.errors.items }}
      </div>
    </div>

    <div class="grid lg:grid-cols-2 gap-6 max-w-5xl mx-auto">
      <Card title="Ringkasan Keranjang">
        <div class="space-y-2 max-h-[50vh] overflow-y-auto">
          <div v-for="item in cart" :key="item.id" class="flex justify-between py-2 border-b border-border text-sm">
            <div class="min-w-0 flex-1">
              <p class="font-medium truncate">{{ item.name }}</p>
              <p class="text-xs text-muted-foreground">{{ item.qty }} x Rp {{ Number(item.price).toLocaleString('id-ID') }}</p>
            </div>
            <span class="font-medium ml-3 whitespace-nowrap">Rp {{ Number(item.qty * item.price).toLocaleString('id-ID') }}</span>
          </div>
        </div>
        <div class="mt-4 space-y-1 text-sm border-t border-border pt-3">
          <div class="flex justify-between"><span class="text-muted-foreground">Subtotal</span><span>Rp {{ Number(subtotal).toLocaleString('id-ID') }}</span></div>
          <div v-if="discountValue > 0" class="flex justify-between"><span class="text-muted-foreground">Diskon</span><span class="text-destructive">- Rp {{ Number(discountValue).toLocaleString('id-ID') }}</span></div>
          <div class="flex justify-between font-bold text-lg pt-2 border-t border-border"><span>Total</span><span class="text-primary">Rp {{ Number(grandTotal).toLocaleString('id-ID') }}</span></div>
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
            <input
              ref="paidInputRef"
              type="number"
              v-model.number="paidAmount"
              :min="grandTotal"
              class="w-full mt-1 border border-input rounded-md px-3 py-2 text-lg font-medium"
              placeholder="Masukkan uang bayar"
            />
            <div v-if="paidAmount > 0" :class="['text-sm mt-1 font-medium', isPaidEnough ? 'text-green-600' : 'text-destructive']">
              {{ isPaidEnough ? 'Kembalian: Rp ' + Number(change).toLocaleString('id-ID') : 'Kurang: Rp ' + Number(grandTotal - paidAmount).toLocaleString('id-ID') }}
            </div>
          </div>
          <div v-if="quickAmounts.length > 1" class="flex flex-wrap gap-2">
            <button
              v-for="amt in quickAmounts"
              :key="amt"
              @click="setQuickAmount(amt)"
              :class="['px-3 py-1.5 text-xs rounded-lg border transition-colors', paidAmount === amt ? 'bg-primary text-primary-foreground border-primary' : 'border-border hover:bg-accent']"
            >
              {{ amt === grandTotal ? 'Pas' : 'Rp ' + Number(amt).toLocaleString('id-ID') }}
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
  </AppLayout>
</template>
