<script setup>
import { computed, onMounted, onUnmounted } from 'vue'
import { usePage } from '@inertiajs/vue3'
import { useAppLayout } from '@/Composables/useAppLayout'
import { useToast } from '@/Composables/useToast'
import AppSidebar from '@/Components/Layout/AppSidebar.vue'
import AppHeader from '@/Components/Layout/AppHeader.vue'
import ToastContainer from '@/Components/UI/ToastContainer.vue'

const page = usePage()
const { navItems, sidebarCollapsed, mobileSidebarOpen, toggleSidebar, closeMobileSidebar } = useAppLayout()
const { toasts, remove } = useToast()

const user = computed(() => page.props.auth?.user)
const canAccess = (item) => !item.roles || item.roles.some(r => user.value?.roles?.includes(r))
const filteredNav = computed(() => navItems.filter(canAccess))

function handleKeydown(e) {
  if (e.key.startsWith('F') && e.key.length <= 3) {
    const num = parseInt(e.key.slice(1))
    if (num >= 1 && num <= 12) {
      e.preventDefault()
      const item = filteredNav.value.find(i => i.shortcut === e.key)
      if (item) window.location.href = item.route
    }
  }
  if (e.key === 'Escape') closeMobileSidebar()
}

onMounted(() => window.addEventListener('keydown', handleKeydown))
onUnmounted(() => window.removeEventListener('keydown', handleKeydown))
</script>
<template>
  <div class="min-h-screen bg-background flex">
    <!-- Mobile Overlay -->
    <div
      v-if="mobileSidebarOpen"
      class="fixed inset-0 bg-black/50 z-40 lg:hidden"
      @click="closeMobileSidebar"
    />

    <!-- Sidebar -->
    <AppSidebar
      :items="filteredNav"
      :collapsed="sidebarCollapsed"
      :mobile-open="mobileSidebarOpen"
      @toggle="toggleSidebar"
    />

    <!-- Main Content - fix potong, tidak kosong -->
    <div class="flex-1 flex flex-col min-h-screen lg:ml-0" :class="{ 'lg:ml-64': !sidebarCollapsed, 'lg:ml-20': sidebarCollapsed }">
      <AppHeader
        :user="user"
        :sidebar-collapsed="sidebarCollapsed"
        @toggle-sidebar="toggleSidebar"
      />

      <main class="flex-1 p-4 lg:p-6 overflow-auto bg-muted/30 min-h-[calc(100vh-4rem)]">
        <slot name="header" />
        <slot />
      </main>

      <!-- Footer -->
      <footer class="bg-card border-t border-border px-4 sm:px-6 py-3 text-xs text-muted-foreground flex flex-col sm:flex-row justify-between gap-1 sm:gap-0">
        <span>© 2026 POSQUPRO • SIMPLE • SMART • SUCCESS</span>
        <div class="flex gap-4">
          <span class="hidden sm:inline">F1-F10: Shortcut</span>
          <span class="hidden sm:inline">Esc: Tutup Sidebar</span>
        </div>
      </footer>
    </div>

    <!-- Toast Container -->
    <ToastContainer :toasts="toasts" @remove="remove" />
  </div>
</template>