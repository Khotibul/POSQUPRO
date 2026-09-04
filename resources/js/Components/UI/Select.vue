<script setup>
import { ref, computed } from 'vue'
const props = defineProps({
  modelValue: { type: [String, Number, Array], default: '' },
  label: { type: String, default: '' },
  placeholder: { type: String, default: 'Pilih...' },
  options: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
  required: { type: Boolean, default: false },
  error: { type: String, default: '' },
  hint: { type: String, default: '' },
  multiple: { type: Boolean, default: false },
  searchable: { type: Boolean, default: false },
  clearable: { type: Boolean, default: false },
})

const emit = defineEmits(['update:modelValue', 'change'])
const isOpen = ref(false)
const searchQuery = ref('')
const selectedOption = computed(() => {
  if (props.multiple) {
    return props.options.filter(o => (props.modelValue || []).includes(o.value))
  }
  return props.options.find(o => o.value == props.modelValue)
})

function toggle() { if (!props.disabled) isOpen.value = !isOpen.value }
function select(opt) {
  if (opt.disabled) return
  if (props.multiple) {
    const vals = [...(props.modelValue || [])]
    const idx = vals.indexOf(opt.value)
    if (idx > -1) vals.splice(idx, 1)
    else vals.push(opt.value)
    emit('update:modelValue', vals)
  } else {
    emit('update:modelValue', opt.value)
    isOpen.value = false
  }
  emit('change', opt)
}
function clear() { emit('update:modelValue', props.multiple ? [] : '') }
const filteredOptions = computed(() => props.options.filter(o =>
  o.label.toLowerCase().includes(searchQuery.value.toLowerCase())
))
</script>
<template>
  <div class="relative w-full">
    <label v-if="label" class="block text-sm font-medium text-gray-700 mb-1.5">
      {{ label }} <span v-if="required" class="text-red-500">*</span>
    </label>
    <div class="relative">
      <div
        class="w-full px-3 py-2 rounded-lg border border-gray-300 bg-white cursor-pointer hover:border-indigo-400 focus-within:ring-2 focus-within:ring-indigo-500 transition-colors disabled:bg-gray-50"
        :class="error ? 'border-red-300' : ''"
        @click="toggle"
      >
        <div class="flex items-center justify-between">
          <div class="flex-1 flex flex-wrap gap-1.5 min-h-[38px] items-center">
            <span v-if="multiple && Array.isArray(modelValue) && modelValue.length > 0" class="flex flex-wrap gap-1.5">
              <span v-for="opt in selectedOption" :key="opt.value" class="inline-flex items-center px-2 py-0.5 rounded text-xs bg-indigo-100 text-indigo-700">
                {{ opt.label }}
                <button type="button" @click.stop="select(opt)" class="ml-1 hover:text-indigo-900">×</button>
              </span>
            </span>
            <span v-else-if="!multiple && selectedOption" class="text-gray-900">{{ selectedOption.label }}</span>
            <span v-else class="text-gray-400">{{ placeholder }}</span>
          </div>
          <div class="flex items-center gap-2">
            <svg class="w-5 h-5 text-gray-400" :class="{ 'rotate-180': isOpen }" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
            <button v-if="clearable && (multiple ? modelValue.length : modelValue)" @click.stop="clear" class="text-gray-400 hover:text-gray-600">×</button>
          </div>
        </div>
      </div>
      <div v-if="isOpen" class="fixed z-50 w-full mt-1 max-h-60 overflow-auto rounded-lg border border-gray-200 bg-white shadow-lg" style="z-index: 9999;">
        <input v-if="searchable" type="text" v-model="searchQuery" placeholder="Cari..." class="w-full px-3 py-2 border-b border-gray-100 focus:outline-none" @click.stop />
        <div class="py-1 max-h-[300px] overflow-auto">
          <div v-for="opt in filteredOptions" :key="opt.value"
            class="px-3 py-2 hover:bg-indigo-50 cursor-pointer flex items-center gap-2"
            :class="{ 'opacity-50': opt.disabled }"
            @click="select(opt)"
          >
            <input v-if="multiple" type="checkbox" :checked="(modelValue || []).includes(opt.value)" class="w-4 h-4 text-indigo-600 rounded" />
            <span :class="opt.disabled ? 'text-gray-400' : 'text-gray-900'">{{ opt.label }}</span>
          </div>
          <div v-if="filteredOptions.length === 0" class="px-3 py-2 text-gray-500 text-center">Tidak ada opsi</div>
        </div>
      </div>
    </div>
    <p v-if="error" class="mt-1 text-sm text-red-600">{{ error }}</p>
    <p v-else-if="hint" class="mt-1 text-sm text-gray-500">{{ hint }}</p>
  </div>
</template>