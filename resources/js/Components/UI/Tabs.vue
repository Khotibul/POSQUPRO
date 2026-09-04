<script setup>
const props = defineProps({
  tabs: { type: Array, required: true },
  modelValue: { type: String, required: true },
})

const emit = defineEmits(['update:modelValue'])
</script>
<template>
  <div class="border-b border-gray-200 overflow-x-auto">
    <nav class="flex gap-1 px-2" aria-label="Tabs">
      <button
        v-for="tab in props.tabs"
        :key="tab.id"
        @click="$emit('update:modelValue', tab.id)"
        :class="[
          'flex items-center gap-2 px-4 py-2.5 text-sm font-medium rounded-lg transition-colors whitespace-nowrap',
          props.modelValue === tab.id
            ? 'bg-indigo-50 text-indigo-700 border-b-2 border-indigo-600 -mb-px'
            : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50',
        ]"
      >
        <component v-if="tab.icon" :is="tab.icon" class="w-4 h-4" />
        {{ tab.label }}
      </button>
    </nav>
  </div>
</template>