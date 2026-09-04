<script setup>
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Table from '@/Components/UI/Table.vue'
import Button from '@/Components/UI/Button.vue'
import Input from '@/Components/UI/Input.vue'
import Modal from '@/Components/UI/Modal.vue'
import { ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import { PlusIcon, PencilIcon, TrashIcon, EyeIcon } from '@heroicons/vue/24/outline'

const { success, error } = useToast()
defineProps({ branches: Object })

const showModal = ref(false)
const editing = ref(null)
const form = ref({ code: '', name: '', phone: '', address: '', active: true })

const columns = [
  { key: 'code', label: 'Kode', width: 110 },
  { key: 'name', label: 'Nama Cabang' },
  { key: 'phone', label: 'Telepon', width: 140 },
  { key: 'address', label: 'Alamat' },
  { key: 'warehouses', label: 'Gudang', width: 90, align: 'center', render: (r) => r.warehouses?.length || 0 },
  { key: 'active', label: 'Status', width: 90, align: 'center', render: (r) => r.active ? '<span class="text-green-600">● Aktif</span>' : '<span class="text-gray-400">○ Nonaktif</span>' },
]
const actions = [
  { label: 'Lihat', icon: EyeIcon, variant: 'ghost', onClick: (r) => router.visit(`/branches/${r.id}`) },
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (r) => openEdit(r) },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (r) => confirmDelete(r) },
]
function openCreate() { editing.value=null; form.value={ code:'', name:'', phone:'', address:'', active:true }; showModal.value=true }
function openEdit(b) { editing.value=b; form.value={ code:b.code, name:b.name, phone:b.phone||'', address:b.address||'', active:!!b.active }; showModal.value=true }
async function save() {
  if(!form.value.code || !form.value.name) { error('Kode & nama wajib'); return }
  if(editing.value) await router.put(`/api/v1/branches/${editing.value.id}`, form.value, { onSuccess:()=>{ showModal.value=false; success('Cabang diperbarui'); router.reload() }})
  else await router.post('/api/v1/branches', form.value, { onSuccess:()=>{ showModal.value=false; success('Cabang dibuat'); router.reload() }})
}
function confirmDelete(b){ if(confirm(`Hapus cabang ${b.name}?`)) router.delete(`/api/v1/branches/${b.id}`, { onSuccess:()=>success('Dihapus') }) }
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex justify-between items-center">
        <div><h1 class="text-2xl font-bold">Manajemen Cabang</h1><p class="text-sm text-muted-foreground">{{ branches.total }} cabang • DB posqu_pro_desktop.branches</p></div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Cabang</Button>
      </div>
    </template>
    <Card>
      <Table :columns="columns" :data="branches.data" :actions="actions" emptyMessage="Belum ada cabang" :pagination="{ page: branches.current_page, perPage: branches.per_page, total: branches.total, onChange: (p)=>router.visit('/branches',{page:p},{replace:true}) }" />
    </Card>
    <Modal v-model="showModal" :title="editing ? 'Edit Cabang' : 'Tambah Cabang'" @confirm="save">
      <div class="grid grid-cols-2 gap-4">
        <Input v-model="form.code" label="Kode *" required placeholder="MAIN, CAB-01" />
        <Input v-model="form.name" label="Nama Cabang *" required placeholder="Toko Utama" />
        <Input v-model="form.phone" label="Telepon" placeholder="0812..." />
        <Input v-model="form.address" label="Alamat" placeholder="Jl. ..." />
        <div class="col-span-2 flex items-center gap-2"><input type="checkbox" v-model="form.active" id="b_active" class="w-4 h-4" /><label for="b_active" class="text-sm">Aktif</label></div>
      </div>
    </Modal>
  </AppLayout>
</template>
