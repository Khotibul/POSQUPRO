<script setup>
import { ref, computed, onMounted } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Badge from '@/Components/UI/Badge.vue'

const { success, error } = useToast()
defineProps({ customers: Array })

const cart = ref([])
const customerId = ref('')
const paymentMethod = ref('cash')
const discount = ref(0)
const discountType = ref('amount')
const notes = ref('')
const paidAmount = ref(0)

onMounted(() => {
  cart.value = JSON.parse(localStorage.getItem('pos_cart') || '[]')
  customerId.value = localStorage.getItem('pos_customer') || ''
  discount.value = Number(localStorage.getItem('pos_discount') || 0)
  discountType.value = localStorage.getItem('pos_discount_type') || 'amount'
  if (!cart.value.length) {
    // jika cart kosong, kembali ke POS
    router.visit('/pos')
  }
})

const subtotal = computed(() => cart.value.reduce((s,i)=> s + i.qty*i.price,0))
const discountValue = computed(() => discountType.value==='percent' ? subtotal.value*Number(discount.value)/100 : Number(discount.value))
const grandTotal = computed(() => Math.max(0, subtotal.value - discountValue.value))
const change = computed(() => Math.max(0, Number(paidAmount.value) - grandTotal.value))
const isPaidEnough = computed(() => Number(paidAmount.value) >= grandTotal.value)

async function processPayment() {
  if (!isPaidEnough.value) { error('Uang bayar kurang'); return }
  try {
    await router.post('/pos/checkout', {
      type:'sell', customer_id: customerId.value||null, discount: discountValue.value, tax_amount:0, notes: notes.value,
      items: cart.value.map(i=>({ product_id:i.id, quantity:i.qty, unit_price:i.price })),
      payment: { method: paymentMethod.value, amount: grandTotal.value },
    }, { onSuccess: () => {
      localStorage.removeItem('pos_cart'); localStorage.removeItem('pos_customer'); localStorage.removeItem('pos_discount');
      success('Transaksi berhasil!'); router.visit('/pos')
    }})
  } catch(e){ error('Gagal') }
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center gap-3">
        <button @click="router.visit('/pos')" class="px-3 py-1.5 border border-border rounded-md text-sm hover:bg-accent">← Kembali ke POS</button>
        <h1 class="text-xl font-bold">Checkout • Menu Page</h1>
        <Badge label="Hemat Memori" variant="success" />
      </div>
    </template>

    <div class="grid lg:grid-cols-2 gap-6 max-w-5xl mx-auto">
      <Card title="Ringkasan Keranjang">
        <div class="space-y-2 max-h-[50vh] overflow-y-auto">
          <div v-for="item in cart" :key="item.id" class="flex justify-between py-2 border-b border-border text-sm">
            <div><p class="font-medium">{{ item.name }}</p><p class="text-xs text-muted-foreground">{{ item.qty }} x Rp {{ Number(item.price).toLocaleString('id-ID') }}</p></div>
            <span class="font-medium">Rp {{ Number(item.qty*item.price).toLocaleString('id-ID') }}</span>
          </div>
        </div>
        <div class="mt-4 space-y-1 text-sm border-t border-border pt-3">
          <div class="flex justify-between"><span class="text-muted-foreground">Subtotal</span><span>Rp {{ Number(subtotal).toLocaleString('id-ID') }}</span></div>
          <div class="flex justify-between"><span class="text-muted-foreground">Diskon</span><span class="text-destructive">- Rp {{ Number(discountValue).toLocaleString('id-ID') }}</span></div>
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
              <option value="cash">Tunai</option><option value="card">Kartu</option><option value="qris">QRIS</option><option value="transfer">Transfer</option>
            </select>
          </div>
          <div>
            <label class="text-sm font-medium">Uang Bayar</label>
            <input type="number" v-model.number="paidAmount" :min="grandTotal" class="w-full mt-1 border border-input rounded-md px-3 py-2" placeholder="Masukkan uang bayar" />
            <p v-if="paidAmount" :class="['text-sm mt-1', isPaidEnough ? 'text-green-600' : 'text-destructive']">
              {{ isPaidEnough ? 'Kembalian: Rp ' + Number(change).toLocaleString('id-ID') : 'Kurang: Rp ' + Number(grandTotal - paidAmount).toLocaleString('id-ID') }}
            </p>
          </div>
          <div>
            <label class="text-sm font-medium">Catatan</label>
            <textarea v-model="notes" rows="2" class="w-full mt-1 border border-input rounded-md px-3 py-2" placeholder="Catatan (opsional)"></textarea>
          </div>
          <div class="flex gap-2 pt-2">
            <button @click="router.visit('/pos')" class="flex-1 py-2.5 border border-border rounded-lg hover:bg-accent">Batal</button>
            <button @click="processPayment" :disabled="!isPaidEnough" class="flex-1 py-2.5 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50">Proses Bayar</button>
          </div>
          <p class="text-xs text-center text-muted-foreground">Menu page • Tidak pakai popup JS • Stabil & ringan</p>
        </div>
      </Card>
    </div>
  </AppLayout>
</template>
