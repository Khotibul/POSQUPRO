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
defineProps({ categories: Object, categories2: Array, allCategories: Array })

const showModal = ref(false)
const editing = ref(null)
const form = ref({ name: '', slug: '' })

function openCreate() { editing.value=null; form.value = { name: '', slug: '' }; showModal.value = true }
function openEdit(c) { editing.value=c; form.value = { name: c.name, slug: c.slug }; showModal.value = true }
async function save() {
  if (!form.value.name) { error('Nama wajib'); return }
  const data = { name: form.value.name, slug: form.value.name.toLowerCase().replace(/\s+/g,'-') }
  if (editing.value) await router.put(`/api/v1/categories/${editing.value.id}`, data, { onSuccess: () => { showModal.value=false; success('Kategori diperbarui'); router.reload() }})
  else await router.post('/api/v1/categories', data, { onSuccess: () => { showModal.value=false; success('Kategori dibuat'); router.reload() }})
}
function confirmDelete(c){ if(confirm(`Hapus kategori ${c.name}?`)) router.delete(`/api/v1/categories/${c.id}`, { onSuccess:()=>success('Dihapus') }) }

const columns = [
  { key: 'name', label: 'Nama Kategori' },
  { key: 'slug', label: 'Slug', width: 180 },
  { key: 'is_active', label: 'Status', width: 100, align: 'center', render: (r) => r.is_active!==undefined ? (r.is_active?'<span class="text-green-600">● Aktif</span>':'<span class="text-gray-400">○ Nonaktif</span>') : '<span class="text-green-600">● Aktif</span>' },
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
          <h1 class="text-2xl font-bold">Kategori Produk</h1>
          <p class="text-sm text-muted-foreground">{{ categories.total }} kategori • DB: categories (Laravel 5) + product_categories (Java 9) = {{ allCategories?.length || categories.total }}</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Kategori</Button>
      </div>
    </template>

    <Card>
      <div class="flex gap-2 mb-4">
        <span class="px-3 py-1.5 bg-primary/10 text-primary rounded-full text-sm">Laravel: 5</span>
        <span class="px-3 py-1.5 bg-green-100 text-green-700 rounded-full text-sm">Java: 9 (product_categories)</span>
        <span class="px-3 py-1.5 bg-muted rounded-full text-sm">Total tampil: {{ categories.total }} (paginated)</span>
      </div>
      <Table :columns="columns" :data="categories.data" :actions="actions" emptyMessage="Belum ada kategori" :pagination="{ page: categories.current_page, perPage: categories.per_page, total: categories.total, onChange: (p)=>router.visit('/categories',{page:p},{replace:true}) }" />
      <div v-if="allCategories" class="mt-4 p-3 bg-muted rounded-lg">
        <p class="text-sm font-medium">Semua kategori dari DB gabungan:</p>
        <div class="flex flex-wrap gap-1.5 mt-2">
          <span v-for="c in allCategories" :key="c.id + c.type" :class="['px-2 py-1 rounded text-xs', c.type==='Java' ? 'bg-green-100 text-green-700' : 'bg-primary/10 text-primary']">{{ c.name }} ({{ c.type }})</span>
        </div>
      </div>
    </Card>

    <Modal v-model="showModal" :title="editing ? 'Edit Kategori' : 'Tambah Kategori'" @confirm="save">
      <div class="space-y-3">
        <Input v-model="form.name" label="Nama Kategori *" required placeholder="Makanan, Minuman..." />
        <p class="text-xs text-muted-foreground">Slug auto dari nama. Akan masuk ke categories (Laravel).</p>
      </div>
    </Modal>
  </AppLayout>
</template>
