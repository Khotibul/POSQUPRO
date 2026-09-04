<script setup>
import { ref, computed } from 'vue'
import { usePage, router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Button from '@/Components/UI/Button.vue'
import Input from '@/Components/UI/Input.vue'
import Select from '@/Components/UI/Select.vue'
import Modal from '@/Components/UI/Modal.vue'
import Table from '@/Components/UI/Table.vue'
import Badge from '@/Components/UI/Badge.vue'
import {
  MagnifyingGlassIcon, ArrowPathIcon,
  ArrowDownTrayIcon, ArrowUpTrayIcon, ExclamationTriangleIcon,
  ClipboardDocumentListIcon, PencilIcon, EyeIcon
} from '@heroicons/vue/24/outline'

const { success, error } = useToast()

const props = defineProps({
  products: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  histories: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
})

const search = ref('')
const filterType = ref('')
const loading = ref(false)
const showAdjustModal = ref(false)
const adjustingProduct = ref(null)
const adjustQty = ref(0)
const adjustType = ref('adjustment')
const adjustReason = ref('')

const adjustTypeOptions = [
  { value: 'in', label: 'Masuk (+)' },
  { value: 'out', label: 'Keluar (-)' },
  { value: 'adjustment', label: 'Koreksi (Set)' },
]

const filteredProducts = computed(() => {
  let data = props.products.data
  if (search.value) {
    const q = search.value.toLowerCase()
    data = data.filter(p => p.name.toLowerCase().includes(q) || p.sku?.toLowerCase().includes(q))
  }
  if (filterType.value === 'low') data = data.filter(p => p.stock <= p.min_stock && p.stock > 0)
  if (filterType.value === 'out') data = data.filter(p => p.stock === 0)
  return data
})

const lowStockProducts = computed(() =>
  props.products.data.filter(p => p.stock <= p.min_stock)
)

const totalStockValue = computed(() =>
  props.products.data.reduce((sum, p) => sum + p.stock * p.cost_price, 0)
)

const totalSellValue = computed(() =>
  props.products.data.reduce((sum, p) => sum + p.stock * p.selling_price, 0)
)

const columns = [
  { key: 'sku', label: 'SKU', width: 100 },
  { key: 'name', label: 'Nama Produk' },
  { key: 'category.name', label: 'Kategori', width: 120 },
  { key: 'unit_quantity.symbol', label: 'Satuan', width: 80, align: 'center' },
  { key: 'stock', label: 'Stok', width: 80, align: 'center', render: (row) => `<span class="${row.stock <= row.min_stock ? 'text-red-600 font-bold' : ''}">${row.stock}</span>` },
  { key: 'min_stock', label: 'Min', width: 60, align: 'center' },
  { key: 'cost_price', label: 'Harga Beli', width: 110, align: 'right', render: (row) => 'Rp ' + Number(row.cost_price).toLocaleString('id-ID') },
  { key: 'selling_price', label: 'Harga Jual', width: 110, align: 'right', render: (row) => 'Rp ' + Number(row.selling_price).toLocaleString('id-ID') },
  { key: 'stock_value', label: 'Nilai Stok', width: 120, align: 'right', render: (row) => 'Rp ' + Number(row.stock * row.cost_price).toLocaleString('id-ID') },
]

const actions = [
  { label: 'Lihat', icon: EyeIcon, variant: 'ghost', onClick: (row) => router.visit('/inventory/' + row.id) },
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (row) => router.visit('/products/' + row.id + '/edit') },
  { label: 'Adjust', icon: ArrowPathIcon, variant: 'ghost', onClick: (row) => openAdjust(row) },
]

function openAdjust(product) {
  adjustingProduct.value = product
  adjustQty.value = 0
  adjustType.value = 'adjustment'
  adjustReason.value = ''
  showAdjustModal.value = true
}

async function saveAdjustment() {
  if (!adjustQty.value) { error('Masukkan jumlah'); return }
  if (!adjustReason.value) { error('Masukkan alasan'); return }

  loading.value = true
  try {
    await router.post('/api/v1/inventory-histories', {
      product_id: adjustingProduct.value.id,
      type: adjustType.value,
      quantity: adjustQty.value,
      reason: adjustReason.value,
    }, {
      onSuccess: () => {
        showAdjustModal.value = false
        success('Stok diperbarui')
        router.reload()
      },
      onError: (err) => error(err),
      onFinish: () => { loading.value = false },
    })
  } catch (e) { loading.value = false }
}
</script>

<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold">Manajemen Inventory</h1>
          <p class="text-sm text-muted-foreground">{{ props.products.total }} produk • {{ lowStockProducts.length }} stok rendah</p>
        </div>
        <div class="flex gap-2">
          <Button variant="outline" @click="router.visit('/stock-counts')"><ClipboardDocumentListIcon class="w-4 h-4" /> Stock Opname</Button>
        </div>
      </div>
    </template>

    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center"><MagnifyingGlassIcon class="w-6 h-6 text-blue-600" /></div>
          <div><p class="text-sm text-muted-foreground">Total Produk</p><p class="text-2xl font-bold">{{ props.products.total }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-yellow-100 rounded-xl flex items-center justify-center"><ExclamationTriangleIcon class="w-6 h-6 text-yellow-600" /></div>
          <div><p class="text-sm text-muted-foreground">Stok Rendah</p><p class="text-2xl font-bold text-yellow-600">{{ lowStockProducts.length }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center"><ArrowDownTrayIcon class="w-6 h-6 text-green-600" /></div>
          <div><p class="text-sm text-muted-foreground">Nilai Stok (HPP)</p><p class="text-2xl font-bold">Rp {{ Number(totalStockValue).toLocaleString('id-ID') }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center"><ArrowUpTrayIcon class="w-6 h-6 text-indigo-600" /></div>
          <div><p class="text-sm text-muted-foreground">Nilai Stok (Jual)</p><p class="text-2xl font-bold">Rp {{ Number(totalSellValue).toLocaleString('id-ID') }}</p></div>
        </div>
      </Card>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <Card class="lg:col-span-2" title="Daftar Produk">
        <div class="flex gap-3 mb-4">
          <div class="flex-1 relative">
            <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
            <input v-model="search" type="text" placeholder="Cari produk..." class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
          </div>
          <Select v-model="filterType" :options="[{value:'',label:'Semua'},{value:'low',label:'Stok Rendah'},{value:'out',label:'Stok Habis'}]" class="w-40" />
        </div>
        <Table
          :columns="columns"
          :data="filteredProducts"
          :actions="actions"
          :loading="loading"
          :pagination="{
            page: props.products.current_page,
            perPage: props.products.per_page,
            total: props.products.total,
            onChange: (p) => router.visit('/inventory', { page: p }, { replace: true })
          }"
          emptyMessage="Belum ada produk"
        />
      </Card>

      <Card title="Stok Rendah">
        <div v-if="!lowStockProducts.length" class="text-center py-8 text-green-600">
          <ExclamationTriangleIcon class="w-12 h-12 mx-auto text-green-300 mb-2" />
          <p class="font-medium">Semua stok aman</p>
        </div>
        <div v-else class="space-y-3 max-h-[400px] overflow-y-auto">
          <div v-for="p in lowStockProducts" :key="p.id" class="bg-red-50 border border-red-100 rounded-lg p-3">
            <div class="flex items-center justify-between">
              <div class="flex-1 min-w-0">
                <p class="font-medium truncate">{{ p.name }}</p>
                <p class="text-xs text-muted-foreground">{{ p.sku }} • {{ p.category?.name }}</p>
              </div>
              <div class="flex items-center gap-2">
                <Badge variant="danger" :label="String(p.stock)" />
                <Badge variant="warning" :label="`Min: ${p.min_stock}`" />
              </div>
            </div>
            <div class="flex gap-2 mt-2">
              <Button size="sm" variant="outline" class="flex-1" @click="openAdjust(p)"><ArrowPathIcon class="w-3.5 h-3.5" /> Adjust</Button>
              <Button size="sm" @click="router.visit('/products/' + p.id + '/edit')"><PencilIcon class="w-3.5 h-3.5" /></Button>
            </div>
          </div>
        </div>
      </Card>
    </div>

    <Modal v-model="showAdjustModal" title="Adjust Stok" @confirm="saveAdjustment" :loading="loading">
      <div class="space-y-4">
        <div class="bg-muted rounded-lg p-4">
          <p class="font-medium">{{ adjustingProduct?.name }}</p>
          <p class="text-sm text-muted-foreground">{{ adjustingProduct?.sku }} • Stok saat ini: <strong>{{ adjustingProduct?.stock }}</strong></p>
        </div>
        <Select v-model="adjustType" :options="adjustTypeOptions" label="Jenis" />
        <Input v-model.number="adjustQty" type="number" min="1" label="Jumlah" required placeholder="Contoh: 10" />
        <Input v-model="adjustReason" label="Alasan *" required placeholder="Contoh: Koreksi fisik, return pembeli, rusak" />
      </div>
    </Modal>
  </AppLayout>
</template>
