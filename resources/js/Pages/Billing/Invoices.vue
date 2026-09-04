<script setup>
import { ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Table from '@/Components/UI/Table.vue'
import {
  MagnifyingGlassIcon, CurrencyDollarIcon,
  CheckCircleIcon, ClockIcon, ExclamationTriangleIcon
} from '@heroicons/vue/24/outline'

const { success, error } = useToast()

const props = defineProps({
  invoices: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  stats: { type: Object, default: () => ({}) },
})

const search = ref('')
const filterStatus = ref('')

const invoiceColor = { paid: 'bg-green-100 text-green-700', pending: 'bg-yellow-100 text-yellow-700', overdue: 'bg-red-100 text-red-700', draft: 'bg-gray-100 text-gray-700' }
const statusLabel = { paid: 'Lunas', pending: 'Belum Bayar', overdue: 'Jatuh Tempo', draft: 'Draft', cancelled: 'Dibatalkan' }
const fc = (v) => 'Rp ' + Number(v || 0).toLocaleString('id-ID')

function renderStatus(row) {
  const c = invoiceColor[row.status] || 'bg-gray-100 text-gray-700'
  return '<span class="px-2 py-0.5 rounded text-xs ' + c + '">' + (statusLabel[row.status] || row.status) + '</span>'
}

const columns = [
  { key: 'invoice_number', label: 'No. Invoice', width: 180 },
  { key: 'tenant.name', label: 'Tenant', width: 160 },
  { key: 'plan.name', label: 'Paket', width: 100 },
  { key: 'total', label: 'Total', width: 120, align: 'right', render: (row) => 'Rp ' + Number(row.total).toLocaleString('id-ID') },
  { key: 'status', label: 'Status', width: 110, align: 'center', render: renderStatus },
  { key: 'issued_at', label: 'Diterbitkan', width: 120, render: (row) => row.issued_at ? new Date(row.issued_at).toLocaleDateString('id-ID') : '-' },
  { key: 'due_at', label: 'Jatuh Tempo', width: 120, render: (row) => row.due_at ? new Date(row.due_at).toLocaleDateString('id-ID') : '-' },
]

function markPaid(invoice) {
  if (confirm('Tandai invoice ' + invoice.invoice_number + ' sebagai lunas?')) {
    router.post('/billing/invoices/' + invoice.id + '/pay', { payment_method: 'bank_transfer' }, {
      onSuccess: () => success('Invoice ditandai lunas'),
      onError: (err) => error(err),
    })
  }
}

function deleteInvoice(invoice) {
  if (confirm('Hapus invoice ' + invoice.invoice_number + '?')) {
    router.delete('/billing/invoices/' + invoice.id, {
      onSuccess: () => success('Invoice dihapus'),
      onError: (err) => error(err),
    })
  }
}
</script>

<template>
  <AppLayout>
    <template #header>
      <div>
        <h1 class="text-2xl font-bold">Invoice & Billing</h1>
        <p class="text-sm text-muted-foreground">Kelola invoice langganan tenant</p>
      </div>
    </template>

    <div class="grid grid-cols-2 sm:grid-cols-5 gap-4 mb-6">
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center"><CurrencyDollarIcon class="w-5 h-5 text-blue-600" /></div>
          <div><p class="text-xs text-muted-foreground">Total</p><p class="text-xl font-bold">{{ stats.total }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center"><CheckCircleIcon class="w-5 h-5 text-green-600" /></div>
          <div><p class="text-xs text-muted-foreground">Lunas</p><p class="text-xl font-bold text-green-600">{{ stats.paid }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-yellow-100 rounded-lg flex items-center justify-center"><ClockIcon class="w-5 h-5 text-yellow-600" /></div>
          <div><p class="text-xs text-muted-foreground">Pending</p><p class="text-xl font-bold text-yellow-600">{{ stats.pending }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-red-100 rounded-lg flex items-center justify-center"><ExclamationTriangleIcon class="w-5 h-5 text-red-600" /></div>
          <div><p class="text-xs text-muted-foreground">Overdue</p><p class="text-xl font-bold text-red-600">{{ stats.overdue }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-indigo-100 rounded-lg flex items-center justify-center"><CurrencyDollarIcon class="w-5 h-5 text-indigo-600" /></div>
          <div><p class="text-xs text-muted-foreground">Revenue</p><p class="text-xl font-bold text-indigo-600">{{ fc(stats.total_revenue) }}</p></div>
        </div>
      </Card>
    </div>

    <Card>
      <div class="flex flex-col sm:flex-row gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
          <input v-model="search" type="text" placeholder="Cari invoice..." class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
        </div>
        <select v-model="filterStatus" class="px-3 py-2 border border-border rounded-lg text-sm bg-background">
          <option value="">Semua Status</option>
          <option value="paid">Lunas</option>
          <option value="pending">Belum Bayar</option>
          <option value="overdue">Jatuh Tempo</option>
          <option value="draft">Draft</option>
        </select>
      </div>

      <Table
        :columns="columns"
        :actions="[
          { label: 'Tandai Lunas', icon: CheckCircleIcon, variant: 'ghost', onClick: (row) => markPaid(row), show: (row) => row.status === 'pending' || row.status === 'overdue' },
          { label: 'Hapus', icon: ExclamationTriangleIcon, variant: 'danger', onClick: (row) => deleteInvoice(row), show: (row) => row.status !== 'paid' },
        ]"
        :data="props.invoices.data.filter(function(i) { return !search || (i.invoice_number && i.invoice_number.toLowerCase().includes(search.toLowerCase())) || (i.tenant && i.tenant.name && i.tenant.name.toLowerCase().includes(search.toLowerCase())); }).filter(function(i) { return !filterStatus || i.status === filterStatus; })"
        emptyMessage="Belum ada invoice"
      />
    </Card>
  </AppLayout>
</template>
