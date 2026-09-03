<script setup>
import { ref, computed } from 'vue'

const toasts = ref([])
let idCounter = 0

function show(message, options = {}) {
  const id = ++idCounter
  const toast = {
    id,
    message,
    type: options.type || 'info', // success, error, warning, info
    duration: options.duration ?? 4000,
    action: options.action,
    onClose: () => remove(id),
  }
  toasts.value.push(toast)
  if (toast.duration > 0) setTimeout(() => remove(id), toast.duration)
  return id
}

function remove(id) {
  const idx = toasts.value.findIndex(t => t.id === id)
  if (idx > -1) toasts.value.splice(idx, 1)
}

function success(msg, opts) { return show(msg, { ...opts, type: 'success' }) }
function error(msg, opts) { return show(msg, { ...opts, type: 'error' }) }
function warning(msg, opts) { return show(msg, { ...opts, type: 'warning' }) }
function info(msg, opts) { return show(msg, { ...opts, type: 'info' }) }

const icons = {
  success: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
  error: 'M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z',
  warning: 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z',
  info: 'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
}

const bgColors = {
  success: 'bg-green-50 border-green-200',
  error: 'bg-red-50 border-red-200',
  warning: 'bg-yellow-50 border-yellow-200',
  info: 'bg-blue-50 border-blue-200',
}

const textColors = {
  success: 'text-green-800',
  error: 'text-red-800',
  warning: 'text-yellow-800',
  info: 'text-blue-800',
}

provide('toast', { show, success, error, warning, info })
</script>
<template>
  <div class="fixed bottom-6 right-6 z-[100] flex flex-col gap-2 w-80 max-w-full">
    <TransitionGroup name="toast">
      <div v-for="toast in toasts" :key="toast.id" :class="['flex items-start gap-3 p-4 rounded-xl border shadow-lg animate-slide-in', bgColors[toast.type]]">
        <svg :class="['w-5 h-5 flex-shrink-0 mt-0.5', textColors[toast.type]]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path :d="icons[toast.type]" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"/></svg>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium" :class="textColors[toast.type]">{{ toast.message }}</p>
          <button v-if="toast.action" :class="['mt-2 text-xs font-medium underline', textColors[toast.type]]" @click="toast.action.onClick">{{ toast.action.label }}</button>
        </div>
        <button @click="toast.onClose" class="flex-shrink-0 p-1 rounded hover:bg-black/10" :class="textColors[toast.type]">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
        </button>
      </div>
    </TransitionGroup>
  </div>
</template>

<style>
@keyframes slide-in { from { opacity: 0; transform: translateX(100%); } to { opacity: 1; transform: translateX(0); } }
.animate-slide-in { animation: slide-in 0.3s ease-out; }
.toast-leave-active { position: absolute; animation: slide-in 0.3s ease-in reverse; }
</style>