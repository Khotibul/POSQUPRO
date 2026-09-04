<script setup>
import { computed } from 'vue'
const props = defineProps({
  modelValue: { type: [String, Number], default: '' },
  label: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  type: { type: String, default: 'text' },
  disabled: { type: Boolean, default: false },
  required: { type: Boolean, default: false },
  error: { type: String, default: '' },
  hint: { type: String, default: '' },
  icon: { type: String, default: '' },
  autocomplete: { type: String, default: 'off' },
  readonly: { type: Boolean, default: false },
  maxLength: { type: Number, default: 0 },
})

const emit = defineEmits(['update:modelValue', 'blur', 'focus'])

const inputClasses = computed(() => `
  w-full px-3 py-2 rounded-lg border transition-colors duration-200
  focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent
  disabled:bg-gray-50 disabled:cursor-not-allowed
  ${props.error ? 'border-red-300 text-red-900 placeholder-red-300 focus:ring-red-500' : 'border-gray-300'}
  ${props.icon ? 'pl-10' : ''}
  ${props.readonly ? 'bg-gray-50' : ''}
`)
</script>
<template>
  <div class="w-full">
    <label v-if="props.label" class="block text-sm font-medium text-gray-700 mb-1.5">
      {{ props.label }} <span v-if="props.required" class="text-red-500">*</span>
    </label>
    <div class="relative">
      <component v-if="props.icon" :is="props.icon" class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
      <input
        :type="props.type"
        :value="props.modelValue"
        :placeholder="props.placeholder"
        :disabled="props.disabled"
        :required="props.required"
        :readonly="props.readonly"
        :autocomplete="props.autocomplete"
        :maxlength="props.maxLength || undefined"
        :class="inputClasses"
        @input="e => emit('update:modelValue', e.target.value)"
        @blur="e => emit('blur', e)"
        @focus="e => emit('focus', e)"
      />
    </div>
    <p v-if="props.error" class="mt-1 text-sm text-red-600">{{ props.error }}</p>
    <p v-else-if="props.hint" class="mt-1 text-sm text-gray-500">{{ props.hint }}</p>
    <p v-if="props.maxLength && !props.error" class="mt-1 text-xs text-gray-400 text-right">
      {{ props.modelValue.toString().length }}/{{ props.maxLength }}
    </p>
  </div>
</template>