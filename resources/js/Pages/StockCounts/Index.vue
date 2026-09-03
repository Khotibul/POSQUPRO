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
  ClipboardDocumentListIcon, CheckIcon, EyeIcon,
  PencilIcon, PlayIcon, PauseIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  stockCounts: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  products: { type: Array, default: () => [] },
})

const search = ref('')
const statusFilter = ref('')
const showModal = ref(false)
const showCountModal = ref(false)
const countingSC = ref(null)
const countInputs = ref({})
const loading = false

const columns = [
  { key: 'count_number', label: 'No. Count', width: 140 },
  { key: 'user.name', label: 'Petugas', width: 120 },
  { key: 'status', label: 'Status', width: 100, align: 'center', render: (row) => {
    const colors = { draft: 'bg-gray-100 text-gray-700', counting: 'bg-blue-100 text-blue-700', review: 'bg-yellow-100 text-yellow-700', approved: 'bg-green-100 text-green-700', posted: 'bg-purple-100 text-purple-700', cancelled: 'bg-red-100 text-red-700' }
    return `<span class="px-2 py-0.5 rounded text-xs ${colors[row.status] || 'bg-gray-100 text-gray-700'}">${row.status}</span>`
  }},
  { key: 'items_count', label: 'Items', width: 60, align: 'center', render: (row) => row.items?.length || 0 },
  { key: 'counted_at', label: 'Dihitung', width: 140, render: (row) => row.counted_at ? new Date(row.counted_at).toLocaleString('id-ID') : '-' },
  { key: 'approved_at', label: 'Disetujui', width: 140, render: (row) => row.approved_at ? new Date(row.approved_at).toLocaleString('id-ID') : '-' },
  { key: 'posted_at', label: 'Diposting', width: 140, render: (row) => row.posted_at ? new Date(row.posted_at).toLocaleString('id-ID') : '-' },
]

const actions = [
  { label: 'Detail', icon: EyeIcon, variant: 'ghost', onClick: (row) => viewDetail(row) },
  { label: 'Mulai Hitung', icon: PlayIcon, variant: 'primary', onClick: (row) => startCounting(row), show: (row) => row.status === 'draft' },
  { label: 'Input Hasil', icon: ClipboardDocumentListIcon, variant: 'ghost', onClick: (row) => openCountModal(row), show: (row) => row.status === 'counting' },
  { label: 'Setujui', icon: CheckIcon, variant: 'success', onClick: (row) => approveCount(row), show: (row) => row.status === 'counting' || row.status === 'review' },
  { label: 'Posting', icon: ArrowPathIcon, variant: 'ghost', onClick: (row) => postCount(row), show: (row) => row.status === 'approved' },
]

function openCreate() {
  form.value = { product_ids: [], is_blind: false, notes: '' }
  showModal.value = true
}

function viewDetail(sc) {
  router.visit(`/stock-counts/${sc.id}`)
}

function startCounting(sc) {
  router.post(`/api/v1/stock-counts/${sc.id}/start`, {}, {
    onSuccess: () => { success('Stock count dimulai'); router.reload() },
    onError: (err) => error(err),
  })
}

function openCountModal(sc) {
  countingSC.value = sc
  countInputs.value = {}
  sc.items?.forEach(item => {
    countInputs.value[item.id] = ''
  })
  showCountModal.value = true
}

async function saveCount() {
  if (!Object.keys(countInputs.value).length) { error('Isi minimal 1 item'); return }
  const items = Object.entries(countInputs.value).map(([id, qty]) => ({ stock_count_item_id: Number(id), counted_quantity: Number(qty) }))
  try {
    await router.post(`/api/v1/stock-counts/${countingSC.value.id}/record`, { items }, {
      onSuccess: () => { showCountModal.value = false; success('Hasil tersimpan'); router.reload() },
      onError: (err) => error(err),
    })
  } catch (e) {}
}

function approveCount(sc) {
  if (confirm('Setujui stock count ini?')) {
    router.post(`/api/v1/stock-counts/${sc.id}/approve`, {}, {
      onSuccess: () => { success('Disetujui'); router.reload() },
      onError: (err) => error(err),
    })
  }
}

function postCount(sc) {
  if (confirm('Posting stock count? Akan update stok produk.')) {
    router.post(`/api/v1/stock-counts/${sc.id}/post`, {}, {
      onSuccess: () => { success('Diposting & stok diupdate'); router.reload() },
      onError: (err) => error(err),
    })
  }
}

const form = ref({ product_ids: [], is_blind: false, notes: '' })
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Stock Opname</h1>
          <p class="text-sm text-muted-foreground">{{ props.stockCounts.total }} count</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Buat Stock Count</Button>
      </div>
    </template>

    <Card>
      <div class="flex flex-col sm:flex-row gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            v-model="search"
            type="text"
            placeholder="Cari count number..."
            class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>
        <Select v-model="statusFilter" :options="[{value:'',label:'Semua'},{value:'draft',label:'Draft'},{value:'counting',label:'Counting'},{value:'review',label:'Review'},{value:'approved',label:'Approved'},{value:'posted',label:'Posted'}]" placeholder="Status" class="w-36" />
      </div>

      <Table
        :columns="columns"
        :data="props.stockCounts.data.filter(s => !search.value || s.count_number.toLowerCase().includes(search.value.toLowerCase()))"
        :actions="actions"
        :loading="loading"
        :pagination="{
          page: props.stockCounts.current_page,
          perPage: props.stockCounts.per_page,
          total: props.stockCounts.total,
          onChange: (p) => router.visit('/stock-counts', { page: p, search: search.value, status: statusFilter.value }, { replace: true })
        }"
        emptyMessage="Belum ada stock count"
      />
    </Card>

    <!-- Create Modal -->
    <Modal v-model="showModal" title="Buat Stock Count Baru" @confirm="createSC">
      <div class="space-y-4">
        <div class="flex items-center gap-2">
          <input type="checkbox" v-model="form.is_blind" id="is_blind" class="w-4 h-4 text-indigo-600 rounded" />
          <label for="is_blind" class="text-sm">Blind Count (sembunyikan system qty dari petugas)</label>
        </div>
        <Select v-model="form.product_ids" :options="props.products.map(p=>({value:p.id,label:p.name + ' (Stock: ' + p.stock + ')'}))" multiple label="Produk (kosong = semua)" class="h-48" />
        <Input v-model="form.notes" type="textarea" label="Catatan" rows="2" />
      </div>
    </Modal>

    <!-- Count Modal -->
    <Modal v-model="showCountModal" :title="'Input Hasil: ' + countingSC?.count_number" size="xl" @confirm="saveCount">
      <div class="space-y-3 max-h-[60vh] overflow-y-auto">
        <div v-for="item in countingSC?.items" :key="item.id" class="bg-muted rounded-lg p-3">
          <div class="flex items-center justify-between mb-2">
            <div class="flex-1">
              <p class="font-medium">{{ item.product?.name }}</p>
              <p class="text-xs text-muted-foreground">{{ item.product?.sku }}</p>
            </div>
            <div v-if="!countingSC.is_blind" class="text-sm text-muted-foreground">System: {{ item.system_quantity }}</div>
          </div>
          <input
            v-model.number="countInputs[item.id]"
            type="number"
            min="0"
            placeholder="Hasil hitung fisik"
            class="w-full px-3 py-2 border border-border rounded-lg text-sm"
          >
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>