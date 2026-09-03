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
import { PlusIcon } from '@heroicons/vue/24/outline'

const { success, error } = useToast()
defineProps({ taxes: Object })

const showModal = ref(false)
const form = ref({ name: '', rate: 0 })

function openCreate() { form.value = { name: '', rate: 0 }; showModal.value = true }
async function save() {
  if (!form.value.name) { error('Nama wajib'); return }
  await router.post('/api/v1/taxes', form.value, { onSuccess: () => { showModal.value=false; success('Pajak dibuat'); router.reload() } })
}

const columns = [
  { key: 'name', label: 'Nama Pajak' },
  { key: 'rate', label: 'Rate (%)', width: 100, align: 'right', render: (r) => Number(r.rate).toFixed(2) + '%' },
  { key: 'is_active', label: 'Status', width: 100, align: 'center', render: (r) => r.is_active ? '<span class="text-green-600">● Aktif</span>' : '<span class="text-gray-400">○ Nonaktif</span>' },
  { key: 'created_at', label: 'Dibuat', width: 160, render: (r) => r.created_at ? new Date(r.created_at).toLocaleDateString('id-ID') : '-' },
]
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-bold">Pajak</h1>
          <p class="text-sm text-muted-foreground">{{ taxes.total }} pajak • DB: taxes (Laravel) — Java pakai product_tax per produk</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Pajak</Button>
      </div>
    </template>

    <Card>
      <Table :columns="columns" :data="taxes.data" emptyMessage="Belum ada pajak" />
      <div class="mt-4 p-3 bg-muted rounded-lg text-sm">
        <p>Java Desktop: pajak per produk via <code>products.product_tax</code> decimal(5,2)</p>
        <p>Laravel: master <code>taxes</code> dengan rate & relasi ke produk via <code>tax_id</code></p>
      </div>
    </Card>

    <Modal v-model="showModal" title="Tambah Pajak" @confirm="save">
      <div class="space-y-3">
        <Input v-model="form.name" label="Nama Pajak *" required placeholder="PPN 11%" />
        <Input v-model.number="form.rate" type="number" step="0.01" min="0" max="100" label="Rate (%) *" required />
      </div>
    </Modal>
  </AppLayout>
</template>
