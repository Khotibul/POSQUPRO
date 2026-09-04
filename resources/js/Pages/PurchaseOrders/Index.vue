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
  MagnifyingGlassIcon, PlusIcon, ArrowPathIcon,
  EyeIcon, PencilIcon, TrashIcon, ArrowDownTrayIcon,
  ShoppingBagIcon, XMarkIcon, CheckIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  purchaseOrders: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  suppliers: { type: Array, default: () => [] },
  products: { type: Array, default: () => [] },
})

const search = ref('')
const statusFilter = ref('')
const showModal = ref(false)
const editingPO = ref(null)
const showReceiveModal = ref(false)
const receivingPO = ref(null)
const receiveItems = ref({})
const loading = false

const columns = [
  { key: 'po_number', label: 'No. PO', width: 140 },
  { key: 'supplier.name', label: 'Supplier', width: 140 },
  { key: 'status', label: 'Status', width: 100, align: 'center', render: (row) => {
    const colors = { draft: 'bg-gray-100 text-gray-700', ordered: 'bg-blue-100 text-blue-700', partial: 'bg-yellow-100 text-yellow-700', received: 'bg-green-100 text-green-700', cancelled: 'bg-red-100 text-red-700' }
    return `<span class="px-2 py-0.5 rounded text-xs ${colors[row.status] || 'bg-gray-100 text-gray-700'}">${row.status}</span>`
  }},
  { key: 'expected_date', label: 'Tgl Diharapkan', width: 120, render: (row) => row.expected_date ? new Date(row.expected_date).toLocaleDateString('id-ID') : '-' },
  { key: 'total', label: 'Total', width: 120, align: 'right', render: (row) => 'Rp ' + Number(row.total).toLocaleString('id-ID') },
  { key: 'created_at', label: 'Dibuat', width: 160, render: (row) => new Date(row.created_at).toLocaleString('id-ID') },
]

const actions = [
  { label: 'Detail', icon: EyeIcon, variant: 'ghost', onClick: (row) => viewDetail(row) },
  { label: 'Terima', icon: ArrowPathIcon, variant: 'primary', onClick: (row) => openReceive(row), show: (row) => ['ordered', 'partial'].includes(row.status) },
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (row) => editPO(row), show: (row) => row.status === 'draft' },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (row) => confirmDelete(row), show: (row) => row.status === 'draft' },
]

function openCreate() {
  editingPO.value = null
  resetForm()
  showModal.value = true
}

function editPO(po) {
  editingPO.value = po
  form.value = {
    supplier_id: po.supplier_id,
    expected_date: po.expected_date ? po.expected_date.split('T')[0] : '',
    notes: po.notes || '',
    items: po.items?.map(i => ({
      product_id: i.product_id,
      quantity: i.quantity,
      unit_cost: Number(i.unit_cost),
      discount: Number(i.discount || 0),
    })) || [],
  }
  showModal.value = true
}

function viewDetail(po) {
  router.visit(`/purchase-orders/${po.id}`)
}

function resetForm() {
  form.value = { supplier_id: '', expected_date: '', notes: '', items: [{ product_id: '', quantity: 1, unit_cost: 0, discount: 0 }] }
}

function addItem() { form.value.items.push({ product_id: '', quantity: 1, unit_cost: 0, discount: 0 }) }
function removeItem(i) { if (form.value.items.length > 1) form.value.items.splice(i, 1) }

const subtotal = computed(() => form.value.items.reduce((s, i) => s + i.quantity * i.unit_cost - (i.discount || 0), 0))
const total = computed(() => subtotal.value - (form.value.discount || 0) + (form.value.tax_amount || 0))

async function savePO() {
  if (!form.value.supplier_id) { error('Pilih supplier'); return }
  if (!form.value.items.some(i => i.product_id)) { error('Minimal 1 item'); return }
  try {
    if (editingPO.value) {
      await router.put(`/api/v1/purchase-orders/${editingPO.value.id}`, form.value, {
        onSuccess: () => { showModal.value = false; success('PO diperbarui'); router.reload() },
        onError: (err) => error(err),
      })
    } else {
      await router.post('/api/v1/purchase-orders', form.value, {
        onSuccess: () => { showModal.value = false; success('PO dibuat'); router.reload() },
        onError: (err) => error(err),
      })
    }
  } catch (e) {}
}

function openReceive(po) {
  receivingPO.value = po
  receiveItems.value = {}
  po.items?.forEach(item => {
    const remaining = item.quantity - item.received_quantity
    if (remaining > 0) receiveItems.value[item.id] = remaining
  })
  showReceiveModal.value = true
}

async function processReceive() {
  if (Object.keys(receiveItems.value).length === 0) { error('Tidak ada item untuk diterima'); return }
  const items = Object.entries(receiveItems.value).map(([id, qty]) => ({ purchase_order_item_id: Number(id), quantity: Number(qty) }))
  try {
    await router.post(`/api/v1/purchase-orders/${receivingPO.value.id}/receive`, { items }, {
      onSuccess: () => { showReceiveModal.value = false; success('Barang diterima'); router.reload() },
      onError: (err) => error(err),
    })
  } catch (e) {}
}

function confirmDelete(po) {
  if (confirm(`Hapus PO ${po.po_number}?`)) {
    router.delete(`/api/v1/purchase-orders/${po.id}`, {
      onSuccess: () => { success('Dihapus'); router.reload() },
      onError: (err) => error(err),
    })
  }
}

const form = ref({
  supplier_id: '',
  expected_date: '',
  notes: '',
  discount: 0,
  tax_amount: 0,
  items: [{ product_id: '', quantity: 1, unit_cost: 0, discount: 0 }],
})
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Purchase Order</h1>
          <p class="text-sm text-muted-foreground">{{ props.purchaseOrders.total }} PO</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Buat PO Baru</Button>
      </div>
    </template>

    <Card>
      <div class="flex flex-col sm:flex-row gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            v-model="search"
            type="text"
            placeholder="Cari PO number..."
            class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>
        <Select v-model="statusFilter" :options="[{value:'',label:'Semua'},{value:'draft',label:'Draft'},{value:'ordered',label:'Ordered'},{value:'partial',label:'Partial'},{value:'received',label:'Received'},{value:'cancelled',label:'Cancelled'}]" placeholder="Status" class="w-36" />
        <Button variant="outline" @click="router.visit('/purchase-orders', { search: search, status: statusFilter }, { replace: true })">
          <MagnifyingGlassIcon class="w-4 h-4" /> Filter
        </Button>
      </div>

      <Table
        :columns="columns"
        :data="props.purchaseOrders.data.filter(p => !search || p.po_number.toLowerCase().includes(search.toLowerCase()))"
        :actions="actions"
        :loading="loading"
        :pagination="{
          page: props.purchaseOrders.current_page,
          perPage: props.purchaseOrders.per_page,
          total: props.purchaseOrders.total,
          onChange: (p) => router.visit('/purchase-orders', { page: p, search: search, status: statusFilter }, { replace: true })
        }"
        emptyMessage="Belum ada PO"
      />
    </Card>

    <!-- Create/Edit PO Modal -->
    <Modal v-model="showModal" :title="editingPO ? 'Edit PO' : 'Buat Purchase Order Baru'" size="xl" @confirm="savePO">
      <div class="space-y-4">
        <Select v-model="form.supplier_id" :options="[{value:'',label:'Pilih Supplier'},...props.suppliers.map(s=>({value:s.id,label:s.name}))]" label="Supplier *" required />
        <input type="date" v-model="form.expected_date" class="w-full px-3 py-2 border border-border rounded-lg text-sm" placeholder="Tanggal Diharapkan" />
        <Input v-model="form.notes" type="textarea" label="Catatan" rows="2" />

        <div class="border-t border-border pt-4">
          <h4 class="font-semibold mb-3">Items</h4>
          <div v-for="(item, i) in form.items" :key="i" class="flex gap-2 mb-2">
            <Select v-model="item.product_id" :options="[{value:'',label:'Pilih Produk'},...props.products.map(p=>({value:p.id,label:p.name + ' (' + p.sku + ') - Cost: Rp ' + p.cost_price}))]" class="flex-1" required />
            <input v-model.number="item.quantity" type="number" min="1" placeholder="Qty" class="w-20 px-3 py-2 border border-border rounded-lg text-sm" />
            <input v-model.number="item.unit_cost" type="number" step="0.01" min="0" placeholder="Cost" class="w-28 px-3 py-2 border border-border rounded-lg text-sm" />
            <input v-model.number="item.discount" type="number" step="0.01" min="0" placeholder="Disc" class="w-20 px-3 py-2 border border-border rounded-lg text-sm" />
            <button @click="removeItem(i)" class="text-red-500 p-2"><XMarkIcon class="w-5 h-5" /></button>
          </div>
          <Button variant="outline" @click="addItem" size="sm"><PlusIcon class="w-4 h-4" /> Tambah Item</Button>
        </div>

        <div class="flex justify-end gap-2 border-t pt-4">
          <div class="mr-auto text-right">
            <p>Subtotal: Rp {{ Number(subtotal).toLocaleString('id-ID') }}</p>
            <p class="font-bold">Total: Rp {{ Number(total).toLocaleString('id-ID') }}</p>
          </div>
        </div>
      </div>
    </Modal>

    <!-- Receive Modal -->
    <Modal v-model="showReceiveModal" :title="'Terima Barang: ' + receivingPO?.po_number" size="lg" @confirm="processReceive">
      <div class="space-y-4 max-h-[50vh] overflow-y-auto">
        <div v-for="item in receivingPO?.items" :key="item.id">
          <div class="bg-muted rounded-lg p-3">
            <div class="flex items-center justify-between mb-2">
              <div>
                <p class="font-medium">{{ item.product?.name }}</p>
                <p class="text-xs text-muted-foreground">Dipesan: {{ item.quantity }} • Diterima: {{ item.received_quantity }} • Sisa: {{ item.quantity - item.received_quantity }}</p>
              </div>
            </div>
            <input
              v-model.number="receiveItems[item.id]"
              type="number"
              min="0"
              :max="item.quantity - item.received_quantity"
              placeholder="Jumlah terima"
              class="w-full px-3 py-2 border border-border rounded-lg text-sm"
            >
          </div>
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>