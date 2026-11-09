<script setup>
import { ref, computed, watch } from 'vue'
import { router, usePage } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Badge from '@/Components/UI/Badge.vue'
import {
  MagnifyingGlassIcon, ShoppingCartIcon, CubeIcon,
  PlusIcon, MinusIcon, TrashIcon, PauseIcon,
  CreditCardIcon, ArrowPathIcon, XMarkIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  products: { type: Object, required: true }, // paginated
  customers: { type: Array, default: () => [] },
  categories: { type: Array, default: () => [] },
  filters: { type: Object, default: () => ({}) },
  posSettings: { type: Object, default: () => ({}) },
})

// Gate edit harga ala Java: custom price ON, atau (admin AND auto update)
const isAdmin = computed(() => {
  const roles = page.props.auth?.user?.roles || []
  return roles.some(r => ['admin', 'owner', 'super admin', 'superadmin'].includes(String(r).toLowerCase()))
})
const canEditPrice = computed(() =>
  props.posSettings.custom_price_enabled === true ||
  (isAdmin.value && props.posSettings.auto_update_price !== false)
)

const search = ref(props.filters.search || '')
const selectedCategory = ref(props.filters.category || '')

// Cart disimpan di localStorage agar survive pindah page (checkout/park)
const cart = ref(JSON.parse(localStorage.getItem('pos_cart') || '[]'))
const customerId = ref(localStorage.getItem('pos_customer') || '')
const discount = ref(Number(localStorage.getItem('pos_discount') || 0))
const discountType = ref(localStorage.getItem('pos_discount_type') || 'amount')

watch(cart, (v) => localStorage.setItem('pos_cart', JSON.stringify(v)), { deep: true })
watch(customerId, (v) => localStorage.setItem('pos_customer', v))
watch(discount, (v) => localStorage.setItem('pos_discount', String(v)))
watch(discountType, (v) => localStorage.setItem('pos_discount_type', v))

const subtotal = computed(() => cart.value.reduce((s, i) => s + i.qty * i.price, 0))
const discountValue = computed(() => discountType.value === 'percent' ? subtotal.value * Number(discount.value) / 100 : Number(discount.value))
const grandTotal = computed(() => Math.max(0, subtotal.value - discountValue.value))

function onSearch() {
  router.get('/pos', { search: search.value, category: selectedCategory.value }, { preserveState: true, replace: true, preserveScroll: true })
}
watch(selectedCategory, () => onSearch())

function addToCart(p) {
  const stock = Number(p.stock)
  if (stock <= 0) { error('Stok habis'); return }
  const exist = cart.value.find(i => i.id === p.id)
  if (exist) {
    if (exist.qty >= stock) { error('Stok tidak cukup'); return }
    exist.qty++
  } else {
    const sellPrice = Number(p.selling_price || p.price)
    cart.value.push({
      id: p.id, name: p.name, sku: p.sku, price: sellPrice, qty: 1, maxQty: stock,
      basePrice: sellPrice,
      cost: Number(p.cost_price ?? p.cost ?? 0),
      wholesale: Number(p.wholesale_price ?? 0),
      minWholesale: Number(p.min_wholesale ?? 0),
    })
  }
}
function updateQty(item, d) {
  const n = item.qty + d
  if (n < 1) cart.value = cart.value.filter(i => i !== item)
  else if (n > item.maxQty) error('Maksimal ' + item.maxQty)
  else item.qty = n
}
function removeItem(item) { cart.value = cart.value.filter(i => i !== item) }
function clearCart() { if (cart.value.length && confirm('Kosongkan keranjang?')) { cart.value = []; customerId.value=''; discount.value=0 } }

// --- Edit harga + update harga produk master (paralel Java) ---
function isCustom(item) {
  return Number(item.price) !== Number(item.basePrice ?? item.price)
}

function onPriceChange(item) {
  let v = Number(item.price)
  if (isNaN(v) || v < 0) v = Number(item.basePrice ?? 0)
  item.price = v
  if (!canEditPrice.value) { item.price = Number(item.basePrice ?? v); return }
  if (v === 0 || v === Number(item.basePrice ?? v)) return // kembali ke harga normal → tidak perlu dialog
  if (isAdmin.value && props.posSettings.auto_update_price !== false) openUpdatePrice(item)
}

const showUpdatePrice = ref(false)
const upProduct = ref(null)
const upForm = ref({ updateCost: false, cost: 0, updateRetail: true, retail: 0, updateWholesale: false, wholesale: 0, minWholesale: 0 })

function openUpdatePrice(item) {
  upProduct.value = item
  upForm.value = {
    updateCost: false,
    cost: Number(item.cost) || 0,
    updateRetail: true,
    retail: Number(item.price),
    updateWholesale: false,
    wholesale: Number(item.wholesale) || 0,
    minWholesale: Number(item.minWholesale) || 0,
  }
  showUpdatePrice.value = true
}

async function confirmUpdatePrice() {
  const f = upForm.value
  if (!f.updateCost && !f.updateRetail && !f.updateWholesale) { error('Centang minimal satu harga untuk diupdate'); return }
  if (f.updateCost && !(Number(f.cost) > 0)) { error('Harga modal harus lebih dari 0'); return }
  if (f.updateRetail && !(Number(f.retail) > 0)) { error('Harga ecer harus lebih dari 0'); return }
  if (f.updateWholesale && !(Number(f.wholesale) > 0)) { error('Harga grosir harus lebih dari 0'); return }
  await router.put('/pos/product-price/' + upProduct.value.id, {
    update_cost: f.updateCost, cost_price: Number(f.cost),
    update_retail: f.updateRetail, selling_price: Number(f.retail),
    update_wholesale: f.updateWholesale, wholesale_price: Number(f.wholesale), min_wholesale: Number(f.minWholesale || 0),
  }, {
    preserveState: true,
    preserveScroll: true,
    onSuccess: () => {
      if (f.updateRetail) upProduct.value.basePrice = Number(f.retail)
      if (f.updateCost) upProduct.value.cost = Number(f.cost)
      if (f.updateWholesale) { upProduct.value.wholesale = Number(f.wholesale); upProduct.value.minWholesale = Number(f.minWholesale || 0) }
      showUpdatePrice.value = false
      success('Harga produk diupdate')
    },
    onError: (e) => error(e.update_retail || e.cost_price || e.selling_price || e.wholesale_price || 'Gagal update harga'),
  })
}

// --- Simpan keranjang langsung dari POS (paralel Java Ctrl+S) ---
function saveCart() {
  if (!cart.value.length) { error('Keranjang kosong'); return }
  const itemCount = cart.value.length
  const now = new Date()
  const hh = String(now.getHours()).padStart(2, '0')
  const mm = String(now.getMinutes()).padStart(2, '0')
  const def = `Keranjang ${now.getDate()}/${now.getMonth() + 1} ${hh}:${mm}`
  const label = window.prompt('Nama simpanan', def)
  if (label === null) return // batal
  router.post('/pos/park', {
    customer_id: customerId.value || null,
    items: cart.value.map(i => ({
      product_id: i.id, product_name: i.name, sku: i.sku,
      quantity: i.qty, unit_price: i.price, discount: 0,
    })),
    discount: Number(discountValue.value) || 0,
    tax_amount: 0,
    notes: label.trim() || def,
  }, {
    onSuccess: () => {
      cart.value = []; customerId.value = ''; discount.value = 0; discountType.value = 'amount'
      success(`Keranjang disimpan (${itemCount} item)`)
    },
    onError: (e) => error(e.items || 'Gagal menyimpan keranjang'),
  })
}

function goCheckout() {
  if (!cart.value.length) { error('Keranjang kosong'); return }
  router.visit('/pos/checkout')
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold text-foreground">POS / Kasir <span class="text-sm font-normal text-muted-foreground ml-2">Halaman Menu • Hemat Memori</span></h1>
        <div class="flex items-center gap-2">
          <a href="/pos/park" class="px-3 py-1.5 text-sm border border-border rounded-md hover:bg-accent">Tertunda</a>
          <Badge :variant="cart.length ? 'success' : 'default'" :label="cart.length + ' item'" />
        </div>
      </div>
    </template>

    <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
      <!-- Products - paginasi server (24 per page) -->
      <div class="lg:col-span-8">
        <Card>
          <div class="flex flex-col sm:flex-row gap-3 mb-4">
            <div class="flex-1 relative">
              <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
              <input v-model="search" @keydown.enter="onSearch" placeholder="Cari produk (nama/SKU/barcode) + Enter..." class="w-full pl-10 pr-4 py-2.5 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-ring" />
            </div>
            <select v-model="selectedCategory" class="px-3 py-2.5 bg-card border border-border rounded-lg text-sm">
              <option value="">Semua Kategori</option>
              <option v-for="c in categories" :key="c.id" :value="c.name">{{ c.name }}</option>
            </select>
            <button type="button" @click="onSearch" class="px-4 py-2.5 bg-primary text-primary-foreground rounded-lg text-sm hover:bg-primary/90">Cari</button>
          </div>

          <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3 max-h-[60vh] overflow-y-auto p-1">
            <div v-for="p in products.data" :key="p.id" @click="addToCart(p)" class="bg-card border border-border rounded-xl p-3 hover:border-primary hover:shadow-md cursor-pointer">
              <div class="w-full h-20 bg-muted rounded-lg flex items-center justify-center mb-2 overflow-hidden">
                <img v-if="p.image || p.photo" :src="p.image || p.photo" class="w-full h-full object-cover" />
                <CubeIcon v-else class="w-8 h-8 text-muted-foreground/30" />
              </div>
              <h4 class="font-medium text-sm line-clamp-2 leading-tight">{{ p.name }}</h4>
              <p class="text-xs text-muted-foreground">{{ p.sku }}</p>
              <p class="font-bold text-primary mt-1">Rp {{ Number(p.selling_price || p.price).toLocaleString('id-ID') }}</p>
              <div class="flex justify-between items-center mt-2 pt-2 border-t border-border">
                <span :class="['text-xs px-1.5 py-0.5 rounded', Number(p.stock) <= Number(p.min_stock) ? 'bg-destructive/10 text-destructive' : 'bg-green-100 text-green-600']">Stok {{ p.stock }}</span>
                <span class="text-xs text-muted-foreground truncate ml-2">{{ p.category?.name || p.category || '' }}</span>
              </div>
            </div>
          </div>

          <!-- Pagination pos-next-js shadcn -->
          <div v-if="products.links" class="flex items-center justify-between mt-4 pt-4 border-t border-border">
            <span class="text-sm text-muted-foreground">Menampilkan {{ products.from }}-{{ products.to }} dari {{ products.total }} (24/page)</span>
            <div class="flex gap-1">
              <button v-for="link in products.links" :key="link.label" @click="link.url && router.visit(link.url, { preserveScroll: true })" :disabled="!link.url" v-html="link.label" :class="['px-3 py-1.5 text-sm rounded-md border', link.active ? 'bg-primary text-primary-foreground border-primary' : 'bg-card border-border hover:bg-accent', !link.url ? 'opacity-50 cursor-not-allowed' : '']" />
            </div>
          </div>

          <div v-if="!products.data.length" class="text-center py-12 text-muted-foreground">
            <CubeIcon class="w-12 h-12 mx-auto text-muted-foreground/30 mb-2" />
            <p>Tidak ada produk</p>
          </div>
        </Card>
      </div>

      <!-- Cart -->
      <div class="lg:col-span-4">
        <Card class="sticky top-6">
          <div class="flex justify-between items-center mb-4">
            <h3 class="font-semibold">Keranjang</h3>
            <span class="text-sm text-muted-foreground">{{ cart.length }} item</span>
          </div>

          <div v-if="!cart.length" class="text-center py-10 border-2 border-dashed border-border rounded-xl">
            <ShoppingCartIcon class="w-12 h-12 mx-auto text-muted-foreground/30 mb-2" />
            <p class="text-sm text-muted-foreground">Keranjang kosong</p>
            <p class="text-xs text-muted-foreground">Klik produk untuk menambah</p>
          </div>

          <div v-else class="space-y-2 max-h-[28vh] overflow-y-auto pr-1">
            <div v-for="item in cart" :key="item.id" class="bg-muted rounded-lg p-3">
              <div class="flex justify-between gap-2">
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-medium truncate">{{ item.name }}</p>
                  <p class="text-xs text-muted-foreground flex items-center gap-1 flex-wrap">
                    <span class="truncate">{{ item.sku }}</span>
                    <span v-if="isCustom(item)" class="px-1 bg-blue-100 text-blue-700 rounded text-[10px] font-bold">CUSTOM</span>
                    <span v-if="canEditPrice" class="flex items-center gap-1 ml-auto">
                      <span>Rp</span>
                      <input type="number" v-model.number="item.price" @change="onPriceChange(item)" min="0" step="any" class="w-20 px-1 py-0.5 text-right border border-border rounded bg-background text-xs" />
                    </span>
                    <span v-else class="ml-auto">Rp {{ Number(item.price).toLocaleString('id-ID') }}</span>
                  </p>
                </div>
                <button @click="removeItem(item)" class="text-destructive hover:text-destructive/80 p-1"><TrashIcon class="w-4 h-4" /></button>
              </div>
              <div class="flex items-center gap-2 mt-2">
                <button @click="updateQty(item,-1)" class="w-8 h-8 border border-border rounded flex items-center justify-center hover:bg-card"><MinusIcon class="w-4 h-4" /></button>
                <input type="number" v-model.number="item.qty" :min="1" :max="item.maxQty" class="w-14 text-center border border-input rounded py-1 text-sm bg-background" />
                <button @click="updateQty(item,1)" class="w-8 h-8 border border-border rounded flex items-center justify-center hover:bg-card"><PlusIcon class="w-4 h-4" /></button>
                <span class="ml-auto font-medium text-sm">Rp {{ Number(item.qty*item.price).toLocaleString('id-ID') }}</span>
              </div>
            </div>
          </div>

          <div class="border-t border-border mt-4 pt-4 space-y-2 text-sm">
            <div class="flex justify-between"><span class="text-muted-foreground">Subtotal</span><span class="font-medium">Rp {{ Number(subtotal).toLocaleString('id-ID') }}</span></div>
            <div class="flex items-center gap-2">
              <span class="text-muted-foreground w-20">Diskon</span>
              <select v-model="discountType" class="w-16 border border-input rounded px-2 py-1.5 text-sm bg-background"><option value="amount">Rp</option><option value="percent">%</option></select>
              <input type="number" v-model.number="discount" :min="0" class="flex-1 border border-input rounded px-2 py-1.5 text-right bg-background" />
            </div>
            <div class="flex justify-between font-bold text-base border-t border-border pt-2"><span>Total</span><span class="text-primary">Rp {{ Number(grandTotal).toLocaleString('id-ID') }}</span></div>
          </div>

          <div class="space-y-3 mt-4">
            <select v-model="customerId" class="w-full border border-input rounded-lg px-3 py-2 text-sm bg-background">
              <option value="">Pelanggan Umum</option>
              <option v-for="c in customers" :key="c.id" :value="String(c.id)">{{ c.name }}</option>
            </select>
            <div class="grid grid-cols-2 gap-2">
              <button type="button" @click="saveCart" :disabled="!cart.length" class="py-2.5 bg-yellow-500 text-white rounded-lg text-sm hover:bg-yellow-600 disabled:opacity-50 flex items-center justify-center gap-1"><PauseIcon class="w-4 h-4" /> Simpan Keranjang</button>
              <button type="button" @click="clearCart" :disabled="!cart.length" class="py-2.5 bg-muted text-foreground border border-border rounded-lg text-sm hover:bg-accent disabled:opacity-50">Kosongkan</button>
            </div>
            <button type="button" @click="goCheckout" :disabled="!cart.length" class="w-full py-3 bg-primary text-primary-foreground rounded-lg font-medium hover:bg-primary/90 disabled:opacity-50 flex items-center justify-center gap-2"><CreditCardIcon class="w-5 h-5" /> Bayar & Checkout</button>
            <p class="text-xs text-center text-muted-foreground">Menu page • Hemat memori vs popup</p>
          </div>
        </Card>
      </div>
    </div>

    <!-- ==================== MODAL UPDATE HARGA (ala Java) ==================== -->
    <div v-if="showUpdatePrice" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" @click.self="showUpdatePrice = false">
      <div class="bg-card rounded-xl shadow-2xl w-full max-w-md p-6 max-h-[90vh] overflow-y-auto">
        <h3 class="font-semibold text-lg">Update Harga Produk</h3>
        <p class="text-sm text-muted-foreground mt-1">{{ upProduct?.name }} <span class="text-xs">({{ upProduct?.sku }})</span></p>
        <p class="text-xs text-muted-foreground mt-2">Harga di keranjang sudah jadi <strong class="text-primary">Rp {{ Number(upProduct?.price || 0).toLocaleString('id-ID') }}</strong>. Centang field yang ingin ditulis ke produk master:</p>

        <div class="space-y-3 mt-4">
          <div class="p-3 border border-border rounded-lg">
            <label class="flex items-center gap-2 font-medium text-sm cursor-pointer">
              <input type="checkbox" v-model="upForm.updateCost" class="rounded" />
              Harga Modal
              <span class="ml-auto px-1 bg-blue-100 text-blue-700 rounded text-[10px] font-bold">UPDATE</span>
            </label>
            <input v-if="upForm.updateCost" type="number" v-model.number="upForm.cost" min="0" step="any" placeholder="0" class="w-full mt-2 border border-input rounded px-3 py-2 text-sm bg-background" />
          </div>

          <div class="p-3 border border-border rounded-lg">
            <label class="flex items-center gap-2 font-medium text-sm cursor-pointer">
              <input type="checkbox" v-model="upForm.updateRetail" class="rounded" />
              Harga Ecer
              <span class="ml-auto px-1 bg-blue-100 text-blue-700 rounded text-[10px] font-bold">UPDATE</span>
            </label>
            <input v-if="upForm.updateRetail" type="number" v-model.number="upForm.retail" min="0" step="any" placeholder="0" class="w-full mt-2 border border-input rounded px-3 py-2 text-sm bg-background" />
          </div>

          <div class="p-3 border border-border rounded-lg">
            <label class="flex items-center gap-2 font-medium text-sm cursor-pointer">
              <input type="checkbox" v-model="upForm.updateWholesale" class="rounded" />
              Harga Grosir
              <span class="ml-auto px-1 bg-blue-100 text-blue-700 rounded text-[10px] font-bold">UPDATE</span>
            </label>
            <template v-if="upForm.updateWholesale">
              <input type="number" v-model.number="upForm.wholesale" min="0" step="any" placeholder="0" class="w-full mt-2 border border-input rounded px-3 py-2 text-sm bg-background" />
              <label class="text-xs text-muted-foreground mt-2 block">Min. Qty Grosir</label>
              <input type="number" v-model.number="upForm.minWholesale" min="0" class="w-full mt-1 border border-input rounded px-3 py-2 text-sm bg-background" />
            </template>
          </div>
        </div>

        <div class="flex justify-end gap-2 mt-6">
          <button @click="showUpdatePrice = false" class="px-4 py-2 border border-border rounded-lg text-sm hover:bg-accent">Batal</button>
          <button @click="confirmUpdatePrice" class="px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm hover:bg-primary/90">Update Harga</button>
        </div>
      </div>
    </div>
  </AppLayout>
</template>
