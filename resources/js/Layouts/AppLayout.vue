<script setup>
import { computed, onMounted, onUnmounted } from 'vue'
import { usePage } from '@inertiajs/vue3'
import { useAppLayout } from '@/Composables/useAppLayout'
import { useToast } from '@/Composables/useToast'
import AppSidebar from '@/Components/Layout/AppSidebar.vue'
import AppHeader from '@/Components/Layout/AppHeader.vue'
import ToastContainer from '@/Components/UI/ToastContainer.vue'

const page = usePage()
const { navItems, sidebarCollapsed, mobileSidebarOpen, isMobile, toggleSidebar, closeMobileSidebar } = useAppLayout()
const { toasts, remove } = useToast()

const user = computed(() => page.props.auth?.user)
const canAccess = (item) => !item.roles || item.roles.some(r => user.value?.roles?.includes(r))
const filteredNav = computed(() => navItems.filter(canAccess))

function handleKeydown(e) {
  if (!isMobile.value && e.key.startsWith('F') && e.key.length <= 3) {
    const num = parseInt(e.key.slice(1))
    if (num >= 1 && num <= 12) {
      e.preventDefault()
      const item = filteredNav.value.find(i => i.shortcut === e.key)
      if (item) window.location.href = item.route
    }
  }
  if (e.key === 'Escape' && mobileSidebarOpen.value) closeMobileSidebar()
}

// Close mobile sidebar on Inertia navigation
function handleInertiaStart() {
  if (isMobile.value) closeMobileSidebar()
}

onMounted(() => {
  window.addEventListener('keydown', handleKeydown)
  page.on('start', handleInertiaStart)
})
onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown)
  page.on('start', handleInertiaStart)
})
</script>
<template>
  <div class="min-h-screen bg-background flex">
    <!-- Sidebar (includes its own overlay on mobile) -->
    <AppSidebar
      :items="filteredNav"
      :collapsed="sidebarCollapsed"
      :mobile-open="mobileSidebarOpen"
      :is-mobile="isMobile"
      @toggle="toggleSidebar"
      @close="closeMobileSidebar"
    />

    <!-- Main Content -->
    <div class="flex-1 flex flex-col min-h-screen transition-[margin] duration-300"
         :class="isMobile ? '' : (sidebarCollapsed ? 'lg:ml-20' : 'lg:ml-64')">
      <AppHeader
        :user="user"
        :sidebar-collapsed="sidebarCollapsed"
        :is-mobile="isMobile"
        @toggle-sidebar="toggleSidebar"
      />

      <main class="flex-1 p-4 lg:p-6 overflow-auto bg-muted/30 min-h-[calc(100vh-4rem)]">
        <slot name="header" />
        <slot />
      </main>

      <!-- Footer -->
      <footer class="bg-card border-t border-border px-4 sm:px-6 py-3 text-xs text-muted-foreground flex flex-col sm:flex-row justify-between gap-1 sm:gap-0">
        <span>&copy; 2026 POSQUPRO &bull; SIMPLE &bull; SMART &bull; SUCCESS</span>
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
