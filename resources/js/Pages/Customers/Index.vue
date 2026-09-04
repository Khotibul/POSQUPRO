<script setup>
import { ref } from 'vue'
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
  MagnifyingGlassIcon, PlusIcon, PencilIcon, TrashIcon,
  EyeIcon, UsersIcon, ArrowDownTrayIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  customers: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
})

const search = ref('')
const showModal = ref(false)
const editingCustomer = ref(null)

const form = ref({
  name: '',
  email: '',
  phone: '',
  address: '',
  credit_limit: 0,
  is_active: true,
})

const columns = [
  { key: 'name', label: 'Nama', render: (row) => `<strong>${row.name}</strong>` },
  { key: 'email', label: 'Email', width: 180 },
  { key: 'phone', label: 'Telepon', width: 140 },
  { key: 'credit_limit', label: 'Limit Kredit', width: 120, align: 'right', render: (row) => 'Rp ' + Number(row.credit_limit).toLocaleString('id-ID') },
  { key: 'credit_balance', label: 'Hutang', width: 120, align: 'right', render: (row) => `<span class="${row.credit_balance > 0 ? 'text-red-600' : 'text-green-600'} font-medium">Rp ${Number(row.credit_balance).toLocaleString('id-ID')}</span>` },
  { key: 'is_active', label: 'Status', width: 80, align: 'center', render: (row) => row.is_active ? '<span class="text-green-600">● Aktif</span>' : '<span class="text-gray-400">○ Nonaktif</span>' },
]

const actions = [
  { label: 'Lihat', icon: EyeIcon, variant: 'ghost', onClick: (row) => router.visit('/customers/' + row.id) },
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (row) => editCustomer(row) },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (row) => confirmDelete(row) },
]

function openCreate() { editingCustomer.value = null; resetForm(); showModal.value = true }
function editCustomer(c) { editingCustomer.value = c; form.value = { name: c.name, email: c.email || '', phone: c.phone || '', address: c.address || '', credit_limit: Number(c.credit_limit), is_active: c.is_active }; showModal.value = true }
function resetForm() { form.value = { name: '', email: '', phone: '', address: '', credit_limit: 0, is_active: true } }

async function saveCustomer() {
  if (!form.value.name) { error('Nama wajib diisi'); return }
  try {
    if (editingCustomer.value) {
      await router.put(`/api/v1/customers/${editingCustomer.value.id}`, form.value, { onSuccess: () => { showModal.value = false; success('Customer diperbarui'); router.reload() }, onError: (err) => error(err) })
    } else {
      await router.post('/api/v1/customers', form.value, { onSuccess: () => { showModal.value = false; success('Customer dibuat'); router.reload() }, onError: (err) => error(err) })
    }
  } catch (e) {}
}

function confirmDelete(c) {
  if (confirm(`Hapus customer ${c.name}?`)) {
    router.delete(`/api/v1/customers/${c.id}`, { onSuccess: () => { success('Dihapus'); router.reload() }, onError: (err) => error(err) })
  }
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Manajemen Pelanggan</h1>
          <p class="text-sm text-muted-foreground">{{ props.customers.total }} pelanggan</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Pelanggan</Button>
      </div>
    </template>

    <Card>
      <div class="flex gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input v-model="search" type="text" placeholder="Cari nama, email, telepon..." class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Pelanggan</Button>
      </div>

      <Table
        :columns="columns"
        :data="props.customers.data.filter(c => !search || c.name.toLowerCase().includes(search.toLowerCase()) || c.phone?.includes(search))"
        :actions="actions"
        :loading="false"
        :pagination="{
          page: props.customers.current_page,
          perPage: props.customers.per_page,
          total: props.customers.total,
          onChange: (p) => router.visit('/customers', { page: p, search: search }, { replace: true })
        }"
        emptyMessage="Belum ada pelanggan"
      />
    </Card>

    <Modal v-model="showModal" :title="editingCustomer ? 'Edit Pelanggan' : 'Tambah Pelanggan'" @confirm="saveCustomer">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Input v-model="form.name" label="Nama *" required />
        <Input v-model="form.email" type="email" label="Email" />
        <Input v-model="form.phone" label="Telepon" />
        <Input v-model="form.address" type="textarea" label="Alamat" rows="2" />
        <Input v-model.number="form.credit_limit" type="number" min="0" step="10000" label="Limit Kredit (Rp)" />
        <div class="md:col-span-2 flex items-center gap-2">
          <input type="checkbox" v-model="form.is_active" id="cust_active" class="w-4 h-4 text-indigo-600 rounded" />
          <label for="cust_active" class="text-sm">Aktif</label>
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>