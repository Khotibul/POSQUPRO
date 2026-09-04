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
  EyeIcon, UserGroupIcon, ShieldCheckIcon, KeyIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  users: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  roles: { type: Array, default: () => [] },
})

const search = ref('')
const showModal = ref(false)
const editingUser = ref(null)

const form = ref({
  name: '',
  email: '',
  password: '',
  phone: '',
  is_active: true,
  roles: [],
})

const columns = [
  { key: 'name', label: 'Nama', render: (row) => `<strong>${row.name}</strong>` },
  { key: 'email', label: 'Email', width: 200 },
  { key: 'phone', label: 'Telepon', width: 140 },
  { key: 'roles', label: 'Role', render: (row) => row.roles?.map(r => `<span class="px-1.5 py-0.5 bg-indigo-100 text-indigo-700 text-xs rounded mr-1">${r.name}</span>`).join('') || '-' },
  { key: 'is_active', label: 'Status', width: 80, align: 'center', render: (row) => row.is_active ? '<span class="text-green-600">● Aktif</span>' : '<span class="text-gray-400">○ Nonaktif</span>' },
  { key: 'last_login_at', label: 'Login Terakhir', width: 160, render: (row) => row.last_login_at ? new Date(row.last_login_at).toLocaleString('id-ID') : '-' },
]

const actions = [
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (row) => editUser(row) },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (row) => confirmDelete(row), show: (row) => row.id !== page.props.auth?.user?.id },
]

function openCreate() { editingUser.value = null; resetForm(); showModal.value = true }
function editUser(u) { editingUser.value = u; form.value = { name: u.name, email: u.email, password: '', phone: u.phone || '', is_active: u.is_active, roles: u.roles?.map(r => r.name) || [] }; showModal.value = true }
function resetForm() { form.value = { name: '', email: '', password: '', phone: '', is_active: true, roles: [] } }

async function saveUser() {
  if (!form.value.name || !form.value.email) { error('Nama & email wajib'); return }
  if (!editingUser.value && !form.value.password) { error('Password wajib untuk user baru'); return }
  try {
    if (editingUser.value) {
      await router.put(`/api/v1/users/${editingUser.value.id}`, form.value, { onSuccess: () => { showModal.value = false; success('User diperbarui'); router.reload() }, onError: (err) => error(err) })
    } else {
      await router.post('/api/v1/users', form.value, { onSuccess: () => { showModal.value = false; success('User dibuat'); router.reload() }, onError: (err) => error(err) })
    }
  } catch (e) {}
}

function confirmDelete(u) {
  if (u.id === page.props.auth?.user?.id) { error('Tidak bisa menghapus diri sendiri'); return }
  if (confirm(`Hapus user ${u.name}?`)) {
    router.delete(`/api/v1/users/${u.id}`, { onSuccess: () => { success('Dihapus'); router.reload() }, onError: (err) => error(err) })
  }
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Manajemen Pengguna & RBAC</h1>
          <p class="text-sm text-muted-foreground">{{ props.users.total }} pengguna</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah User</Button>
      </div>
    </template>

    <Card>
      <div class="flex gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input v-model="search" type="text" placeholder="Cari nama, email..." class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah User</Button>
      </div>

      <Table
        :columns="columns"
        :data="props.users.data.filter(u => !search || u.name.toLowerCase().includes(search.toLowerCase()) || u.email?.includes(search))"
        :actions="actions"
        :loading="false"
        :pagination="{
          page: props.users.current_page,
          perPage: props.users.per_page,
          total: props.users.total,
          onChange: (p) => router.visit('/users', { page: p, search: search }, { replace: true })
        }"
        emptyMessage="Belum ada pengguna"
      />
    </Card>

    <Modal v-model="showModal" :title="editingUser ? 'Edit User' : 'Tambah User'" size="lg" @confirm="saveUser">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Input v-model="form.name" label="Nama *" required />
        <Input v-model="form.email" type="email" label="Email *" required />
        <Input v-model="form.password" type="password" :label="editingUser ? 'Password (kosongkan jika tidak diubah)' : 'Password *'" :required="!editingUser" />
        <Input v-model="form.phone" label="Telepon" />
        <Select v-model="form.roles" :options="props.roles.map(r=>({value:r.name,label:r.name}))" multiple label="Roles" />
        <div class="md:col-span-2 flex items-center gap-2">
          <input type="checkbox" v-model="form.is_active" id="user_active" class="w-4 h-4 text-indigo-600 rounded" />
          <label for="user_active" class="text-sm">Aktif</label>
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>