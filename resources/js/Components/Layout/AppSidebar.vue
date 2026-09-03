<script setup>
import { Link } from '@inertiajs/vue3'
import { computed } from 'vue'
import {
  HomeIcon, CreditCardIcon, PauseCircleIcon, CubeIcon, ArchiveBoxIcon,
  DocumentTextIcon, UsersIcon, TruckIcon, ShoppingBagIcon,
  ClipboardDocumentListIcon, BanknotesIcon, ChartBarIcon,
  Cog6ToothIcon, UserGroupIcon, ChevronLeftIcon, ChevronRightIcon,
  TagIcon, ScaleIcon, ReceiptPercentIcon, BuildingStorefrontIcon, BuildingOffice2Icon
} from '@heroicons/vue/24/outline'

const props = defineProps({
  items: { type: Array, required: true },
  collapsed: { type: Boolean, default: false },
  mobileOpen: { type: Boolean, default: false },
})

const emit = defineEmits(['toggle'])

const iconMap = {
  HomeIcon, CreditCardIcon, PauseCircleIcon, CubeIcon, ArchiveBoxIcon,
  DocumentTextIcon, UsersIcon, TruckIcon, ShoppingBagIcon,
  ClipboardDocumentListIcon, BanknotesIcon, ChartBarIcon,
  Cog6ToothIcon, UserGroupIcon, TagIcon, ScaleIcon, ReceiptPercentIcon, BuildingStorefrontIcon, BuildingOffice2Icon,
}

const sidebarWidth = computed(() => (props.collapsed ? 'w-20' : 'w-64'))
const sidebarClasses = computed(() => `
  fixed inset-y-0 left-0 z-50 bg-card border-r border-border flex flex-col h-screen transition-all duration-300 ease-in-out
  ${sidebarWidth.value}
  ${props.mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0 lg:translate-x-0'}
`)
</script>
<template>
  <aside :class="sidebarClasses" aria-label="Sidebar navigation">
    <!-- Logo POSQUPRO Baru -->
    <div class="flex items-center justify-between h-16 px-4 border-b border-border bg-card">
      <div class="flex items-center gap-2" v-if="!collapsed">
        <img src="/logo.png" alt="POSQUPRO" class="h-9 w-auto object-contain" />
      </div>
      <div v-else class="flex justify-center w-full">
        <img src="/logo.png" alt="POSQUPRO" class="h-8 w-8 object-contain rounded-lg" />
      </div>
      <button @click="emit('toggle')" class="p-1.5 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 lg:hidden">
        <ChevronLeftIcon class="w-5 h-5" v-if="!collapsed" />
        <ChevronRightIcon class="w-5 h-5" v-else />
      </button>
    </div>

    <!-- Navigation pos-next-js shadcn -->
    <nav class="flex-1 overflow-y-auto px-2 py-4 space-y-1" v-if="!collapsed">
      <template v-for="item in items" :key="item.name">
        <Link
          :href="item.route"
          class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-muted-foreground hover:bg-accent hover:text-accent-foreground transition-colors"
          :class="{ 'bg-primary text-primary-foreground hover:bg-primary/90': $page.url.startsWith(item.route) }"
        >
          <component :is="iconMap[item.icon]" class="w-5 h-5 flex-shrink-0" />
          <span>{{ item.label }}</span>
          <span v-if="item.shortcut" class="ml-auto px-1.5 py-0.5 text-xs bg-muted rounded text-muted-foreground">{{ item.shortcut }}</span>
        </Link>
      </template>
    </nav>

    <!-- Collapsed Navigation -->
    <nav v-else class="flex-1 overflow-y-auto px-2 py-4 space-y-1">
      <template v-for="item in items" :key="item.name">
        <Link
          :href="item.route"
          class="flex items-center justify-center px-3 py-2.5 rounded-lg text-muted-foreground hover:bg-accent hover:text-accent-foreground transition-colors relative group"
          :class="{ 'bg-primary text-primary-foreground': $page.url.startsWith(item.route) }"
          :title="item.label"
        >
          <component :is="iconMap[item.icon]" class="w-5 h-5" />
          <span class="absolute left-full top-1/2 -translate-y-1/2 ml-3 px-2 py-1 bg-popover text-popover-foreground border border-border text-xs rounded-md shadow-md whitespace-nowrap opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all">
            {{ item.label }}
          </span>
        </Link>
      </template>
    </nav>

    <!-- User Info shadcn -->
    <div class="p-4 border-t border-border" v-if="!collapsed">
      <div class="flex items-center gap-3 px-2 py-2">
        <div class="w-8 h-8 bg-primary/10 rounded-full flex items-center justify-center flex-shrink-0">
          <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-foreground truncate">{{ $page.props.auth?.user?.name }}</p>
          <p class="text-xs text-muted-foreground truncate">{{ $page.props.auth?.user?.roles?.[0] }}</p>
        </div>
      </div>
      <Link href="/logout" method="post" as="button" class="w-full flex items-center gap-2 px-3 py-2 text-sm text-destructive hover:bg-destructive/10 rounded-lg transition-colors">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/></svg>
        Keluar
      </Link>
    </div>
  </aside>
</template>