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
  PlusIcon, MagnifyingGlassIcon, PencilIcon, TrashIcon,
  EyeIcon, CubeIcon, ArrowDownTrayIcon, ArrowUpTrayIcon,
  XMarkIcon, CheckIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  products: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  categories: { type: Array, default: () => [] },
  units: { type: Array, default: () => [] },
  taxes: { type: Array, default: () => [] },
  suppliers: { type: Array, default: () => [] },
  filters: { type: Object, default: () => ({}) },
})

// State - init from server-side filters
const search = ref(props.filters?.search || '')
const categoryFilter = ref(props.filters?.category_id || '')
const typeFilter = ref(props.filters?.type || '')
const showModal = ref(false)
const editingProduct = ref(null)
const loading = ref(false)

const form = ref({
  name: '',
  sku: '',
  barcode: '',
  category_id: '',
  unit_quantity_id: '',
  tax_id: '',
  supplier_id: '',
  type: 'finished_goods',
  cost_price: 0,
  selling_price: 0,
  stock: 0,
  min_stock: 5,
  description: '',
  is_active: true,
})

const columns = computed(() => [
  { key: 'sku', label: 'SKU', width: 110 },
  { key: 'name', label: 'Nama Produk', render: (row) => `<strong>${row.name}</strong>${Number(row.stock) <= Number(row.min_stock) ? '<span class="ml-1 bg-destructive/10 text-destructive text-xs px-1 rounded">Low</span>' : ''}` },
  { key: 'category', label: 'Kategori', width: 120, render: (row) => row.category?.name || row.category_text || '-' },
  { key: 'unit', label: 'Satuan', width: 80, align: 'center', render: (row) => row.unit_quantity?.symbol || row.unit_id || '-' },
  { key: 'selling_price', label: 'Harga Jual', width: 120, align: 'right', render: (row) => 'Rp ' + Number(row.selling_price || row.price || 0).toLocaleString('id-ID') },
  { key: 'cost_price', label: 'Harga Beli', width: 120, align: 'right', render: (row) => 'Rp ' + Number(row.cost_price || row.cost || 0).toLocaleString('id-ID') },
  { key: 'stock', label: 'Stok', width: 90, align: 'center', render: (row) => `<span class="${Number(row.stock) <= Number(row.min_stock) ? 'text-destructive font-bold' : ''}">${Number(row.stock).toLocaleString('id-ID')}</span>` },
  { key: 'is_active', label: 'Status', width: 90, align: 'center', render: (row) => (row.is_active ?? row.active) ? '<span class="text-green-600">● Aktif</span>' : '<span class="text-muted-foreground">○ Nonaktif</span>' },
])

const actions = [
  { label: 'Lihat', icon: EyeIcon, variant: 'ghost', onClick: (row) => viewProduct(row) },
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (row) => editProduct(row) },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (row) => confirmDelete(row), show: (row) => row.stock === 0 },
]

function openCreate() {
  resetForm()
  editingProduct.value = null
  showModal.value = true
}

function editProduct(product) {
  editingProduct.value = product
  form.value = {
    name: product.name,
    sku: product.sku,
    barcode: product.barcode || '',
    category_id: product.category_id || '',
    unit_quantity_id: product.unit_quantity_id || '',
    tax_id: product.tax_id || '',
    supplier_id: product.supplier_id || '',
    type: product.type,
    cost_price: Number(product.cost_price || product.cost || 0),
    selling_price: Number(product.selling_price || product.price || 0),
    stock: Number(product.stock || 0),
    min_stock: Number(product.min_stock || 0),
    description: product.description || '',
    is_active: product.is_active ?? product.active ?? true,
  }
  showModal.value = true
}

function viewProduct(product) {
  router.visit(`/products/${product.id}`)
}

function resetForm() {
  form.value = {
    name: '',
    sku: '',
    barcode: '',
    category_id: '',
    unit_quantity_id: '',
    tax_id: '',
    supplier_id: '',
    type: 'finished_goods',
    cost_price: 0,
    selling_price: 0,
    stock: 0,
    min_stock: 5,
    description: '',
    is_active: true,
  }
}

async function submitForm() {
  loading.value = true
  try {
    if (editingProduct.value) {
      await router.put(`/api/v1/products/${editingProduct.value.id}`, form.value, {
        onSuccess: () => { showModal.value = false; success('Produk diperbarui'); router.reload() },
        onError: (err) => error(err),
        onFinish: () => loading.value = false,
      })
    } else {
      await router.post('/api/v1/products', form.value, {
        onSuccess: () => { showModal.value = false; success('Produk dibuat'); router.reload() },
        onError: (err) => error(err),
        onFinish: () => loading.value = false,
      })
    }
  } catch (e) { loading.value = false }
}

function confirmDelete(product) {
  if (confirm(`Hapus produk "${product.name}"?`)) {
    router.delete(`/api/v1/products/${product.id}`, {
      onSuccess: () => success('Produk dihapus'),
      onError: (err) => error(err),
    })
  }
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Manajemen Produk</h1>
          <p class="text-sm text-muted-foreground">{{ props.products.total }} produk</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Produk</Button>
      </div>
    </template>

    <Card>
      <div class="flex flex-col sm:flex-row gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            v-model="search"
            type="text"
            placeholder="Cari produk (nama/SKU/barcode)..."
            class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            @keydown.enter="router.get('/products', { search: search, category_id: categoryFilter, type: typeFilter })"
          />
        </div>
        <Select v-model="categoryFilter" :options="[{value:'',label:'Semua Kategori'},...props.categories.map(c=>({value:c.id,label:c.name}))]" placeholder="Kategori" class="w-48" />
        <Select v-model="typeFilter" :options="[{value:'',label:'Semua Tipe'},{value:'raw_material',label:'Bahan Baku'},{value:'finished_goods',label:'Jadi'},{value:'service',label:'Jasa'}]" placeholder="Tipe" class="w-40" />
        <Button variant="outline" @click="router.get('/products', { search: search, category_id: categoryFilter, type: typeFilter })">
          <MagnifyingGlassIcon class="w-4 h-4" /> Filter
        </Button>
      </div>

      <Table
        :columns="columns"
        :data="props.products.data"
        :actions="actions"
        :loading="loading"
        :pagination="{
          page: props.products.current_page,
          perPage: props.products.per_page,
          total: props.products.total,
          onChange: (p) => router.get('/products', { page: p, search: search, category_id: categoryFilter, type: typeFilter })
        }"
        emptyMessage="Belum ada produk"
      />
    </Card>

    <!-- Modal -->
    <Modal v-model="showModal" :title="editingProduct ? 'Edit Produk' : 'Tambah Produk'" size="lg" @confirm="submitForm" :loading="loading">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Input v-model="form.name" label="Nama Produk *" required placeholder="Nama produk" />
        <Input v-model="form.sku" label="SKU *" required placeholder="Kode unik (auto jika kosong)" />
        <Input v-model="form.barcode" label="Barcode" placeholder="Kode barcode (opsional)" />
        <Select v-model="form.category_id" :options="[{value:'',label:'Pilih Kategori'},...props.categories.map(c=>({value:c.id,label:c.name}))]" label="Kategori" />
        <Select v-model="form.unit_quantity_id" :options="[{value:'',label:'Pilih Satuan'},...props.units.map(u=>({value:u.id,label:u.name + ' (' + u.symbol + ')'}))]" label="Satuan" />
        <Select v-model="form.tax_id" :options="[{value:'',label:'Tanpa Pajak'},...props.taxes.map(t=>({value:t.id,label:t.name + ' (' + t.rate + '%)'}))]" label="Pajak" />
        <Select v-model="form.supplier_id" :options="[{value:'',label:'Pilih Supplier'},...props.suppliers.map(s=>({value:s.id,label:s.name}))]" label="Supplier" />
        <Select v-model="form.type" :options="[{value:'raw_material',label:'Bahan Baku'},{value:'finished_goods',label:'Barang Jadi'},{value:'service',label:'Jasa'}]" label="Tipe Produk" />
        <Input v-model.number="form.cost_price" type="number" step="0.01" min="0" label="Harga Beli (Rp) *" required />
        <Input v-model.number="form.selling_price" type="number" step="0.01" min="0" label="Harga Jual (Rp) *" required />
        <Input v-model.number="form.stock" type="number" min="0" label="Stok Awal" />
        <Input v-model.number="form.min_stock" type="number" min="0" label="Stok Minimum" />
        <div class="md:col-span-2">
          <Input v-model="form.description" type="textarea" label="Deskripsi" placeholder="Deskripsi produk" rows="3" />
        </div>
        <div class="md:col-span-2 flex items-center gap-2">
          <input type="checkbox" v-model="form.is_active" id="is_active" class="w-4 h-4 text-indigo-600 rounded" />
          <label for="is_active" class="text-sm text-gray-700">Aktif</label>
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>