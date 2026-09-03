import { ref } from 'vue'

const toasts = ref([])

export function useToast() {
  function show(message, options = {}) {
    const id = Date.now() + Math.random()
    const toast = {
      id,
      message,
      type: options.type || 'info',
      duration: options.duration ?? 4000,
      action: options.action,
    }
    toasts.value.push(toast)
    if (toast.duration > 0) setTimeout(() => remove(id), toast.duration)
    return id
  }

  function remove(id) {
    const idx = toasts.value.findIndex(t => t.id === id)
    if (idx > -1) toasts.value.splice(idx, 1)
  }

  return {
    toasts,
    show,
    remove,
    success: (msg, opts) => show(msg, { ...opts, type: 'success' }),
    error: (msg, opts) => show(msg, { ...opts, type: 'error' }),
    warning: (msg, opts) => show(msg, { ...opts, type: 'warning' }),
    info: (msg, opts) => show(msg, { ...opts, type: 'info' }),
  }
}