<script setup>
import { ref, computed } from 'vue'
defineProps({
  columns: { type: Array, required: true }, // [{ key, label, sortable, width, align, render }]
  data: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  emptyMessage: { type: String, default: 'Tidak ada data' },
  rowKey: { type: String, default: 'id' },
  striped: { type: Boolean, default: true },
  hoverable: { type: Boolean, default: true },
  selectable: { type: Boolean, default: false },
  selected: { type: Array, default: () => [] },
  pagination: { type: Object, default: null }, // { page, perPage, total, onChange }
  actions: { type: Array, default: () => [] }, // [{ label, variant, icon, onClick, show }]
})

const emit = defineEmits(['select', 'action', 'sort', 'page-change'])

const sortColumn = ref('')
const sortDirection = ref('asc')
const localSelected = ref([])

const sortedData = computed(() => {
  if (!sortColumn.value) return data.value
  return [...data.value].sort((a, b) => {
    const av = a[sortColumn.value]
    const bv = b[sortColumn.value]
    const dir = sortDirection.value === 'asc' ? 1 : -1
    if (av < bv) return -1 * dir
    if (av > bv) return 1 * dir
    return 0
  })
})

function handleSort(key) {
  if (sortColumn.value === key) {
    sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortColumn.value = key
    sortDirection.value = 'asc'
  }
  emit('sort', { key, direction: sortDirection.value })
}

function toggleRow(row) {
  const idx = localSelected.value.findIndex(r => r[rowKey.value] === row[rowKey.value])
  if (idx > -1) localSelected.value.splice(idx, 1)
  else localSelected.value.push(row)
  emit('select', localSelected.value)
}

function isSelected(row) {
  return localSelected.value.some(r => r[rowKey.value] === row[rowKey.value])
}

function handleAction(action, row) { emit('action', { action, row }) }
function selectAll() {
  if (localSelected.value.length === sortedData.value.length) {
    localSelected.value = []
  } else {
    localSelected.value = [...sortedData.value]
  }
  emit('select', localSelected.value)
}
</script>
<template>
  <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
    <div class="overflow-x-auto">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th v-if="selectable" class="px-4 py-3 text-center">
              <input type="checkbox" :checked="localSelected.length === sortedData.length && sortedData.length > 0" :indeterminate="localSelected.length > 0 && localSelected.length < sortedData.length" @change="selectAll" class="w-4 h-4 text-indigo-600 rounded" />
            </th>
            <th v-for="col in columns" :key="col.key"
              :class="['px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider', col.align ? `text-${col.align}` : '', col.sortable ? 'cursor-pointer hover:bg-gray-100 select-none' : '']"
              :style="{ width: col.width ? `${col.width}px` : undefined }"
              @click="col.sortable && handleSort(col.key)"
            >
              <div class="flex items-center gap-1">
                <span>{{ col.label }}</span>
                <svg v-if="col.sortable" class="w-4 h-4" :class="{ 'rotate-180': sortColumn === col.key && sortDirection === 'desc' }" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/></svg>
              </div>
            </th>
            <th v-if="actions.length" class="px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase tracking-wider">Aksi</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          <tr v-if="loading" class="animate-pulse">
            <td :colspan="columns.length + (selectable ? 1 : 0) + (actions.length ? 1 : 0)" class="px-4 py-8 text-center text-gray-500">Memuat...</td>
          </tr>
          <tr v-else-if="!loading && (!data || data.length === 0)">
            <td :colspan="columns.length + (selectable ? 1 : 0) + (actions.length ? 1 : 0)" class="px-4 py-8 text-center text-gray-500">{{ emptyMessage }}</td>
          </tr>
          <tr v-for="row in sortedData" :key="row[rowKey]"
            :class="['transition-colors', hoverable ? 'hover:bg-gray-50' : '', isSelected(row) ? 'bg-indigo-50' : '']"
          >
            <td v-if="selectable" class="px-4 py-3 text-center">
              <input type="checkbox" :checked="isSelected(row)" @change="toggleRow(row)" @click.stop class="w-4 h-4 text-indigo-600 rounded" />
            </td>
            <td v-for="col in columns" :key="col.key" class="px-4 py-3 text-sm text-gray-900" :class="col.align ? `text-${col.align}` : ''">
              <span v-if="col.render" v-html="col.render(row, col)"></span>
              <span v-else>{{ row[col.key] }}</span>
            </td>
            <td v-if="actions.length" class="px-4 py-3 text-center">
              <div class="flex items-center justify-center gap-1.5">
                <button v-for="act in actions" :key="act.label"
                  v-if="!act.show || act.show(row)"
                  :class="['p-1.5 rounded text-gray-500 hover:text-gray-700 hover:bg-gray-100 transition-colors', act.variant === 'danger' && 'text-red-500 hover:text-red-700 hover:bg-red-50']"
                  @click.stop="handleAction(act, row)"
                  :title="act.label"
                >
                  <component :is="act.icon" class="w-4 h-4" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <div v-if="pagination" class="px-4 py-3 border-t border-gray-100 flex items-center justify-between">
      <div class="text-sm text-gray-600">
        Menampilkan {{ (pagination.page - 1) * pagination.perPage + 1 }} - {{ Math.min(pagination.page * pagination.perPage, pagination.total) }} dari {{ pagination.total }}
      </div>
      <div class="flex gap-2">
        <Button size="sm" variant="outline" :disabled="pagination.page === 1" @click="$emit('page-change', pagination.page - 1)">Sebelumnya</Button>
        <Button size="sm" variant="outline" :disabled="pagination.page * pagination.perPage >= pagination.total" @click="$emit('page-change', pagination.page + 1)">Selanjutnya</Button>
      </div>
    </div>
  </div>
</template>