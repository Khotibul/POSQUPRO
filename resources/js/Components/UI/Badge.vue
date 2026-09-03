<script setup>
defineProps({
  label: { type: String, default: '' },
  variant: { type: String, default: 'default' }, // default, success, warning, danger, info, primary
  size: { type: String, default: 'md' }, // sm, md, lg
  dot: { type: Boolean, default: false },
  removable: { type: Boolean, default: false },
  icon: { type: String, default: '' },
})

const variantClasses = {
  default: 'bg-gray-100 text-gray-700',
  success: 'bg-green-100 text-green-700',
  warning: 'bg-yellow-100 text-yellow-700',
  danger: 'bg-red-100 text-red-700',
  info: 'bg-blue-100 text-blue-700',
  primary: 'bg-indigo-100 text-indigo-700',
}

const sizeClasses = {
  sm: 'px-2 py-0.5 text-xs',
  md: 'px-2.5 py-1 text-sm',
  lg: 'px-3 py-1.5 text-base',
}

const dotColors = {
  default: 'bg-gray-400',
  success: 'bg-green-500',
  warning: 'bg-yellow-500',
  danger: 'bg-red-500',
  info: 'bg-blue-500',
  primary: 'bg-indigo-500',
}
</script>
<template>
  <span :class="['inline-flex items-center gap-1.5 rounded-full font-medium', variantClasses[variant], sizeClasses[size]]">
    <span v-if="dot" :class="['w-1.5 h-1.5 rounded-full', dotColors[variant]]" />
    <component v-else-if="icon" :is="icon" class="w-3.5 h-3.5" />
    <span>{{ label }}</span>
    <button v-if="removable" @click="$emit('remove')" class="ml-1.5 p-0.5 rounded hover:bg-black/10">×</button>
  </span>
</template>