<script setup>
import { computed, onMounted, onUnmounted } from 'vue'
import { usePage, router } from '@inertiajs/vue3'
import { useAppLayout } from '@/Composables/useAppLayout'
import { useToast } from '@/Composables/useToast'
import AppSidebar from '@/Components/Layout/AppSidebar.vue'
import AppHeader from '@/Components/Layout/AppHeader.vue'
import ToastContainer from '@/Components/UI/ToastContainer.vue'

const page = usePage()

let removeInertiaStartListener = null

const {
  navItems,
  sidebarCollapsed,
  mobileSidebarOpen,
  isMobile,
  toggleSidebar,
  closeMobileSidebar
} = useAppLayout()

const { toasts, remove } = useToast()

const user = computed(() => page.props.auth?.user)

const tenant = computed(() => page.props.tenant)
const planFeatures = computed(() => page.props.tenant?.features || null)

const canAccess = (item) =>
  !item.roles || item.roles.some(r => user.value?.roles?.includes(r))

const canUseFeature = (item) =>
  !item.feature || !planFeatures.value || planFeatures.value.includes(item.feature)

const filteredNav = computed(() => navItems.filter(item => canAccess(item) && canUseFeature(item)))

const showSubscriptionBanner = computed(() => {
  if (!tenant.value) return false
  if (page.url.startsWith('/billing')) return false
  return tenant.value.is_trial || tenant.value.is_expired || tenant.value.status === 'suspended'
})

const subscriptionMessage = computed(() => {
  if (!tenant.value) return ''
  if (tenant.value.status === 'suspended') return 'Akun tenant ditangguhkan. Hubungi administrator.'
  if (tenant.value.is_expired) return 'Masa demo/langganan berakhir. Pilih paket untuk melanjutkan.'
  const days = tenant.value.subscription?.days_remaining ?? 0
  return `Demo tersisa ${days} hari. Semua fitur terbuka.`
})

function handleKeydown(e) {
  if (!isMobile.value && e.key.startsWith('F') && e.key.length <= 3) {
    const num = parseInt(e.key.slice(1))

    if (num >= 1 && num <= 12) {
      e.preventDefault()

      const item = filteredNav.value.find(i => i.shortcut === e.key)

      if (item) {
        window.location.href = item.route
      }
    }
  }

  if (e.key === 'Escape' && mobileSidebarOpen.value) {
    closeMobileSidebar()
  }
}

function handleInertiaStart() {
  if (isMobile.value) {
    closeMobileSidebar()
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleKeydown)

  removeInertiaStartListener = router.on(
    'start',
    handleInertiaStart
  )
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown)

  if (removeInertiaStartListener) {
    removeInertiaStartListener()
    removeInertiaStartListener = null
  }
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
        <div
          v-if="showSubscriptionBanner"
          class="mb-4 flex flex-col sm:flex-row sm:items-center justify-between gap-2 rounded-xl px-4 py-3 text-sm"
          :class="tenant.is_expired || tenant.status === 'suspended' ? 'bg-red-50 text-red-800 border border-red-200' : 'bg-amber-50 text-amber-800 border border-amber-200'"
        >
          <span>{{ subscriptionMessage }}</span>
          <a href="/billing" class="font-semibold underline whitespace-nowrap">Kelola langganan</a>
        </div>

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
