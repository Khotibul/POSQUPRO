<script setup>
import { ref, computed, watch } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Button from '@/Components/UI/Button.vue'
import Modal from '@/Components/UI/Modal.vue'
import Table from '@/Components/UI/Table.vue'
import {
  MagnifyingGlassIcon, PlusIcon, BuildingOffice2Icon,
  CheckCircleIcon, ClockIcon, XCircleIcon, EyeIcon,
  TrashIcon, NoSymbolIcon, PencilIcon, UsersIcon
} from '@heroicons/vue/24/outline'

const { success, error } = useToast()

const props = defineProps({
  tenants: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  plans: { type: Array, default: () => [] },
  stats: { type: Object, default: () => ({}) },
})

const search = ref('')
const filterStatus = ref('')
const filterPlan = ref(null)
const showModal = ref(false)
const loading = ref(false)
const editing = ref(null)
let slugTouched = false
let searchTimer = null

const form = ref(blankForm())

const lastPage = computed(() => Math.max(1, Math.ceil((props.tenants.total || 0) / (props.tenants.per_page || 15))))

const pagination = computed(() => ({
  page: props.tenants.current_page,
  perPage: props.tenants.per_page,
  total: props.tenants.total,
  onChange: (p) => applyFilters(p),
}))

const statusStyle = {
  active: 'bg-emerald-100 text-emerald-700',
  trial: 'bg-blue-100 text-blue-700',
  suspended: 'bg-orange-100 text-orange-700',
  expired: 'bg-gray-100 text-gray-500',
  inactive: 'bg-gray-100 text-gray-500',
}
const statusLabel = { active: 'ACTIVE', trial: 'TRIAL', suspended: 'SUSPENDED', expired: 'EXPIRED', inactive: 'INACTIVE' }

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))
}

function renderStatus(row) {
  const cls = statusStyle[row.status] || 'bg-gray-100 text-gray-500'
  const label = statusLabel[row.status] || row.status
  return '<span class="px-2 py-0.5 rounded-full text-xs font-medium ' + cls + '">' + esc(label) + '</span>'
}

function renderDomain(row) {
  const host = row.domain && row.subdomain ? row.subdomain + '.' + row.domain : (row.domain || row.subdomain || '')
  return host ? esc(host) : '-'
}

function renderDate(value) {
  return value ? new Date(value).toLocaleDateString('id-ID') : '-'
}

const columns = [
  {
    key: 'name',
    label: 'Tenant',
    render: (row) => '<div class="font-medium">' + esc(row.name) + '</div><div class="text-xs text-muted-foreground font-mono">' + esc(row.slug || '-') + '</div>',
  },
  {
    key: 'owner',
    label: 'Owner',
    width: 170,
    render: (row) => '<div class="text-sm">' + esc(row.owner?.name || '-') + '</div><div class="text-xs text-muted-foreground">' + esc(row.owner?.email || '') + '</div>',
  },
  { key: 'plan', label: 'Paket', width: 100, render: (row) => esc(row.plan?.name || 'Free') },
  { key: 'status', label: 'Status', width: 110, align: 'center', render: renderStatus },
  { key: 'trial_ends_at', label: 'Trial Berakhir', width: 120, render: (row) => renderDate(row.trial_ends_at) },
  { key: 'users_count', label: 'Users', width: 60, align: 'right', render: (row) => esc(row.users_count ?? 0) },
  { key: 'branches_count', label: 'Cabang', width: 70, align: 'right', render: (row) => esc(row.branches_count ?? 0) },
  { key: 'domain', label: 'Domain', width: 170, render: renderDomain },
]

function blankForm() {
  return {
    name: '', slug: '', domain: '', subdomain: '',
    status: 'trial', trial_ends_at: '', suspended_at: '',
    email: '', phone: '', address: '', city: '', province: '',
    owner_name: '', owner_email: '', owner_password: '',
    plan_id: null,
  }
}

function applyFilters(page = 1) {
  clearTimeout(searchTimer)
  const params = {}
  if (page > 1) params.page = page
  const q = search.value.trim()
  if (q) params.q = q
  if (filterStatus.value) params.status = filterStatus.value
  if (filterPlan.value) params.plan_id = filterPlan.value
  router.get('/tenants', params, { preserveState: true, preserveScroll: true, replace: true })
}

watch(search, () => {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => applyFilters(1), 350)
})
watch([filterStatus, filterPlan], () => applyFilters(1))

watch(() => form.value.name, (value) => {
  if (!editing.value && !slugTouched) {
    form.value.slug = value.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')
  }
})

function openCreate() {
  editing.value = null
  slugTouched = false
  form.value = blankForm()
  showModal.value = true
}

function openEdit(row) {
  editing.value = row
  slugTouched = true
  form.value = {
    name: row.name || '',
    slug: row.slug || '',
    domain: row.domain || '',
    subdomain: row.subdomain || '',
    status: row.status || 'trial',
    trial_ends_at: (row.trial_ends_at || '').slice(0, 10),
    suspended_at: (row.suspended_at || '').slice(0, 10),
    email: row.email || '',
    phone: row.phone || '',
    address: row.address || '',
    city: row.city || '',
    province: row.province || '',
    owner_name: '',
    owner_email: '',
    owner_password: '',
    plan_id: row.plan_id ?? null,
  }
  showModal.value = true
}

async function saveTenant() {
  loading.value = true
  const isEdit = !!editing.value
  try {
    const options = {
      onSuccess: () => { showModal.value = false; success(isEdit ? 'Tenant diperbarui' : 'Tenant dibuat') },
      onError: (err) => error(err),
      onFinish: () => { loading.value = false },
    }
    if (isEdit) {
      await router.put('/tenants/' + editing.value.id, form.value, options)
    } else {
      await router.post('/tenants', form.value, options)
    }
  } catch (e) { loading.value = false }
}

function openDetail(row) {
  router.visit('/tenants/' + row.id)
}

function openUsers(row) {
  router.get('/users', { tenant_id: row.id })
}

function suspendTenant(row) {
  if (confirm('Tangguhkan tenant "' + row.name + '"?')) {
    router.post('/tenants/' + row.id + '/suspend', { reason: 'Ditangguhkan oleh admin' }, {
      onSuccess: () => success('Tenant ditangguhkan'),
      onError: (err) => error(err),
    })
  }
}

function activateTenant(row) {
  router.post('/tenants/' + row.id + '/activate', {}, {
    onSuccess: () => success('Tenant diaktifkan'),
    onError: (err) => error(err),
  })
}

function deleteTenant(row) {
  if (confirm('Hapus tenant "' + row.name + '"? Semua data akan hilang.')) {
    router.delete('/tenants/' + row.id, {
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
          <p class="text-sm text-muted-foreground">
            Kelola tenant: aktif/nonaktif, trial, domain/subdomain, dan paket.
            Total {{ props.tenants.total }} tenant · halaman {{ props.tenants.current_page }}/{{ lastPage }}
          </p>
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
          <input
            v-model="search"
            type="text"
            placeholder="Cari nama, slug, domain, email..."
            class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            @keydown.enter="applyFilters(1)"
          />
        </div>
        <select v-model="filterStatus" class="px-3 py-2 border border-border rounded-lg text-sm bg-background">
          <option value="">Semua Status</option>
          <option value="active">Aktif</option>
          <option value="trial">Trial</option>
          <option value="suspended">Suspended</option>
          <option value="expired">Kedaluwarsa</option>
          <option value="inactive">Nonaktif</option>
        </select>
        <select v-model="filterPlan" class="px-3 py-2 border border-border rounded-lg text-sm bg-background">
          <option :value="null">Semua Paket</option>
          <option v-for="p in props.plans" :key="p.id" :value="p.id">{{ p.name }}</option>
        </select>
      </div>

      <Table
        :columns="columns"
        :data="props.tenants.data"
        :pagination="pagination"
        :actions="[
          { label: 'Detail', icon: EyeIcon, variant: 'ghost', onClick: (row) => openDetail(row) },
          { label: 'Users', icon: UsersIcon, variant: 'ghost', onClick: (row) => openUsers(row) },
          { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (row) => openEdit(row) },
          { label: 'Aktifkan', icon: CheckCircleIcon, variant: 'ghost', onClick: (row) => activateTenant(row), show: (row) => ['suspended', 'inactive', 'expired'].includes(row.status) },
          { label: 'Tangguhkan', icon: NoSymbolIcon, variant: 'danger', onClick: (row) => suspendTenant(row), show: (row) => row.status === 'active' || row.status === 'trial' },
          { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (row) => deleteTenant(row), show: (row) => row.status !== 'active' },
        ]"
        emptyMessage="Belum ada tenant"
      />
    </Card>

    <Modal v-model="showModal" :title="editing ? 'Ubah Tenant' : 'Tambah Tenant'" @confirm="saveTenant" :loading="loading" size="lg">
      <div class="space-y-4">
        <p class="text-xs text-muted-foreground">Pengaturan ini mempengaruhi akses tenant ke sistem.</p>

        <p class="text-xs font-semibold uppercase text-muted-foreground">Tenant</p>
        <div class="grid grid-cols-2 gap-4">
          <div class="col-span-2">
            <label class="block text-sm font-medium mb-1">Nama Usaha *</label>
            <input v-model="form.name" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" placeholder="PT Toko Sejahtera" required />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Slug</label>
            <input v-model="form.slug" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm font-mono" placeholder="otomatis dari nama" @input="slugTouched = true" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Domain</label>
            <input v-model="form.domain" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" placeholder="posqupro.co-id.id" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Subdomain</label>
            <input v-model="form.subdomain" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" placeholder="toko-sejahtera" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Paket</label>
            <select v-model="form.plan_id" class="w-full px-3 py-2 border border-border rounded-lg text-sm">
              <option :value="null">Free</option>
              <option v-for="p in props.plans" :key="p.id" :value="p.id">{{ p.name }} - Rp {{ Number(p.price).toLocaleString('id-ID') }}/bln</option>
            </select>
          </div>
          <div class="col-span-2 grid grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-medium mb-1">Status</label>
              <select v-model="form.status" class="w-full px-3 py-2 border border-border rounded-lg text-sm">
                <option value="trial">Trial</option>
                <option value="active">Aktif</option>
                <option value="suspended">Suspended</option>
                <option value="expired">Kedaluwarsa</option>
                <option value="inactive">Nonaktif</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium mb-1">Trial Berakhir</label>
              <input v-model="form.trial_ends_at" type="date" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
            </div>
            <div>
              <label class="block text-sm font-medium mb-1">Digantung Pada</label>
              <input v-model="form.suspended_at" type="date" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
            </div>
          </div>
        </div>

        <hr class="border-border" />
        <p class="text-xs font-semibold uppercase text-muted-foreground">Kontak</p>
        <div class="grid grid-cols-2 gap-4">
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

        <template v-if="!editing">
          <hr class="border-border" />
          <p class="text-xs font-semibold uppercase text-muted-foreground">Akun Admin</p>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium mb-1">Nama Pemilik</label>
              <input v-model="form.owner_name" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
            </div>
            <div>
              <label class="block text-sm font-medium mb-1">Email Pemilik</label>
              <input v-model="form.owner_email" type="email" class="w-full px-3 py-2 border border-border rounded-lg text-sm" placeholder="Akun admin tenant (login web + desktop)" />
            </div>
            <div class="col-span-2">
              <label class="block text-sm font-medium mb-1">Password Admin</label>
              <input v-model="form.owner_password" type="password" minlength="8" class="w-full px-3 py-2 border border-border rounded-lg text-sm" placeholder="Min. 8 karakter (otomatis jika kosong)" />
            </div>
          </div>
        </template>
      </div>
    </Modal>
  </AppLayout>
</template>
