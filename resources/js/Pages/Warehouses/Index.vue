<script setup>
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Table from '@/Components/UI/Table.vue'
import Button from '@/Components/UI/Button.vue'
import Input from '@/Components/UI/Input.vue'
import Select from '@/Components/UI/Select.vue'
import Modal from '@/Components/UI/Modal.vue'
import { ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import { PlusIcon, PencilIcon, TrashIcon, EyeIcon } from '@heroicons/vue/24/outline'

const { success, error } = useToast()
const props = defineProps({ warehouses: Object, branches: Array })

const showModal = ref(false)
const editing = ref(null)
const form = ref({ branch_id: '', code: '', name: '', phone: '', address: '', active: true })

const columns = [
  { key: 'code', label: 'Kode', width: 110 },
  { key: 'name', label: 'Nama Gudang' },
  { key: 'branch.name', label: 'Cabang', width: 140 },
  { key: 'phone', label: 'Telepon', width: 140 },
  { key: 'address', label: 'Alamat' },
  { key: 'active', label: 'Status', width: 90, align: 'center', render: (r) => r.active ? '<span class="text-green-600">● Aktif</span>' : '<span class="text-gray-400">○ Nonaktif</span>' },
]
const actions = [
  { label: 'Lihat', icon: EyeIcon, variant: 'ghost', onClick: (r) => router.visit(`/warehouses/${r.id}`) },
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (r) => openEdit(r) },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (r) => confirmDelete(r) },
]
function openCreate() { editing.value=null; form.value={ branch_id:'', code:'', name:'', phone:'', address:'', active:true }; showModal.value=true }
function openEdit(w) { editing.value=w; form.value={ branch_id: String(w.branch_id||''), code:w.code, name:w.name, phone:w.phone||'', address:w.address||'', active:!!w.active }; showModal.value=true }
async function save() {
  if(!form.value.branch_id || !form.value.code || !form.value.name) { error('Cabang, kode & nama wajib'); return }
  const data = { ...form.value, branch_id: Number(form.value.branch_id) }
  if(editing.value) await router.put(`/api/v1/warehouses/${editing.value.id}`, data, { onSuccess:()=>{ showModal.value=false; success('Gudang diperbarui'); router.reload() }})
  else await router.post('/api/v1/warehouses', data, { onSuccess:()=>{ showModal.value=false; success('Gudang dibuat'); router.reload() }})
}
function confirmDelete(w){ if(confirm(`Hapus gudang ${w.name}?`)) router.delete(`/api/v1/warehouses/${w.id}`, { onSuccess:()=>success('Dihapus') }) }
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex justify-between items-center">
        <div><h1 class="text-2xl font-bold">Manajemen Gudang</h1><p class="text-sm text-muted-foreground">{{ warehouses.total }} gudang • DB posqu_pro_desktop.warehouses</p></div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Gudang</Button>
      </div>
    </template>
    <Card>
      <Table :columns="columns" :data="warehouses.data" :actions="actions" emptyMessage="Belum ada gudang" :pagination="{ page: warehouses.current_page, perPage: warehouses.per_page, total: warehouses.total, onChange: (p)=>router.visit('/warehouses',{page:p},{replace:true}) }" />
    </Card>
    <Modal v-model="showModal" :title="editing ? 'Edit Gudang' : 'Tambah Gudang'" @confirm="save">
      <div class="grid grid-cols-2 gap-4">
        <div class="col-span-2">
          <label class="text-sm font-medium">Cabang *</label>
          <select v-model="form.branch_id" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background">
            <option value="">Pilih Cabang</option>
            <option v-for="b in branches || []" :key="b.id" :value="String(b.id)">{{ b.name }} ({{ b.code }})</option>
          </select>
        </div>
        <Input v-model="form.code" label="Kode *" required placeholder="GUD-01" />
        <Input v-model="form.name" label="Nama Gudang *" required placeholder="Gudang Utama" />
        <Input v-model="form.phone" label="Telepon" />
        <Input v-model="form.address" label="Alamat" />
        <div class="col-span-2 flex items-center gap-2"><input type="checkbox" v-model="form.active" id="w_active" class="w-4 h-4" /><label for="w_active" class="text-sm">Aktif</label></div>
      </div>
    </Modal>
  </AppLayout>
</template>
