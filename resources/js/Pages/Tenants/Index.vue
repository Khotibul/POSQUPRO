<script setup>
import { ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Button from '@/Components/UI/Button.vue'
import Badge from '@/Components/UI/Badge.vue'
import Modal from '@/Components/UI/Modal.vue'
import Table from '@/Components/UI/Table.vue'
import {
  MagnifyingGlassIcon, PlusIcon, BuildingOffice2Icon,
  CheckCircleIcon, ClockIcon, XCircleIcon, EyeIcon,
  TrashIcon, NoSymbolIcon
} from '@heroicons/vue/24/outline'

const { success, error } = useToast()

const props = defineProps({
  tenants: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  plans: { type: Array, default: () => [] },
  stats: { type: Object, default: () => ({}) },
})

const search = ref('')
const filterStatus = ref('')
const showModal = ref(false)
const loading = ref(false)
const form = ref({
  name: '', email: '', phone: '', address: '', city: '', province: '',
  owner_name: '', owner_email: '', plan_id: null,
})

const statusColor = { active: 'success', trial: 'info', suspended: 'danger', inactive: 'warning' }
const statusLabel = { active: 'Aktif', trial: 'Trial', suspended: 'Suspended', inactive: 'Nonaktif' }

function renderStatus(row) {
  const c = { active: 'bg-green-100 text-green-700', trial: 'bg-blue-100 text-blue-700', suspended: 'bg-red-100 text-red-700', inactive: 'bg-gray-100 text-gray-700' }
  return '<span class="px-2 py-0.5 rounded text-xs ' + (c[row.status] || '') + '">' + (statusLabel[row.status] || row.status) + '</span>'
}

const columns = [
  { key: 'name', label: 'Tenant' },
  { key: 'owner.name', label: 'Pemilik', width: 140 },
  { key: 'plan.name', label: 'Paket', width: 100 },
  { key: 'status', label: 'Status', width: 100, align: 'center', render: renderStatus },
  { key: 'email', label: 'Email', width: 200 },
]

const filteredData = ref([])

function openCreate() {
  form.value = { name: '', email: '', phone: '', address: '', city: '', province: '', owner_name: '', owner_email: '', plan_id: null }
  showModal.value = true
}

function openDetail(tenant) {
  router.visit('/tenants/' + tenant.id)
}

async function saveTenant() {
  loading.value = true
  try {
    await router.post('/tenants', form.value, {
      onSuccess: () => { showModal.value = false; success('Tenant dibuat') },
      onError: (err) => error(err),
      onFinish: () => { loading.value = false },
    })
  } catch (e) { loading.value = false }
}

function suspendTenant(tenant) {
  if (confirm('Tangguhkan tenant "' + tenant.name + '"?')) {
    router.post('/tenants/' + tenant.id + '/suspend', { reason: 'Ditangguhkan oleh admin' }, {
      onSuccess: () => success('Tenant ditangguhkan'),
      onError: (err) => error(err),
    })
  }
}

function activateTenant(tenant) {
  router.post('/tenants/' + tenant.id + '/activate', {}, {
    onSuccess: () => success('Tenant diaktifkan'),
    onError: (err) => error(err),
  })
}

function deleteTenant(tenant) {
  if (confirm('Hapus tenant "' + tenant.name + '"? Semua data akan hilang.')) {
    router.delete('/tenants/' + tenant.id, {
      onSuccess: () => success('Tenant dihapus'),
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
          <h1 class="text-2xl font-bold">Manajemen Tenant</h1>
          <p class="text-sm text-muted-foreground">{{ props.tenants.total }} tenant</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Tenant</Button>
      </div>
    </template>

    <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center"><BuildingOffice2Icon class="w-5 h-5 text-blue-600" /></div>
          <div><p class="text-xs text-muted-foreground">Total</p><p class="text-xl font-bold">{{ stats.total }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center"><CheckCircleIcon class="w-5 h-5 text-green-600" /></div>
          <div><p class="text-xs text-muted-foreground">Aktif</p><p class="text-xl font-bold text-green-600">{{ stats.active }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-yellow-100 rounded-lg flex items-center justify-center"><ClockIcon class="w-5 h-5 text-yellow-600" /></div>
          <div><p class="text-xs text-muted-foreground">Trial</p><p class="text-xl font-bold text-yellow-600">{{ stats.trial }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-red-100 rounded-lg flex items-center justify-center"><XCircleIcon class="w-5 h-5 text-red-600" /></div>
          <div><p class="text-xs text-muted-foreground">Suspended</p><p class="text-xl font-bold text-red-600">{{ stats.suspended }}</p></div>
        </div>
      </Card>
    </div>

    <Card>
      <div class="flex flex-col sm:flex-row gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
          <input v-model="search" type="text" placeholder="Cari tenant..." class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
        </div>
        <select v-model="filterStatus" class="px-3 py-2 border border-border rounded-lg text-sm bg-background">
          <option value="">Semua Status</option>
          <option value="active">Aktif</option>
          <option value="trial">Trial</option>
          <option value="suspended">Suspended</option>
          <option value="inactive">Nonaktif</option>
        </select>
      </div>

      <Table
        :columns="columns"
        :actions="[
          { label: 'Detail', icon: EyeIcon, variant: 'ghost', onClick: (row) => openDetail(row) },
          { label: 'Aktifkan', icon: CheckCircleIcon, variant: 'ghost', onClick: (row) => activateTenant(row), show: (row) => row.status === 'suspended' || row.status === 'inactive' },
          { label: 'Tangguhkan', icon: NoSymbolIcon, variant: 'danger', onClick: (row) => suspendTenant(row), show: (row) => row.status === 'active' || row.status === 'trial' },
          { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (row) => deleteTenant(row), show: (row) => row.status !== 'active' },
        ]"
        :data="props.tenants.data.filter(function(t) { return !search || t.name.toLowerCase().includes(search.toLowerCase()) || (t.email && t.email.toLowerCase().includes(search.toLowerCase())); }).filter(function(t) { return !filterStatus || t.status === filterStatus; })"
        emptyMessage="Belum ada tenant"
      />
    </Card>

    <Modal v-model="showModal" title="Tambah Tenant Baru" @confirm="saveTenant" :loading="loading" size="lg">
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div class="col-span-2">
            <label class="block text-sm font-medium mb-1">Nama Usaha *</label>
            <input v-model="form.name" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" placeholder="PT Toko Sejahtera" required />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Email</label>
            <input v-model="form.email" type="email" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Telepon</label>
            <input v-model="form.phone" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div class="col-span-2">
            <label class="block text-sm font-medium mb-1">Alamat</label>
            <input v-model="form.address" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Kota</label>
            <input v-model="form.city" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Provinsi</label>
            <input v-model="form.province" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
        </div>
        <hr class="border-border" />
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-1">Nama Pemilik</label>
            <input v-model="form.owner_name" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Email Pemilik</label>
            <input v-model="form.owner_email" type="email" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div class="col-span-2">
            <label class="block text-sm font-medium mb-1">Paket</label>
            <select v-model="form.plan_id" class="w-full px-3 py-2 border border-border rounded-lg text-sm">
              <option :value="null">Free</option>
              <option v-for="p in props.plans" :key="p.id" :value="p.id">{{ p.name }} - Rp {{ Number(p.price).toLocaleString('id-ID') }}/bln</option>
            </select>
          </div>
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>
