<script setup>
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Table from '@/Components/UI/Table.vue'
defineProps({ warehouses: Object })
const columns = [
  { key: 'code', label: 'Kode', width: 100 },
  { key: 'name', label: 'Nama Gudang' },
  { key: 'branch.name', label: 'Cabang', width: 140 },
  { key: 'phone', label: 'Telepon', width: 140 },
  { key: 'address', label: 'Alamat' },
  { key: 'active', label: 'Status', width: 80, align: 'center', render: (r) => r.active ? '<span class="text-green-600">● Aktif</span>' : '<span class="text-gray-400">○ Nonaktif</span>' },
]
</script>
<template>
  <AppLayout>
    <template #header><h1 class="text-2xl font-bold">Manajemen Gudang</h1><p class="text-sm text-muted-foreground">{{ warehouses.total }} gudang • Dari DB posqu_pro_desktop.warehouses</p></template>
    <Card>
      <Table :columns="columns" :data="warehouses.data" emptyMessage="Belum ada gudang" />
      <div class="mt-4 text-xs text-muted-foreground">Data sesuai database: warehouses ({{ warehouses.total }}) + branch relation</div>
    </Card>
  </AppLayout>
</template>
