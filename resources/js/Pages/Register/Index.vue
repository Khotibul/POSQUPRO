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
  MagnifyingGlassIcon, PlusIcon, BanknotesIcon,
  PlayIcon, StopIcon, ArrowPathIcon, EyeIcon,
  PencilIcon, TrashIcon, CurrencyDollarIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  registers: { type: Object, default: () => ({ data: [], total: 0, current_page: 1, per_page: 15 }) },
  currentSession: { type: Object, default: null },
})

const search = ref('')
const showModal = ref(false)
const showCloseModal = ref(false)
const closingSession = ref(null)
const closeForm = ref({ actual_cash: 0, notes: '' })
const showCreateRegister = ref(false)
const newRegister = ref({ name: '', code: '', description: '', is_active: true })

const columns = [
  { key: 'name', label: 'Nama Register', width: 140 },
  { key: 'code', label: 'Kode', width: 100 },
  { key: 'is_active', label: 'Status', width: 80, align: 'center', render: (row) => row.is_active ? '<span class="text-green-600">● Aktif</span>' : '<span class="text-gray-400">○ Nonaktif</span>' },
  { key: 'open_session', label: 'Sesi Aktif', width: 200, render: (row) => {
    if (!row.open_session) return '<span class="text-gray-400">Tidak ada sesi</span>'
    return `<div class="text-sm"><p class="font-medium">${row.open_session.user?.name}</p><p class="text-xs text-muted-foreground">Float: Rp ${Number(row.open_session.opening_float).toLocaleString('id-ID')}</p><p class="text-xs text-muted-foreground">${new Date(row.open_session.opened_at).toLocaleString('id-ID')}</p></div>`
  }},
]

const actions = [
  { label: 'Buka Sesi', icon: PlayIcon, variant: 'primary', onClick: (row) => openSession(row), show: (row) => !row.open_session },
  { label: 'Tutup Sesi', icon: StopIcon, variant: 'danger', onClick: (row) => closeSession(row), show: (row) => !!row.open_session },
  { label: 'Detail', icon: EyeIcon, variant: 'ghost', onClick: (row) => router.visit('/register/' + row.id) },
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (row) => editRegister(row) },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (row) => confirmDelete(row) },
]

function openCreate() { showCreateRegister.value = true }
function editRegister(r) { newRegister.value = { name: r.name, code: r.code, description: r.description, is_active: r.is_active }; showCreateRegister.value = true }
function createRegister() {
  if (!newRegister.value.name || !newRegister.value.code) { error('Nama & kode wajib'); return }
  router.post('/api/v1/registers', newRegister.value, {
    onSuccess: () => { showCreateRegister.value = false; success('Register dibuat'); router.reload(); newRegister.value = { name: '', code: '', description: '', is_active: true } },
    onError: (err) => error(err),
  })
}

function openSession(r) {
  form.value = { register_id: r.id, opening_float: 0, notes: '' }
  showModal.value = true
}

async function saveOpen() {
  if (!form.value.opening_float) { error('Masukkan opening float'); return }
  try {
    await router.post('/api/v1/register-sessions/open', form.value, {
      onSuccess: () => { showModal.value = false; success('Sesi dibuka'); router.reload(); form.value = { opening_float: 0, notes: '' } },
      onError: (err) => error(err),
    })
  } catch (e) {}
}

function closeSession(s) {
  closingSession.value = s
  closeForm.value = { actual_cash: 0, notes: '' }
  showCloseModal.value = true
}

async function saveClose() {
  if (!closeForm.value.actual_cash) { error('Masukkan aktual cash'); return }
  try {
    await router.post(`/api/v1/register-sessions/${closingSession.value.id}/close`, closeForm.value, {
      onSuccess: () => { showCloseModal.value = false; success('Sesi ditutup'); router.reload(); closeForm.value = { actual_cash: 0, notes: '' }; closingSession.value = null },
      onError: (err) => error(err),
    })
  } catch (e) {}
}

function confirmDelete(r) {
  if (confirm(`Hapus register ${r.name}?`)) {
    router.delete(`/api/v1/registers/${r.id}`, {
      onSuccess: () => { success('Dihapus'); router.reload() },
      onError: (err) => error(err),
    })
  }
}

const form = ref({ register_id: '', opening_float: 0, notes: '' })
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Register & Shift Kasir</h1>
          <p class="text-sm text-muted-foreground">{{ props.registers.total }} register</p>
        </div>
        <div class="flex gap-2">
          <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Register</Button>
        </div>
      </div>
    </template>

    <!-- Current Session Banner -->
    <Card v-if="props.currentSession" class="mb-6 bg-indigo-50 border-indigo-100">
      <div class="flex items-center justify-between">
        <div>
          <p class="font-semibold text-indigo-800">Sesi Aktif: {{ props.currentSession.register?.name }}</p>
          <p class="text-sm text-indigo-600">
            Kasir: {{ props.currentSession.user?.name }} | Float: Rp {{ Number(props.currentSession.opening_float).toLocaleString('id-ID') }} | Dibuka: {{ new Date(props.currentSession.opened_at).toLocaleString('id-ID') }}
          </p>
        </div>
        <Button variant="danger" @click="closeSession(props.currentSession)"><StopIcon class="w-4 h-4" /> Tutup Sesi</Button>
      </div>
    </Card>

    <Card>
      <div class="flex flex-col sm:flex-row gap-3 mb-4">
        <div class="flex-1 relative">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            v-model="search"
            type="text"
            placeholder="Cari register..."
            class="w-full pl-10 pr-4 py-2 bg-card border border-border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Register</Button>
      </div>

      <Table
        :columns="columns"
        :data="props.registers.data.filter(r => !search.value || r.name.toLowerCase().includes(search.value.toLowerCase()) || r.code.toLowerCase().includes(search.value.toLowerCase()))"
        :actions="actions"
        :loading="false"
        emptyMessage="Belum ada register"
      />
    </Card>

    <!-- Open Session Modal -->
    <Modal v-model="showModal" title="Buka Sesi Register" @confirm="saveOpen">
      <div class="space-y-4">
        <Select v-model="form.register_id" :options="props.registers.data.filter(r => r.is_active && !r.open_session).map(r=>({value:r.id,label:r.name + ' (' + r.code + ')'}))" label="Register *" required />
        <Input v-model.number="form.opening_float" type="number" min="0" step="1000" label="Opening Float (Rp) *" required placeholder="Contoh: 500000" />
        <Input v-model="form.notes" type="textarea" label="Catatan" rows="2" placeholder="Catatan pembukaan sesi (opsional)" />
      </div>
    </Modal>

    <!-- Close Session Modal -->
    <Modal v-model="showCloseModal" :title="'Tutup Sesi: ' + closingSession?.register?.name" @confirm="saveClose">
      <div class="space-y-4">
        <div class="bg-muted rounded-lg p-4">
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div><p class="text-muted-foreground">Opening Float</p><p class="font-semibold">Rp {{ Number(closingSession?.opening_float || 0).toLocaleString('id-ID') }}</p></div>
            <div><p class="text-muted-foreground">Estimated Cash Sales</p><p class="font-semibold">Rp {{ Number(closingSession?.expected_cash || 0).toLocaleString('id-ID') }}</p></div>
            <div><p class="text-muted-foreground">Expected Total Cash</p><p class="font-semibold text-indigo-600">Rp {{ Number((closingSession?.opening_float || 0) + (closingSession?.expected_cash || 0)).toLocaleString('id-ID') }}</p></div>
          </div>
        </div>
        <Input v-model.number="closeForm.actual_cash" type="number" min="0" step="1000" label="Aktual Cash di Laci (Rp) *" required placeholder="Masukkan jumlah uang fisik" />
        <Input v-model="closeForm.notes" type="textarea" label="Catatan Penutupan" rows="2" placeholder="Catatan selisih/over/short (opsional)" />
      </div>
    </Modal>

    <!-- Create Register Modal -->
    <div v-if="showCreateRegister" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div class="bg-card rounded-xl max-w-md w-full p-6">
        <div class="flex justify-between items-center mb-4">
          <h3 class="font-semibold text-lg">Tambah Register Baru</h3>
          <button @click="showCreateRegister = false" class="text-gray-400 hover:text-gray-600">×</button>
        </div>
        <div class="space-y-4">
          <Input v-model="newRegister.name" label="Nama Register *" required placeholder="Contoh: Kasir 1" />
          <Input v-model="newRegister.code" label="Kode (Unik) *" required placeholder="Contoh: REG-001" />
          <Input v-model="newRegister.description" type="textarea" label="Deskripsi" rows="2" />
          <div class="flex items-center gap-2">
            <input type="checkbox" v-model="newRegister.is_active" id="reg_active" class="w-4 h-4 text-indigo-600 rounded" />
            <label for="reg_active" class="text-sm">Aktif</label>
          </div>
          <div class="flex gap-2 pt-4">
            <Button variant="ghost" class="flex-1" @click="showCreateRegister = false">Batal</Button>
            <Button @click="createRegister" class="flex-1">Simpan</Button>
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>