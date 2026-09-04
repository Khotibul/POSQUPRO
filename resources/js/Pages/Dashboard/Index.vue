<script setup>
import { ref, computed, onMounted } from 'vue'
import { Link, usePage, router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Badge from '@/Components/UI/Badge.vue'
import Button from '@/Components/UI/Button.vue'
import {
  HomeIcon, CreditCardIcon, CubeIcon, ArchiveBoxIcon,
  ChartBarIcon, ArrowTrendingUpIcon, CurrencyDollarIcon,
  ShoppingBagIcon, ClipboardDocumentListIcon, BanknotesIcon,
  ExclamationTriangleIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  stats: {
    type: Object,
    default: () => ({
      today_revenue: 0,
      today_transactions: 0,
      month_revenue: 0,
      month_transactions: 0,
      low_stock_count: 0,
      total_products: 0,
      total_customers: 0,
      pending_pos: 0,
    })
  },
  recentTransactions: { type: Array, default: () => [] },
  lowStockProducts: { type: Array, default: () => [] },
  chartData: { type: Object, default: () => ({ daily: [], hourly: [] }) },
})

const statsCards = [
  { label: 'Hari Ini', value: 'today_revenue', icon: CurrencyDollarIcon, color: 'text-green-600', bg: 'bg-green-50 dark:bg-green-950', format: 'currency' },
  { label: 'Transaksi', value: 'today_transactions', icon: CreditCardIcon, color: 'text-blue-600', bg: 'bg-blue-50 dark:bg-blue-950', format: 'number' },
  { label: 'Bulan Ini', value: 'month_revenue', icon: ArrowTrendingUpIcon, color: 'text-indigo-600', bg: 'bg-indigo-50 dark:bg-indigo-950', format: 'currency' },
  { label: 'Stok Rendah', value: 'low_stock_count', icon: ExclamationTriangleIcon, color: 'text-red-600', bg: 'bg-red-50 dark:bg-red-950', format: 'number' },
]

const quickActions = [
  { label: 'POS', route: '/pos', icon: CreditCardIcon, color: 'bg-indigo-100 text-indigo-600', roles: ['Cashier', 'Super Admin', 'Admin'] },
  { label: 'Produk', route: '/products/create', icon: CubeIcon, color: 'bg-green-100 text-green-600', roles: ['Warehouse Manager', 'Super Admin', 'Admin'] },
  { label: 'Stok Opname', route: '/stock-counts', icon: ClipboardDocumentListIcon, color: 'bg-yellow-100 text-yellow-600', roles: ['Warehouse Manager', 'Super Admin', 'Admin'] },
  { label: 'PO', route: '/purchase-orders', icon: ShoppingBagIcon, color: 'bg-purple-100 text-purple-600', roles: ['Warehouse Manager', 'Super Admin', 'Admin'] },
  { label: 'Laporan', route: '/reports', icon: ChartBarIcon, color: 'bg-blue-100 text-blue-600', roles: ['Super Admin', 'Admin', 'Finance'] },
  { label: 'Kasir', route: '/register', icon: BanknotesIcon, color: 'bg-pink-100 text-pink-600', roles: ['Cashier', 'Super Admin', 'Admin'] },
]

const user = computed(() => page.props.auth?.user)
const canAccess = (item) => !item.roles || item.roles.some(r => user.value?.roles?.includes(r))
const filteredActions = computed(() => quickActions.filter(canAccess))

function formatValue(val, fmt) {
  if (fmt === 'currency') return 'Rp ' + Number(val).toLocaleString('id-ID')
  return Number(val).toLocaleString('id-ID')
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-xl sm:text-2xl font-bold text-foreground">Dashboard</h1>
          <p class="text-xs sm:text-sm text-muted-foreground mt-0.5">Selamat datang kembali, {{ user?.name }}</p>
        </div>
        <span class="px-2 sm:px-3 py-1 text-xs sm:text-sm bg-indigo-100 text-indigo-700 rounded-full">{{ user?.roles?.[0] }}</span>
      </div>
    </template>

    <!-- Stats Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 mb-4 sm:mb-6">
      <Card v-for="stat in statsCards" :key="stat.value" class="hover:shadow-md transition-shadow">
        <div class="flex items-center gap-3 sm:gap-4">
          <div :class="['w-10 h-10 sm:w-12 sm:h-12 rounded-xl flex items-center justify-center flex-shrink-0', stat.bg]">
            <component :is="stat.icon" :class="['w-5 h-5 sm:w-6 sm:h-6', stat.color]" />
          </div>
          <div class="min-w-0">
            <p class="text-xs sm:text-sm font-medium text-muted-foreground truncate">{{ stat.label }}</p>
            <p class="text-lg sm:text-2xl font-bold text-foreground truncate">{{ formatValue(props.stats[stat.value], stat.format) }}</p>
          </div>
        </div>
      </Card>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 sm:gap-6">
      <!-- Quick Actions -->
      <Card title="Aksi Cepat" class="lg:col-span-1">
        <div class="grid grid-cols-3 sm:grid-cols-2 gap-2 sm:gap-3">
          <button
            v-for="action in filteredActions"
            :key="action.label"
            @click="router.visit(action.route)"
            class="flex flex-col items-center gap-1.5 sm:gap-2 p-3 sm:p-4 rounded-xl border border-border hover:border-indigo-300 hover:bg-accent transition-colors text-center"
          >
            <div :class="['w-9 h-9 sm:w-10 sm:h-10 rounded-lg flex items-center justify-center', action.color]">
              <component :is="action.icon" class="w-4 h-4 sm:w-5 sm:h-5 text-white" />
            </div>
            <span class="text-xs sm:text-sm font-medium text-gray-700">{{ action.label }}</span>
          </button>
        </div>
      </Card>

      <!-- Recent Transactions -->
      <Card title="Transaksi Terbaru" subtitle="5 transaksi terakhir" class="lg:col-span-2">
        <div v-if="recentTransactions.length === 0" class="text-center py-8 text-muted-foreground">
          <CreditCardIcon class="w-10 h-10 sm:w-12 sm:h-12 mx-auto text-gray-300 mb-2" />
          <p class="text-sm">Belum ada transaksi hari ini</p>
        </div>
        <div v-else class="space-y-2 sm:space-y-3">
          <div v-for="tx in recentTransactions.slice(0, 5)" :key="tx.id" class="flex items-center justify-between p-2.5 sm:p-3 rounded-lg hover:bg-muted transition-colors gap-2">
            <div class="flex items-center gap-2.5 sm:gap-3 min-w-0">
              <div class="w-8 h-8 bg-indigo-100 rounded-lg flex items-center justify-center flex-shrink-0">
                <CreditCardIcon class="w-4 h-4 text-indigo-600" />
              </div>
              <div class="min-w-0">
                <p class="font-medium text-foreground text-sm truncate">{{ tx.invoice_number }}</p>
                <p class="text-xs text-muted-foreground truncate">{{ tx.customer?.name || 'Umum' }} • {{ new Date(tx.created_at).toLocaleString('id-ID') }}</p>
              </div>
            </div>
            <div class="text-right flex-shrink-0">
              <p class="font-semibold text-foreground text-sm">Rp {{ Number(tx.total).toLocaleString('id-ID') }}</p>
              <Badge :variant="tx.status === 'completed' ? 'success' : tx.status === 'pending' ? 'warning' : 'danger'" :label="tx.status" size="sm" />
            </div>
          </div>
          <Link href="/transactions" class="block text-center text-sm text-indigo-600 hover:text-indigo-700 mt-2">Lihat semua →</Link>
        </div>
      </Card>
    </div>

    <!-- Low Stock Alert -->
    <div v-if="lowStockProducts.length > 0" class="mt-4 sm:mt-6">
      <Card title="⚠ Stok Rendah" :headerAction="{ label: 'Lihat Semua', variant: 'ghost', onClick: () => router.visit('/inventory') }">
        <div class="overflow-x-auto -mx-6 px-6">
          <table class="w-full min-w-[500px]">
            <thead class="bg-muted">
              <tr><th class="px-4 py-2 text-left text-xs font-semibold text-muted-foreground">Produk</th><th class="px-4 py-2 text-center text-xs font-semibold text-muted-foreground">Stok</th><th class="px-4 py-2 text-center text-xs font-semibold text-muted-foreground">Min</th><th class="px-4 py-2 text-right text-xs font-semibold text-muted-foreground">Selisih</th></tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr v-for="p in lowStockProducts.slice(0, 10)" :key="p.id" class="hover:bg-muted">
                <td class="px-4 py-2.5">
                  <p class="font-medium text-foreground text-sm">{{ p.name }}</p>
                  <p class="text-xs text-muted-foreground">{{ p.sku }}</p>
                </td>
                <td class="px-4 py-2.5 text-center"><Badge variant="danger" :label="p.stock" /></td>
                <td class="px-4 py-2.5 text-center text-sm text-muted-foreground">{{ p.min_stock }}</td>
                <td class="px-4 py-2.5 text-right text-sm text-red-600 font-medium">{{ p.min_stock - p.stock }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  </AppLayout>
</template>
