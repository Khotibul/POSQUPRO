<script setup>
import { ref, onMounted } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Badge from '@/Components/UI/Badge.vue'

const { success, error } = useToast()
const props = defineProps({ parked: Array })

const cart = ref([])
const customerId = ref('')
const notes = ref('')

onMounted(() => {
  cart.value = JSON.parse(localStorage.getItem('pos_cart') || '[]')
  customerId.value = localStorage.getItem('pos_customer') || ''
})

async function savePark() {
  if (!cart.value.length) { error('Keranjang kosong'); return }
  try {
    await router.post('/pos/park', {
      customer_id: customerId.value||null,
      items: cart.value.map(i=>({ product_id:i.id, qty:i.qty, price:i.price, quantity:i.qty, unit_price:i.price })),
      notes: notes.value,
    }, { onSuccess: () => {
      localStorage.removeItem('pos_cart'); cart.value=[]; notes.value=''; success('Disimpan ke Park'); router.visit('/pos')
    }})
  } catch(e){ error('Gagal') }
}

function restorePark(p) {
  // ParkedTransaction items adalah array dengan product_id, qty, price
  const items = p.items.map(it => ({ id: it.product_id, name: it.product_name || 'Produk', sku: it.sku || '', price: Number(it.price), qty: Number(it.qty), maxQty: 999 }))
  localStorage.setItem('pos_cart', JSON.stringify(items))
  if(p.customer_id) localStorage.setItem('pos_customer', String(p.customer_id))
  success('Dipulihkan ke POS'); router.visit('/pos')
}

async function removePark(id) {
  if(!confirm('Hapus park ini?')) return
  router.delete(`/pos/park/${id}`, { onSuccess: ()=> success('Dihapus') })
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center gap-3">
        <button @click="router.visit('/pos')" class="px-3 py-1.5 border border-border rounded-md text-sm hover:bg-accent">← Kembali ke POS</button>
        <h1 class="text-xl font-bold">Parkir Transaksi • Menu Page</h1>
        <Badge :label="cart.length + ' item di cart'" variant="default" />
      </div>
    </template>

    <div class="grid lg:grid-cols-2 gap-6 max-w-5xl mx-auto">
      <Card title="Simpan Cart Saat Ini">
        <div v-if="!cart.length" class="text-center py-8 text-muted-foreground">Keranjang kosong</div>
        <div v-else class="space-y-3">
          <div v-for="item in cart" :key="item.id" class="flex justify-between text-sm py-1 border-b border-border">
            <span>{{ item.name }} ({{ item.qty }}x)</span><span>Rp {{ Number(item.qty*item.price).toLocaleString('id-ID') }}</span>
          </div>
          <textarea v-model="notes" placeholder="Catatan park (opsional)" rows="2" class="w-full border border-input rounded-md px-3 py-2"></textarea>
          <button @click="savePark" class="w-full py-2.5 bg-yellow-500 text-white rounded-lg hover:bg-yellow-600">Simpan Park (Hemat Memori)</button>
          <p class="text-xs text-center text-muted-foreground">Disimpan sebagai menu page, bukan popup JS</p>
        </div>
      </Card>

      <Card title="Daftar Parkir">
        <div v-if="!parked.length" class="text-center py-8 text-muted-foreground">Tidak ada parkir</div>
        <div v-else class="space-y-2 max-h-[60vh] overflow-y-auto">
          <div v-for="p in parked" :key="p.id" class="border border-border rounded-lg p-3">
            <div class="flex justify-between">
              <div><p class="font-medium text-sm">{{ p.invoice_no || p.invoice_number }}</p><p class="text-xs text-muted-foreground">{{ p.customer?.name || 'Umum' }} • {{ new Date(p.created_at).toLocaleString('id-ID') }}</p></div>
              <Badge :label="p.items?.length + ' item'" />
            </div>
            <div class="flex gap-2 mt-3">
              <button @click="restorePark(p)" class="flex-1 py-1.5 bg-primary text-primary-foreground rounded-md text-sm hover:bg-primary/90">Pulihkan ke POS</button>
              <button @click="removePark(p.id)" class="px-3 py-1.5 border border-border rounded-md text-sm hover:bg-accent text-destructive">Hapus</button>
            </div>
          </div>
        </div>
      </Card>
    </div>
  </AppLayout>
</template>
