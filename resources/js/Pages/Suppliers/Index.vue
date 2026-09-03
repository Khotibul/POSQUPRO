<script setup>
import { ref } from 'vue'
import { usePage, router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Button from '@/Components/UI/Button.vue'
import Input from '@/Components/UI/Input.vue'
import Modal from '@/Components/UI/Modal.vue'
import Table from '@/Components/UI/Table.vue'
import {
  MagnifyingGlassIcon, PlusIcon, PencilIcon, TrashIcon,
  EyeIcon, TruckIcon, ArrowDownTrayIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  suppliers: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
})

const search = ref('')
const showModal = ref(false)
const editingSupplier = ref(null)

const form = ref({
  name: '',
  email: '',
  phone: '',
  address: '',
  contact_person: '',
  is_active: true,
})

const columns = [
  { key: 'name', label: 'Nama', render: (row) => `<strong>${row.name}</strong>` },
  { key: 'contact_person', label: 'Contact Person', width: 140 },
  { key: 'email', label: 'Email', width: 180 },
  { key: 'phone', label: 'Telepon', width: 140 },
  { key: 'address', label: 'Alamat', render: (row) => row.address || '-' },
  { key: 'is_active', label: 'Status', width: 80, align: 'center', render: (row) => row.is_active ? '<span class="text-green-600">● Aktif</span>' : '<span class="text-gray-400">○ Nonaktif</span>' },
]

const actions = [
  { label: 'Lihat', icon: EyeIcon, variant: 'ghost', onClick: (row) => router.visit('/suppliers/' + row.id) },
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (row) => editSupplier(row) },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (row) => confirmDelete(row) },
]

function openCreate() { editingSupplier.value = null; resetForm(); showModal.value = true }
function editSupplier(s) { editingSupplier.value = s; form.value = { name: s.name, email: s.email || '', phone: s.phone || '', address: s.address || '', contact_person: s.contact_person || '', is_active: s.is_active }; showModal.value = true }
function resetForm() { form.value = { name: '', email: '', phone: '', address: '', contact_person: '', is_active: true } }

async function saveSupplier() {
  if (!form.value.name) { error('Nama wajib diisi'); return }
  try {
    if (editingSupplier.value) {
      await router.put(`/api/v1/suppliers/${editingSupplier.value.id}`, form.value, { onSuccess: () => { showModal.value = false; success('Supplier diperbarui'); router.reload() }, onError: (err) => error(err) })
    } else {
      await router.post('/api/v1/suppliers', form.value, { onSuccess: () => { showModal.value = false; success('Supplier dibuat'); router.reload() }, onError: (err) => error(err) })
    }
  } catch (e) {}
}

function confirmDelete(s) {
  if (confirm(`Hapus supplier ${s.name}?`)) {
    router.delete(`/api/v1/suppliers/${s.id}`, { onSuccess: () => { success('Dihapus'); router.reload() }, onError: (err) => error(err) })
  }
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Manajemen Supplier</h1>
          <p class="text-sm text-muted-foreground">{{ props.suppliers.total }} supplier</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Supplier</Button>
      </div>
    </template>

    <Card>
      <div class="flex gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input v-model="search" type="text" placeholder="Cari nama, email, telepon..." class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Supplier</Button>
      </div>

      <Table
        :columns="columns"
        :data="props.suppliers.data.filter(s => !search.value || s.name.toLowerCase().includes(search.value.toLowerCase()) || s.phone?.includes(search.value))"
        :actions="actions"
        :loading="false"
        :pagination="{
          page: props.suppliers.current_page,
          perPage: props.suppliers.per_page,
          total: props.suppliers.total,
          onChange: (p) => router.visit('/suppliers', { page: p, search: search.value }, { replace: true })
        }"
        emptyMessage="Belum ada supplier"
      />
    </Card>

    <Modal v-model="showModal" :title="editingSupplier ? 'Edit Supplier' : 'Tambah Supplier'" @confirm="saveSupplier">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Input v-model="form.name" label="Nama *" required />
        <Input v-model="form.contact_person" label="Contact Person" />
        <Input v-model="form.email" type="email" label="Email" />
        <Input v-model="form.phone" label="Telepon" />
        <Input v-model="form.address" type="textarea" label="Alamat" rows="2" class="md:col-span-2" />
        <div class="md:col-span-2 flex items-center gap-2">
          <input type="checkbox" v-model="form.is_active" id="supp_active" class="w-4 h-4 text-indigo-600 rounded" />
          <label for="supp_active" class="text-sm">Aktif</label>
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>