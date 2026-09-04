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
import { PlusIcon, PencilIcon, TrashIcon } from '@heroicons/vue/24/outline'

const { success, error } = useToast()
defineProps({ units: Object, allUnits: Array, unitQuantities: Array })

const showModal = ref(false)
const editing = ref(null)
const form = ref({ name: '', symbol: '' })

function openCreate() { editing.value=null; form.value = { name: '', symbol: '' }; showModal.value = true }
function openEdit(u) { editing.value=u; form.value = { name: u.name, symbol: u.symbol }; showModal.value = true }
async function save() {
  if (!form.value.name || !form.value.symbol) { error('Nama & simbol wajib'); return }
  if (editing.value) await router.put(`/api/v1/unit-quantities/${editing.value.id}`, form.value, { onSuccess: () => { showModal.value=false; success('Satuan diperbarui'); router.reload() }})
  else await router.post('/api/v1/unit-quantities', form.value, { onSuccess: () => { showModal.value=false; success('Satuan dibuat'); router.reload() }})
}
function confirmDelete(u){ if(confirm(`Hapus satuan ${u.name}?`)) router.delete(`/api/v1/unit-quantities/${u.id}`, { onSuccess:()=>success('Dihapus') }) }

const columns = [
  { key: 'name', label: 'Nama Satuan' },
  { key: 'symbol', label: 'Simbol', width: 100, align: 'center' },
  { key: 'created_at', label: 'Dibuat', width: 160, render: (r) => r.created_at ? new Date(r.created_at).toLocaleDateString('id-ID') : '-' },
]
const actions = [
  { label: 'Edit', icon: PencilIcon, variant: 'ghost', onClick: (r) => openEdit(r) },
  { label: 'Hapus', icon: TrashIcon, variant: 'danger', onClick: (r) => confirmDelete(r) },
]
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-bold">Satuan Produk</h1>
          <p class="text-sm text-muted-foreground">{{ units.total }} satuan • DB: unit_quantities (5) + units Java (10)</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Satuan</Button>
      </div>
    </template>

    <Card>
      <div class="flex gap-2 mb-4">
        <span class="px-3 py-1.5 bg-primary/10 text-primary rounded-full text-sm">Laravel unit_quantities: {{ unitQuantities?.length || 5 }}</span>
        <span class="px-3 py-1.5 bg-green-100 text-green-700 rounded-full text-sm">Java units: {{ allUnits?.length || 10 }}</span>
      </div>
      <Table :columns="columns" :data="units.data" :actions="actions" emptyMessage="Belum ada satuan" :pagination="{ page: units.current_page, perPage: units.per_page, total: units.total, onChange: (p)=>router.visit('/units',{page:p},{replace:true}) }" />
      <div v-if="allUnits" class="mt-4 p-3 bg-muted rounded-lg">
        <p class="text-sm font-medium">Semua satuan Java (units):</p>
        <div class="flex flex-wrap gap-1.5 mt-2">
          <span v-for="u in allUnits" :key="u.id" class="px-2 py-1 bg-green-100 text-green-700 rounded text-xs">{{ u.name }}</span>
        </div>
      </div>
    </Card>

    <Modal v-model="showModal" :title="editing ? 'Edit Satuan' : 'Tambah Satuan'" @confirm="save">
      <div class="space-y-3">
        <Input v-model="form.name" label="Nama Satuan *" required placeholder="Kilogram, Liter..." />
        <Input v-model="form.symbol" label="Simbol *" required placeholder="kg, ltr..." />
      </div>
    </Modal>
  </AppLayout>
</template>
