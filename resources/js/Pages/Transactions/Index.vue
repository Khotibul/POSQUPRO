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
  MagnifyingGlassIcon, ArrowPathIcon, EyeIcon,
  PencilIcon, TrashIcon, PrinterIcon, ArrowDownTrayIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  transactions: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  customers: { type: Array, default: () => [] },
})

const search = ref('')
const typeFilter = ref('')
const statusFilter = ref('')
const dateFrom = ref('')
const dateTo = ref('')
const showDetail = ref(false)
const selectedTx = ref(null)

const columns = [
  { key: 'invoice_number', label: 'No. Invoice', width: 160 },
  { key: 'type', label: 'Tipe', width: 80, render: (row) => `<span class="px-2 py-0.5 rounded text-xs ${row.type === 'sell' ? 'bg-green-100 text-green-700' : 'bg-blue-100 text-blue-700'}">${row.type === 'sell' ? 'Jual' : 'Beli'}</span>` },
  { key: 'customer.name', label: 'Pelanggan', width: 140 },
  { key: 'user.name', label: 'Kasir', width: 120 },
  { key: 'total', label: 'Total', width: 120, align: 'right', render: (row) => 'Rp ' + Number(row.total).toLocaleString('id-ID') },
  { key: 'status', label: 'Status', width: 100, align: 'center', render: (row) => {
    const colors = { completed: 'bg-green-100 text-green-700', pending: 'bg-yellow-100 text-yellow-700', cancelled: 'bg-red-100 text-red-700' }
    return `<span class="px-2 py-0.5 rounded text-xs ${colors[row.status] || 'bg-gray-100 text-gray-700'}">${row.status}</span>`
  }},
  { key: 'created_at', label: 'Waktu', width: 160, render: (row) => new Date(row.created_at).toLocaleString('id-ID') },
]

const actions = [
  { label: 'Detail', icon: EyeIcon, variant: 'ghost', onClick: (row) => viewDetail(row) },
  { label: 'Cetak', icon: PrinterIcon, variant: 'ghost', onClick: (row) => printReceipt(row), show: (row) => row.status === 'completed' },
  { label: 'Refund', icon: ArrowPathIcon, variant: 'ghost', onClick: (row) => openRefund(row), show: (row) => row.type === 'sell' && row.status === 'completed' },
  { label: 'Void', icon: TrashIcon, variant: 'danger', onClick: (row) => confirmVoid(row), show: (row) => row.status !== 'cancelled' },
]

function viewDetail(tx) {
  selectedTx.value = tx
  showDetail.value = true
}

function printReceipt(tx) {
  window.open(`/transactions/${tx.id}/print`, '_blank')
}

function openRefund(tx) {
  alert('Fitur refund: implementasi modal refund dengan pilih item & qty')
}

function confirmVoid(tx) {
  if (confirm(`Batalkan transaksi ${tx.invoice_number}? Stok akan dikembalikan.`)) {
    router.post(`/api/v1/transactions/${tx.id}/void`, {}, {
      onSuccess: () => { success('Transaksi dibatalkan'); router.reload() },
      onError: (err) => error(err),
    })
  }
}

const filteredData = computed(() =>
  props.transactions.data.filter(tx => {
    if (search.value && !tx.invoice_number.toLowerCase().includes(search.value.toLowerCase()) &&
        !tx.customer?.name?.toLowerCase().includes(search.value.toLowerCase())) return false
    if (typeFilter.value && tx.type !== typeFilter.value) return false
    if (statusFilter.value && tx.status !== statusFilter.value) return false
    if (dateFrom.value && new Date(tx.created_at) < new Date(dateFrom.value)) return false
    if (dateTo.value && new Date(tx.created_at) > new Date(dateTo.value)) return false
    return true
  })
)
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Transaksi</h1>
          <p class="text-sm text-muted-foreground">{{ props.transactions.total }} transaksi</p>
        </div>
        <div class="flex gap-2">
          <Button variant="outline" @click="router.visit('/transactions/create')"><PlusIcon class="w-4 h-4" /> Tambah</Button>
          <Button variant="outline" @click="exportCSV"><ArrowDownTrayIcon class="w-4 h-4" /> Export</Button>
        </div>
      </div>
    </template>

    <Card>
      <div class="flex flex-col sm:flex-row gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            v-model="search"
            type="text"
            placeholder="Cari invoice, pelanggan..."
            class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>
        <Select v-model="typeFilter" :options="[{value:'',label:'Semua'},{value:'sell',label:'Penjualan'},{value:'buy',label:'Pembelian'}]" placeholder="Tipe" class="w-36" />
        <Select v-model="statusFilter" :options="[{value:'',label:'Semua'},{value:'completed',label:'Selesai'},{value:'pending',label:'Pending'},{value:'cancelled',label:'Batal'}]" placeholder="Status" class="w-36" />
        <input type="date" v-model="dateFrom" class="px-3 py-2 border border-border rounded-lg text-sm" placeholder="Dari" />
        <input type="date" v-model="dateTo" class="px-3 py-2 border border-border rounded-lg text-sm" placeholder="Sampai" />
        <Button variant="outline" @click="router.visit('/transactions', { search: search.value, type: typeFilter.value, status: statusFilter.value, from: dateFrom.value, to: dateTo.value }, { replace: true })">
          <MagnifyingGlassIcon class="w-4 h-4" /> Filter
        </Button>
      </div>

      <Table
        :columns="columns"
        :data="filteredData"
        :actions="actions"
        :loading="false"
        emptyMessage="Tidak ada transaksi"
      />
    </Card>

    <!-- Detail Modal -->
    <Modal v-model="showDetail" :title="'Detail: ' + selectedTx?.invoice_number" size="xl">
      <div v-if="selectedTx" class="space-y-6">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <p class="text-sm text-muted-foreground">Invoice</p>
            <p class="font-mono text-lg font-bold">{{ selectedTx.invoice_number }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Tipe</p>
            <p><Badge :variant="selectedTx.type === 'sell' ? 'success' : 'info'" :label="selectedTx.type === 'sell' ? 'Penjualan' : 'Pembelian'" /></p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Status</p>
            <p><Badge :variant="selectedTx.status === 'completed' ? 'success' : selectedTx.status === 'pending' ? 'warning' : 'danger'" :label="selectedTx.status" /></p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Tanggal</p>
            <p>{{ new Date(selectedTx.created_at).toLocaleString('id-ID') }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Pelanggan</p>
            <p>{{ selectedTx.customer?.name || 'Pelanggan Umum' }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Kasir</p>
            <p>{{ selectedTx.user?.name }}</p>
          </div>
        </div>

        <div class="border-t border-border pt-4">
          <h4 class="font-semibold mb-3">Items</h4>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead class="bg-muted"><tr><th class="px-4 py-2 text-left">Produk</th><th class="px-4 py-2 text-center">Qty</th><th class="px-4 py-2 text-right">Harga</th><th class="px-4 py-2 text-right">Diskon</th><th class="px-4 py-2 text-right">Subtotal</th></tr></thead>
              <tbody class="divide-y divide-gray-100">
                <tr v-for="item in selectedTx.items" :key="item.id">
                  <td class="px-4 py-2">{{ item.product?.name }} <br><span class="text-xs text-muted-foreground">{{ item.product?.sku }}</span></td>
                  <td class="px-4 py-2 text-center">{{ item.quantity }}</td>
                  <td class="px-4 py-2 text-right">Rp {{ Number(item.unit_price).toLocaleString('id-ID') }}</td>
                  <td class="px-4 py-2 text-right">Rp {{ Number(item.discount).toLocaleString('id-ID') }}</td>
                  <td class="px-4 py-2 text-right font-medium">Rp {{ Number(item.subtotal).toLocaleString('id-ID') }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="grid grid-cols-4 gap-4 text-right">
          <div class="col-span-2"></div>
          <div>
            <p class="text-sm text-muted-foreground">Subtotal</p>
            <p>Rp {{ Number(selectedTx.subtotal).toLocaleString('id-ID') }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Diskon</p>
            <p class="text-red-600">- Rp {{ Number(selectedTx.discount).toLocaleString('id-ID') }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">PPN</p>
            <p>Rp {{ Number(selectedTx.tax_amount).toLocaleString('id-ID') }}</p>
          </div>
          <div class="col-span-2"></div>
          <div class="col-span-2 font-bold text-lg">
            <p class="text-sm text-muted-foreground">Total</p>
            <p class="text-indigo-600">Rp {{ Number(selectedTx.total).toLocaleString('id-ID') }}</p>
          </div>
        </div>

        <div v-if="selectedTx.payments && selectedTx.payments.length" class="border-t border-border pt-4">
          <h4 class="font-semibold mb-3">Pembayaran</h4>
          <div class="space-y-2">
            <div v-for="pay in selectedTx.payments" :key="pay.id" class="flex justify-between text-sm p-2 bg-muted rounded">
              <span class="capitalize">{{ pay.method }} {{ pay.status !== 'success' ? '(' + pay.status + ')' : '' }}</span>
              <span class="font-medium">Rp {{ Number(pay.amount).toLocaleString('id-ID') }}</span>
            </div>
          </div>
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>

<script>
import { MagnifyingGlassIcon, PlusIcon, ArrowDownTrayIcon } from '@heroicons/vue/24/outline'
export default { components: { MagnifyingGlassIcon, PlusIcon, ArrowDownTrayIcon } }
</script>