<script setup>
import { ref, computed, onMounted } from 'vue'
import { usePage, router } from '@inertiajs/vue3'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Select from '@/Components/UI/Select.vue'
import Button from '@/Components/UI/Button.vue'
import Badge from '@/Components/UI/Badge.vue'
import {
  ChartBarIcon, CurrencyDollarIcon, ShoppingBagIcon,
  UsersIcon, ArrowDownTrayIcon, CalendarDaysIcon
} from '@heroicons/vue/24/outline'

const page = usePage()

const props = defineProps({
  stats: { type: Object, default: () => ({ today_revenue: 0, today_transactions: 0, month_revenue: 0, low_stock_count: 0 }) },
  salesData: { type: Array, default: () => [] },
  topProducts: { type: Array, default: () => [] },
  paymentBreakdown: { type: Array, default: () => [] },
})

const reportType = ref('sales')
const dateRange = ref('today')
const dateFrom = ref('')
const dateTo = ref('')
const loading = ref(false)

const dateRanges = [
  { value: 'today', label: 'Hari Ini' },
  { value: 'yesterday', label: 'Kemarin' },
  { value: 'week', label: '7 Hari Terakhir' },
  { value: 'month', label: 'Bulan Ini' },
  { value: 'last_month', label: 'Bulan Lalu' },
  { value: 'custom', label: 'Custom' },
]

const formatCurrency = (val) => 'Rp ' + Number(val).toLocaleString('id-ID')

const salesChartData = computed(() =>
  props.salesData.map(d => ({
    date: d.date,
    revenue: Number(d.total),
    transactions: Number(d.count),
  }))
)

const paymentChartData = computed(() =>
  props.paymentBreakdown.map(d => ({
    name: d.method.charAt(0).toUpperCase() + d.method.slice(1),
    value: Number(d.total),
  }))
)

function loadReport() {
  loading.value = true
  router.get('/api/v1/reports/sales', {
    type: reportType.value,
    from: dateFrom.value,
    to: dateTo.value,
  }, {
    onSuccess: () => { loading.value = false },
    onFinish: () => loading.value = false,
  })
}

function exportReport() {
  window.open(`/api/v1/reports/sales/export?type=${reportType.value}&from=${dateFrom.value}&to=${dateTo.value}`, '_blank')
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-foreground">Laporan & Analitik</h1>
          <p class="text-sm text-muted-foreground">Insight bisnis real-time</p>
        </div>
        <div class="flex gap-2">
          <Select v-model="reportType" :options="[{value:'sales',label:'Penjualan'},{value:'inventory',label:'Inventory'},{value:'profit',label:'Profit'},{value:'cashier',label:'Kasir'}]" class="w-40" />
          <Select v-model="dateRange" :options="dateRanges" class="w-40" @change="onDateRangeChange" />
          <div v-if="dateRange.value === 'custom'" class="flex gap-2">
            <input type="date" v-model="dateFrom" class="px-3 py-2 border border-border rounded-lg text-sm" />
            <input type="date" v-model="dateTo" class="px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <Button @click="loadReport" :disabled="loading"><ChartBarIcon class="w-4 h-4" /> Refresh</Button>
          <Button variant="outline" @click="exportReport"><ArrowDownTrayIcon class="w-4 h-4" /> Export</Button>
        </div>
      </div>
    </template>

    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center">
            <CurrencyDollarIcon class="w-6 h-6 text-indigo-600" />
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Pendapatan</p>
            <p class="text-2xl font-bold text-foreground">{{ formatCurrency(props.stats.today_revenue || 0) }}</p>
          </div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
            <ShoppingBagIcon class="w-6 h-6 text-green-600" />
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Transaksi</p>
            <p class="text-2xl font-bold text-foreground">{{ Number(props.stats.today_transactions || 0).toLocaleString('id-ID') }}</p>
          </div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
            <CurrencyDollarIcon class="w-6 h-6 text-blue-600" />
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Bulan Ini</p>
            <p class="text-2xl font-bold text-foreground">{{ formatCurrency(props.stats.month_revenue || 0) }}</p>
          </div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
            <UsersIcon class="w-6 h-6 text-purple-600" />
          </div>
          <div>
            <p class="text-sm text-muted-foreground">Avg/Transaksi</p>
            <p class="text-2xl font-bold text-foreground">{{ props.stats.today_transactions > 0 ? formatCurrency((props.stats.today_revenue || 0) / props.stats.today_transactions) : 'Rp 0' }}</p>
          </div>
        </div>
      </Card>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
      <!-- Revenue Chart - Simple Bar Chart using CSS -->
      <Card title="Tren Pendapatan" class="h-[400px]">
        <div class="h-full flex items-end gap-2 px-2 pb-4" style="height: 320px;">
          <div v-for="d in salesChartData.value" :key="d.date" class="flex-1 flex flex-col items-center justify-end min-w-[40px]">
            <div 
              class="w-full bg-indigo-600 rounded-t transition-all duration-300 hover:bg-indigo-700 cursor-pointer"
              :style="{ height: salesChartData.value.length > 0 ? (d.revenue / Math.max(...salesChartData.value.map(x => x.revenue)) * 100) + '%' : '0%' }"
              :title="formatCurrency(d.revenue)"
            ></div>
            <span class="text-xs text-muted-foreground mt-1" style="writing-mode: vertical-rl; text-orientation: mixed;">{{ new Date(d.date).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' }) }}</span>
          </div>
        </div>
      </Card>

      <!-- Payment Method Donut Chart - CSS only -->
      <Card title="Metode Pembayaran" class="h-[400px]">
        <div class="flex items-center justify-center h-full">
          <div class="relative w-64 h-64">
            <svg class="w-full h-full transform -rotate-90">
              <circle
                cx="32" cy="32" r="28"
                fill="none" stroke="#e5e7eb" stroke-width="16"
              />
              <template v-for="(p, i) in paymentChartData.value" :key="p.name">
                <circle
                  cx="32" cy="32" r="28"
                  fill="none" :stroke="['#6366f1', '#22c55e', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4'][i % 6]"
                  stroke-width="16"
                  stroke-dasharray="175.93"
                  :stroke-dashoffset="175.93 - (p.value / (paymentChartData.value.reduce((s, x) => s + x.value, 0) || 1) * 175.93)"
                  stroke-linecap="round"
                  style="transition: stroke-dashoffset 1s ease-out;"
                />
              </template>
            </svg>
            <div class="absolute inset-0 flex items-center justify-center">
              <div class="text-center">
                <p class="text-2xl font-bold text-foreground">{{ formatCurrency(paymentChartData.value.reduce((s, x) => s + x.value, 0)) }}</p>
                <p class="text-xs text-muted-foreground">Total Bayar</p>
              </div>
            </div>
          </div>
          <div class="ml-8 space-y-2">
            <div v-for="(p, i) in paymentChartData.value" :key="p.name" class="flex items-center gap-3">
              <div class="w-4 h-4 rounded" :style="{ backgroundColor: ['#6366f1', '#22c55e', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4'][i % 6] }"></div>
              <span class="capitalize text-sm">{{ p.name }}</span>
              <span class="text-sm font-medium text-foreground ml-auto">{{ formatCurrency(p.value) }}</span>
            </div>
          </div>
        </div>
      </Card>
    </div>

    <!-- Top Products & Payment Breakdown -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <Card title="Produk Terlaris">
        <div class="space-y-3">
          <div v-for="(p, i) in props.topProducts.slice(0, 10)" :key="p.id || i" class="flex items-center justify-between p-3 bg-muted rounded-lg">
            <div class="flex items-center gap-3">
              <span class="w-8 h-8 bg-indigo-100 rounded-full flex items-center justify-center text-indigo-600 font-bold">{{ i + 1 }}</span>
              <div>
                <p class="font-medium text-foreground">{{ p.product?.name || 'Produk' }}</p>
                <p class="text-xs text-muted-foreground">Terjual: {{ p.qty }} • {{ formatCurrency(p.revenue) }}</p>
              </div>
            </div>
          </div>
        </div>
      </Card>

      <Card title="Rincian Pembayaran">
        <div class="space-y-3">
          <div v-for="p in props.paymentBreakdown" :key="p.method" class="flex items-center justify-between p-3 bg-muted rounded-lg">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-lg flex items-center justify-center" :class="p.method === 'cash' ? 'bg-green-100' : p.method === 'card' ? 'bg-blue-100' : p.method === 'qris' ? 'bg-purple-100' : 'bg-yellow-100'">
                <span class="text-lg">{{ p.method === 'cash' ? '💵' : p.method === 'card' ? '💳' : p.method === 'qris' ? '📱' : '🏦' }}</span>
              </div>
              <span class="font-medium capitalize">{{ p.method }}</span>
            </div>
            <div class="text-right">
              <p class="font-bold text-foreground">{{ formatCurrency(p.total) }}</p>
              <p class="text-xs text-muted-foreground">{{ Math.round(Number(p.total) / (props.stats.today_revenue || 1) * 100) }}%</p>
            </div>
          </div>
        </div>
      </Card>
    </div>

    <!-- Summary Table -->
    <Card title="Ringkasan Harian">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="bg-muted"><tr><th class="px-4 py-2 text-left">Tanggal</th><th class="px-4 py-2 text-right">Pendapatan</th><th class="px-4 py-2 text-right">Transaksi</th><th class="px-4 py-2 text-right">Rata-rata</th></tr></thead>
          <tbody class="divide-y divide-gray-100">
            <tr v-for="d in salesChartData.value" :key="d.date">
              <td class="px-4 py-2">{{ new Date(d.date).toLocaleDateString('id-ID', { weekday: 'short', day: '2-digit', month: 'short' }) }}</td>
              <td class="px-4 py-2 text-right font-medium">{{ formatCurrency(d.revenue) }}</td>
              <td class="px-4 py-2 text-right">{{ d.transactions }}</td>
              <td class="px-4 py-2 text-right">{{ d.transactions > 0 ? formatCurrency(d.revenue / d.transactions) : 'Rp 0' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Card>
  </AppLayout>
</template>

<script>
import { ChartBarIcon, CurrencyDollarIcon, ShoppingBagIcon, UsersIcon, ArrowDownTrayIcon, CalendarDaysIcon } from '@heroicons/vue/24/outline'
export default { components: { ChartBarIcon, CurrencyDollarIcon, ShoppingBagIcon, UsersIcon, ArrowDownTrayIcon, CalendarDaysIcon } }
</script>