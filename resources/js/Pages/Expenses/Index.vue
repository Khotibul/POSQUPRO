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
  BanknotesIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  expenses: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  totalMonth: { type: Number, default: 0 },
  branches: { type: Array, default: () => [] },
})

const search = ref('')
const showModal = ref(false)
const editingExpense = ref(null)

const form = ref({
  category: '',
  description: '',
  amount: '',
  branch_id: '',
})

const columns = [
  { key: 'created_at', label: 'Tanggal', width: 150, render: (row) => row.created_at ? new Date(row.created_at).toLocaleString('id-ID') : '-' },
  { key: 'category', label: 'Kategori', width: 140, render: (row) => `<strong>${row.category}</strong>` },
  { key: 'description', label: 'Keterangan', render: (row) => row.description || '-' },
  { key: 'branch', label: 'Cabang', width: 130, render: (row) => row.branch?.name || '-' },
  { key: 'user', label: 'Oleh', width: 130, render: (row) => row.user?.name || '-' },
  { key: 'amount', label: 'Jumlah', width: 150, align: 'right', render: (row) => 'Rp ' + Number(row.amount).toLocaleString('id-ID') },
]

const actions = [
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (row) => editExpense(row) },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (row) => confirmDelete(row) },
]

function openCreate() { editingExpense.value = null; resetForm(); showModal.value = true }
function editExpense(e) { editingExpense.value = e; form.value = { category: e.category, description: e.description || '', amount: e.amount, branch_id: e.branch_id || '' }; showModal.value = true }
function resetForm() { form.value = { category: '', description: '', amount: '', branch_id: '' } }

async function saveExpense() {
  if (!form.value.category) { error('Kategori wajib diisi'); return }
  if (!form.value.amount || Number(form.value.amount) < 1) { error('Jumlah harus lebih dari 0'); return }
  try {
    const payload = { ...form.value, amount: Number(form.value.amount), branch_id: form.value.branch_id || null }
    if (editingExpense.value) {
      await router.put(`/api/v1/expenses/${editingExpense.value.id}`, payload, { onSuccess: () => { showModal.value = false; success('Pengeluaran diperbarui'); router.reload() }, onError: (err) => error(err) })
    } else {
      await router.post('/api/v1/expenses', payload, { onSuccess: () => { showModal.value = false; success('Pengeluaran dicatat'); router.reload() }, onError: (err) => error(err) })
    }
  } catch (e) {}
}

function confirmDelete(e) {
  if (confirm(`Hapus pengeluaran "${e.category} - Rp ${Number(e.amount).toLocaleString('id-ID')}"?`)) {
    router.delete(`/api/v1/expenses/${e.id}`, { onSuccess: () => { success('Dihapus'); router.reload() }, onError: (err) => error(err) })
  }
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Pengeluaran</h1>
          <p class="text-sm text-muted-foreground">{{ props.expenses.total }} catatan • Rp {{ Number(props.totalMonth).toLocaleString('id-ID') }} bulan ini</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Catat Pengeluaran</Button>
      </div>
    </template>

    <Card>
      <div class="flex gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input v-model="search" type="text" placeholder="Cari kategori, keterangan..." class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Catat Pengeluaran</Button>
      </div>

      <Table
        :columns="columns"
        :data="props.expenses.data.filter(e => !search || e.category.toLowerCase().includes(search.toLowerCase()) || (e.description || '').toLowerCase().includes(search.toLowerCase()))"
        :actions="actions"
        :loading="false"
        :pagination="{
          page: props.expenses.current_page,
          perPage: props.expenses.per_page,
          total: props.expenses.total,
          onChange: (p) => router.visit('/expenses', { page: p }, { replace: true })
        }"
        emptyMessage="Belum ada pengeluaran"
      />
    </Card>

    <Modal v-model="showModal" :title="editingExpense ? 'Edit Pengeluaran' : 'Catat Pengeluaran'" @confirm="saveExpense">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Input v-model="form.category" label="Kategori *" required placeholder="cth: Operasional, Listrik, Gaji" />
        <Input v-model="form.amount" type="number" label="Jumlah (Rp) *" required min="1" />
        <div>
          <label class="block text-sm font-medium mb-1">Cabang</label>
          <select v-model="form.branch_id" class="w-full px-3 py-2 bg-card border border-border rounded-lg text-sm">
            <option value="">-- Semua cabang --</option>
            <option v-for="b in props.branches" :key="b.id" :value="b.id">{{ b.name }}</option>
          </select>
        </div>
        <Input v-model="form.description" label="Keterangan" placeholder="Detail pengeluaran" class="md:col-span-2" />
      </div>
    </Modal>
  </AppLayout>
</template>
