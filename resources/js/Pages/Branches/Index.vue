<script setup>
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Table from '@/Components/UI/Table.vue'
import Badge from '@/Components/UI/Badge.vue'
defineProps({ branches: Object })
const columns = [
  { key: 'code', label: 'Kode', width: 100 },
  { key: 'name', label: 'Nama Cabang' },
  { key: 'phone', label: 'Telepon', width: 140 },
  { key: 'address', label: 'Alamat' },
  { key: 'warehouses', label: 'Gudang', width: 100, align: 'center', render: (r) => r.warehouses?.length || 0 },
  { key: 'active', label: 'Status', width: 80, align: 'center', render: (r) => r.active ? '<span class="text-green-600">● Aktif</span>' : '<span class="text-gray-400">○ Nonaktif</span>' },
]
</script>
<template>
  <AppLayout>
    <template #header><h1 class="text-2xl font-bold">Manajemen Cabang</h1><p class="text-sm text-muted-foreground">{{ branches.total }} cabang • Dari DB posqu_pro_desktop.branches</p></template>
    <Card>
      <Table :columns="columns" :data="branches.data" emptyMessage="Belum ada cabang" />
      <div class="mt-4 text-xs text-muted-foreground">Data sesuai database: branches ({{ branches.total }}) — sinkron dengan POS Desktop Java</div>
    </Card>
  </AppLayout>
</template>
