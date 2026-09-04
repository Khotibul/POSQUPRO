<script setup>
import { ref, computed } from 'vue'
import { usePage } from '@inertiajs/vue3'
import { BellIcon, MagnifyingGlassIcon } from '@heroicons/vue/24/outline'
import { Link } from '@inertiajs/vue3'
import { useAppLayout } from '@/Composables/useAppLayout'

const props = defineProps({
  user: { type: Object, default: null },
  sidebarCollapsed: { type: Boolean, default: false },
  isMobile: { type: Boolean, default: false },
})

defineEmits(['toggle-sidebar'])

const page = usePage()
const { shortcuts } = useAppLayout()

const searchQuery = ref('')
const showShortcuts = ref(false)
const showNotifications = ref(false)
const showUserMenu = ref(false)

const notifications = ref([
  { id: 1, title: 'Stok Rendah', message: '5 produk di bawah batas minimum', time: '5 menit lalu', type: 'warning' },
  { id: 2, title: 'Transaksi Berhasil', message: 'INV-20240830-001 selesai', time: '10 menit lalu', type: 'success' },
  { id: 3, title: 'PO Diterima', message: 'PO-20240830-ABC123 diterima penuh', time: '1 jam lalu', type: 'info' },
])
</script>
<template>
  <header class="sticky top-0 z-30 bg-card/95 backdrop-blur supports-[backdrop-filter]:bg-card/95 border-b border-border">
    <div class="flex items-center justify-between h-14 sm:h-16 px-4 lg:px-6">
      <!-- Left: Hamburger + Search -->
      <div class="flex items-center gap-3">
        <!-- Hamburger: always visible on mobile, hidden on desktop -->
        <button @click="$emit('toggle-sidebar')" class="p-2 rounded-md text-muted-foreground hover:bg-accent hover:text-accent-foreground lg:hidden">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/></svg>
        </button>
        <!-- Desktop collapse toggle -->
        <button @click="$emit('toggle-sidebar')" class="hidden lg:block p-2 rounded-md text-muted-foreground hover:bg-accent hover:text-accent-foreground">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/></svg>
        </button>

        <div class="relative hidden sm:block w-64 lg:w-80">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <input
            type="text"
            v-model="searchQuery"
            placeholder="Cari produk, transaksi... (Ctrl+K)"
            class="w-full pl-10 pr-4 py-2 bg-muted border border-input rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent placeholder:text-muted-foreground"
            @keydown.ctrl.k.prevent
          />
        </div>
      </div>

      <!-- Center: Page Title -->
      <div class="flex-1 flex items-center justify-center lg:justify-start px-4">
        <h1 class="text-sm sm:text-lg font-semibold text-foreground truncate">{{ $page.props.title || 'POSQUPRO' }}</h1>
      </div>

      <!-- Right: Shortcuts, Notifications, User -->
      <div class="flex items-center gap-1 sm:gap-2">
        <!-- Keyboard Shortcuts (desktop only) -->
        <div class="relative hidden lg:block">
          <button @click="showShortcuts = !showShortcuts" class="p-2 rounded-lg text-muted-foreground hover:bg-accent hover:text-accent-foreground transition-colors" title="Shortcut Keyboard">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/></svg>
          </button>
          <div v-if="showShortcuts" @click="showShortcuts = false" class="fixed inset-0 z-40"></div>
          <div v-if="showShortcuts" class="absolute right-0 top-full mt-2 w-56 bg-popover border border-border rounded-lg shadow-lg p-3 z-50">
            <p class="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-2">Shortcut Cepat</p>
            <div class="space-y-1 text-xs">
              <div v-for="s in shortcuts" :key="s.key" class="flex justify-between text-muted-foreground">
                <span>{{ s.label }}</span>
                <kbd class="px-1.5 py-0.5 bg-muted rounded text-foreground font-mono">{{ s.key }}</kbd>
              </div>
            </div>
          </div>
        </div>

        <!-- Notifications -->
        <div class="relative">
          <button @click="showNotifications = !showNotifications" class="relative p-2 rounded-lg text-muted-foreground hover:bg-accent hover:text-accent-foreground transition-colors">
            <BellIcon class="w-5 h-5" />
            <span v-if="notifications.length" class="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-500 text-white text-[10px] rounded-full flex items-center justify-center font-medium">{{ notifications.length }}</span>
          </button>
          <div v-if="showNotifications" @click="showNotifications = false" class="fixed inset-0 z-40"></div>
          <div v-if="showNotifications" class="absolute right-0 top-full mt-2 w-72 sm:w-80 bg-popover border border-border rounded-lg shadow-lg z-50 max-h-96 overflow-auto">
            <div class="px-4 py-3 border-b border-border flex items-center justify-between">
              <h3 class="font-semibold text-foreground text-sm">Notifikasi</h3>
              <button @click="showNotifications = false" class="text-muted-foreground hover:text-foreground">&times;</button>
            </div>
            <div class="py-1">
              <div v-for="n in notifications" :key="n.id" class="px-4 py-3 hover:bg-accent border-b border-border/50 last:border-0">
                <div class="flex items-start gap-3">
                  <div :class="['w-2 h-2 rounded-full mt-1.5 flex-shrink-0', n.type === 'success' ? 'bg-green-500' : n.type === 'warning' ? 'bg-yellow-500' : n.type === 'error' ? 'bg-red-500' : 'bg-blue-500']" />
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-foreground">{{ n.title }}</p>
                    <p class="text-xs text-muted-foreground">{{ n.message }}</p>
                    <p class="text-xs text-muted-foreground/60 mt-1">{{ n.time }}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- User Menu -->
        <div class="relative">
          <button @click="showUserMenu = !showUserMenu" class="flex items-center gap-2 p-1.5 rounded-lg hover:bg-accent hover:text-accent-foreground transition-colors">
            <div class="w-7 h-7 sm:w-8 sm:h-8 bg-primary/10 rounded-full flex items-center justify-center flex-shrink-0">
              <svg class="w-4 h-4 sm:w-5 sm:h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
            </div>
            <span class="hidden md:block text-sm font-medium text-foreground max-w-[120px] truncate">{{ user?.name }}</span>
          </button>
          <div v-if="showUserMenu" @click="showUserMenu = false" class="fixed inset-0 z-40"></div>
          <div v-if="showUserMenu" class="absolute right-0 top-full mt-2 w-52 bg-popover border border-border rounded-lg shadow-lg py-1 z-50">
            <div class="px-4 py-3 border-b border-border">
              <p class="text-sm font-medium text-foreground">{{ user?.name }}</p>
              <p class="text-xs text-muted-foreground truncate">{{ user?.email }}</p>
              <span class="inline-flex mt-1 px-2 py-0.5 text-xs bg-primary/10 text-primary rounded-full">{{ user?.roles?.[0] || 'User' }}</span>
            </div>
            <div class="py-1">
              <Link href="/settings" @click="showUserMenu = false" class="flex items-center gap-2 px-4 py-2 text-sm text-foreground hover:bg-accent">
                <svg class="w-4 h-4 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                Pengaturan
              </Link>
              <Link href="/logout" method="post" as="button" @click="showUserMenu = false" class="flex items-center gap-2 w-full text-left px-4 py-2 text-sm text-destructive hover:bg-destructive/10">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/></svg>
                Keluar
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  </header>
</template>
