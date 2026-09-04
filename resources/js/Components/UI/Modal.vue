<script setup>
import { onMounted, onUnmounted, watch } from 'vue'
import Button from './Button.vue'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  title: { type: String, default: '' },
  size: { type: String, default: 'md' },
  closable: { type: Boolean, default: true },
  closeOnOverlay: { type: Boolean, default: true },
  showFooter: { type: Boolean, default: true },
  loading: { type: Boolean, default: false },
})

const emit = defineEmits(['update:modelValue', 'confirm', 'cancel'])

const sizeClasses = {
  sm: 'max-w-sm',
  md: 'max-w-md',
  lg: 'max-w-lg',
  xl: 'max-w-xl',
  '2xl': 'max-w-2xl',
  '3xl': 'max-w-3xl',
  '4xl': 'max-w-4xl',
  full: 'max-w-full mx-4',
}

function close() { emit('update:modelValue', false) }
function handleKeydown(e) { if (e.key === 'Escape') close() }

onMounted(() => { if (props.modelValue) document.body.style.overflow = 'hidden' })
onUnmounted(() => { document.body.style.overflow = '' })
watch(() => props.modelValue, v => { document.body.style.overflow = v ? 'hidden' : '' })
</script>
<template>
  <Transition name="fade">
    <div v-if="modelValue" class="fixed inset-0 z-50 overflow-y-auto" @keydown="handleKeydown">
      <div class="flex min-h-full items-center justify-center p-4">
        <Transition name="zoom">
          <div class="fixed inset-0 bg-black/50" @click="closeOnOverlay && close" />
        </Transition>
        <div :class="['relative w-full bg-white rounded-xl shadow-xl', sizeClasses[size]]">
          <div v-if="title || closable" class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900">{{ title }}</h3>
            <button v-if="closable" @click="close" class="p-1 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>
          <div class="px-6 py-4 overflow-y-auto" style="max-height: 70vh;">
            <slot />
          </div>
          <div v-if="showFooter" class="px-6 py-4 border-t border-gray-100 flex justify-end gap-3">
            <slot name="footer">
              <Button variant="ghost" @click="close">Batal</Button>
              <Button @click="$emit('confirm')">Simpan</Button>
            </slot>
          </div>
        </div>
      </div>
    </div>
  </Transition>
</template>