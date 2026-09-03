<script setup>
import { ref, computed } from 'vue'
import { usePage, router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Button from '@/Components/UI/Button.vue'
import Input from '@/Components/UI/Input.vue'
import Select from '@/Components/UI/Select.vue'
import Table from '@/Components/UI/Table.vue'
import Badge from '@/Components/UI/Badge.vue'
import Modal from '@/Components/UI/Modal.vue'
import {
  MagnifyingGlassIcon, ArrowPathIcon, PlusIcon,
  TrashIcon, EyeIcon, PauseIcon, XMarkIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  parkedTransactions: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
})

const search = ref('')
const showDetail = ref(false)
const selectedPark = ref(null)

const columns = [
  { key: 'invoice_number', label: 'No. Invoice', width: 160 },
  { key: 'customer.name', label: 'Pelanggan', width: 140 },
  { key: 'user.name', label: 'Kasir', width: 120 },
  { key: 'items_count', label: 'Item', width: 60, align: 'center', render: (row) => row.items?.length || 0 },
  { key: 'total', label: 'Total', width: 120, align: 'right', render: (row) => 'Rp ' + Number(row.total).toLocaleString('id-ID') },
  { key: 'created_at', label: 'Waktu', width: 160, render: (row) => new Date(row.created_at).toLocaleString('id-ID') },
]

const actions = [
  { label: 'Lihat', icon: EyeIcon, variant: 'ghost', onClick: (row) => viewDetail(row) },
  { label: 'Lanjutkan', icon: ArrowPathIcon, variant: 'primary', onClick: (row) => restoreParked(row) },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (row) => confirmDelete(row) },
]

function viewDetail(park) {
  selectedPark.value = park
  showDetail.value = true
}

function restoreParked(park) {
  router.post(`/api/v1/parked-transactions/${park.id}/restore`, {}, {
    onSuccess: (resp) => {
      window.location.href = '/pos?restored=' + encodeURIComponent(JSON.stringify(resp.items))
    },
    onError: (err) => error(err),
  })
}

function confirmDelete(park) {
  if (confirm(`Hapus transaksi tertunda ${park.invoice_number}?`)) {
    router.delete(`/api/v1/parked-transactions/${park.id}`, {
      onSuccess: () => { success('Dihapus'); router.reload() },
      onError: (err) => error(err),
    })
  }
}

const filteredData = computed(() =>
  props.parkedTransactions.data.filter(p => {
    if (search.value && !p.invoice_number.toLowerCase().includes(search.value.toLowerCase()) &&
        !p.customer?.name?.toLowerCase().includes(search.value.toLowerCase())) return false
    return true
  })
)
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Transaksi Tertunda (Held Sales)</h1>
          <p class="text-sm text-muted-foreground">{{ props.parkedTransactions.total }} transaksi</p>
        </div>
      </div>
    </template>

    <Card>
      <div class="flex gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            v-model="search"
            type="text"
            placeholder="Cari invoice, pelanggan..."
            class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>
      </div>

      <Table
        :columns="columns"
        :data="filteredData"
        :actions="actions"
        :loading="false"
        :pagination="{
          page: props.parkedTransactions.current_page,
          perPage: props.parkedTransactions.per_page,
          total: props.parkedTransactions.total,
          onChange: (p) => router.visit('/parked-transactions', { page: p, search: search.value }, { replace: true })
        }"
        emptyMessage="Tidak ada transaksi tertunda"
      />
    </Card>

    <!-- Detail Modal -->
    <Modal v-model="showDetail" :title="'Detail: ' + selectedPark?.invoice_number" size="lg">
      <div v-if="selectedPark" class="space-y-6">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <p class="text-sm text-muted-foreground">Invoice</p>
            <p class="font-mono text-lg font-bold">{{ selectedPark.invoice_number }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Tanggal</p>
            <p>{{ new Date(selectedPark.created_at).toLocaleString('id-ID') }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Pelanggan</p>
            <p>{{ selectedPark.customer?.name || 'Pelanggan Umum' }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Kasir</p>
            <p>{{ selectedPark.user?.name }}</p>
          </div>
        </div>

        <div class="border-t border-border pt-4">
          <h4 class="font-semibold mb-3">Items</h4>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead class="bg-muted"><tr><th class="px-4 py-2 text-left">Produk</th><th class="px-4 py-2 text-center">Qty</th><th class="px-4 py-2 text-right">Harga</th><th class="px-4 py-2 text-right">Diskon</th><th class="px-4 py-2 text-right">Subtotal</th></tr></thead>
              <tbody class="divide-y divide-gray-100">
                <tr v-for="(item, i) in selectedPark.items" :key="i">
                  <td class="px-4 py-2">{{ item.name }}</td>
                  <td class="px-4 py-2 text-center">{{ item.qty }}</td>
                  <td class="px-4 py-2 text-right">Rp {{ Number(item.price).toLocaleString('id-ID') }}</td>
                  <td class="px-4 py-2 text-right">Rp {{ Number(item.discount || 0).toLocaleString('id-ID') }}</td>
                  <td class="px-4 py-2 text-right font-medium">Rp {{ Number(item.qty * item.price - (item.discount || 0)).toLocaleString('id-ID') }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="grid grid-cols-4 gap-4 text-right">
          <div class="col-span-2"></div>
          <div>
            <p class="text-sm text-muted-foreground">Subtotal</p>
            <p>Rp {{ Number(selectedPark.subtotal).toLocaleString('id-ID') }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Diskon</p>
            <p class="text-red-600">- Rp {{ Number(selectedPark.discount).toLocaleString('id-ID') }}</p>
          </div>
          <div>
            <p class="text-sm text-muted-foreground">PPN</p>
            <p>Rp {{ Number(selectedPark.tax_amount).toLocaleString('id-ID') }}</p>
          </div>
          <div class="col-span-2"></div>
          <div class="col-span-2 font-bold text-lg">
            <p class="text-sm text-muted-foreground">Total</p>
            <p class="text-indigo-600">Rp {{ Number(selectedPark.total).toLocaleString('id-ID') }}</p>
          </div>
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>