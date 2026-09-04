<script setup>
import { ref, computed } from 'vue'
import { router } from '@inertiajs/vue3'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import {
  CurrencyDollarIcon, ShoppingBagIcon, ChartBarIcon, ArrowDownTrayIcon
} from '@heroicons/vue/24/outline'

const props = defineProps({
  stats: { type: Object, default: () => ({ today_revenue: 0, today_transactions: 0, month_revenue: 0, low_stock_count: 0 }) },
  salesData: { type: Array, default: () => [] },
  topProducts: { type: Array, default: () => [] },
  paymentBreakdown: { type: Array, default: () => [] },
})

const dateRange = ref('today')
const loading = ref(false)

const fc = (v) => 'Rp ' + Number(v || 0).toLocaleString('id-ID')

const salesChart = computed(() => props.salesData.map(d => ({ date: d.date, rev: Number(d.total), cnt: Number(d.count) })))
const maxRev = computed(() => Math.max(...salesChart.value.map(d => d.rev), 1))

const paymentChart = computed(() => {
  const total = props.paymentBreakdown.reduce((s, p) => s + Number(p.total), 0) || 1
  return props.paymentBreakdown.map(p => ({
    name: p.method.charAt(0).toUpperCase() + p.method.slice(1),
    value: Number(p.total),
    pct: Math.round(Number(p.total) / total * 100),
  }))
})

const colors = ['#6366f1', '#22c55e', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4']
const donutTotal = computed(() => paymentChart.value.reduce((s, p) => s + p.value, 0))

function loadReport() {
  loading.value = true
  router.reload({ onFinish: () => { loading.value = false } })
}
</script>

<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold">Laporan & Analitik</h1>
          <p class="text-sm text-muted-foreground">Insight bisnis real-time</p>
        </div>
        <div class="flex gap-2">
          <select v-model="dateRange" class="px-3 py-2 border border-border rounded-lg text-sm bg-background">
            <option value="today">Hari Ini</option>
            <option value="week">7 Hari</option>
            <option value="month">Bulan Ini</option>
          </select>
          <button @click="loadReport" :disabled="loading" class="px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm hover:bg-primary/90 disabled:opacity-50 flex items-center gap-1">
            <ChartBarIcon class="w-4 h-4" /> {{ loading ? 'Memuat...' : 'Refresh' }}
          </button>
        </div>
      </div>
    </template>

    <!-- KPI Cards -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center"><CurrencyDollarIcon class="w-6 h-6 text-indigo-600" /></div>
          <div><p class="text-sm text-muted-foreground">Pendapatan Hari</p><p class="text-2xl font-bold">{{ fc(stats.today_revenue) }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center"><ShoppingBagIcon class="w-6 h-6 text-green-600" /></div>
          <div><p class="text-sm text-muted-foreground">Transaksi Hari</p><p class="text-2xl font-bold">{{ Number(stats.today_transactions || 0).toLocaleString('id-ID') }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center"><CurrencyDollarIcon class="w-6 h-6 text-blue-600" /></div>
          <div><p class="text-sm text-muted-foreground">Bulan Ini</p><p class="text-2xl font-bold">{{ fc(stats.month_revenue) }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-red-100 rounded-xl flex items-center justify-center"><ChartBarIcon class="w-6 h-6 text-red-600" /></div>
          <div><p class="text-sm text-muted-foreground">Stok Menipis</p><p class="text-2xl font-bold text-red-600">{{ stats.low_stock_count || 0 }}</p></div>
        </div>
      </Card>
    </div>

    <!-- Charts -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
      <!-- Bar Chart -->
      <Card title="Tren Pendapatan">
        <div v-if="!salesChart.length" class="h-64 flex items-center justify-center text-muted-foreground">Belum ada data</div>
        <div v-else class="h-64 flex items-end gap-1 px-2 pb-6 overflow-x-auto">
          <div v-for="d in salesChart" :key="d.date" class="flex-1 min-w-[36px] flex flex-col items-center justify-end h-full">
            <span class="text-[10px] text-muted-foreground mb-1 whitespace-nowrap">{{ fc(d.rev) }}</span>
            <div class="w-full bg-indigo-500 rounded-t hover:bg-indigo-600 transition-colors cursor-pointer" :style="{ height: (d.rev / maxRev * 100) + '%' }" :title="fc(d.rev)" />
            <span class="text-[10px] text-muted-foreground mt-1">{{ new Date(d.date).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' }) }}</span>
          </div>
        </div>
      </Card>

      <!-- Donut Chart -->
      <Card title="Metode Pembayaran">
        <div v-if="!paymentChart.length" class="h-64 flex items-center justify-center text-muted-foreground">Belum ada data</div>
        <div v-else class="flex items-center justify-center h-64 gap-6">
          <div class="relative w-48 h-48 flex-shrink-0">
            <svg viewBox="0 0 100 100" class="w-full h-full -rotate-90">
              <circle cx="50" cy="50" r="40" fill="none" stroke="#e5e7eb" stroke-width="20" />
              <template v-for="(p, i) in paymentChart" :key="p.name">
                <circle cx="50" cy="50" r="40" fill="none" :stroke="colors[i % colors.length]" stroke-width="20"
                  :stroke-dasharray="`${p.pct * 2.513} ${251.3 - p.pct * 2.513}`"
                  :stroke-dashoffset="-paymentChart.slice(0, i).reduce((s, x) => s + x.pct * 2.513, 0)"
                  stroke-linecap="round" style="transition: all 0.8s ease" />
              </template>
            </svg>
            <div class="absolute inset-0 flex items-center justify-center"><div class="text-center"><p class="text-lg font-bold">{{ fc(donutTotal) }}</p><p class="text-xs text-muted-foreground">Total</p></div></div>
          </div>
          <div class="space-y-2">
            <div v-for="(p, i) in paymentChart" :key="p.name" class="flex items-center gap-2 text-sm">
              <div class="w-3 h-3 rounded-full" :style="{ backgroundColor: colors[i % colors.length] }" />
              <span class="w-16">{{ p.name }}</span>
              <span class="font-medium ml-auto">{{ fc(p.value) }}</span>
              <span class="text-muted-foreground w-10 text-right">{{ p.pct }}%</span>
            </div>
          </div>
        </div>
      </Card>
    </div>

    <!-- Top Products & Daily Summary -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <Card title="Produk Terlaris (30 Hari)">
        <div v-if="!topProducts.length" class="py-8 text-center text-muted-foreground">Belum ada data</div>
        <div v-else class="space-y-2">
          <div v-for="(p, i) in topProducts.slice(0, 10)" :key="p.product_id || i" class="flex items-center gap-3 p-3 bg-muted rounded-lg">
            <span class="w-8 h-8 bg-indigo-100 rounded-full flex items-center justify-center text-indigo-600 font-bold text-sm">{{ i + 1 }}</span>
            <div class="flex-1 min-w-0">
              <p class="font-medium text-sm truncate">{{ p.product?.name || 'Produk #' + p.product_id }}</p>
              <p class="text-xs text-muted-foreground">Terjual: {{ p.qty }}</p>
            </div>
            <span class="font-medium text-sm">{{ fc(p.revenue) }}</span>
          </div>
        </div>
      </Card>

      <Card title="Ringkasan Harian">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead class="bg-muted"><tr><th class="px-3 py-2 text-left">Tanggal</th><th class="px-3 py-2 text-right">Pendapatan</th><th class="px-3 py-2 text-right">Transaksi</th><th class="px-3 py-2 text-right">Rata-rata</th></tr></thead>
            <tbody class="divide-y divide-border">
              <tr v-for="d in salesChart" :key="d.date" class="hover:bg-muted/50">
                <td class="px-3 py-2">{{ new Date(d.date).toLocaleDateString('id-ID', { weekday: 'short', day: '2-digit', month: 'short' }) }}</td>
                <td class="px-3 py-2 text-right font-medium">{{ fc(d.rev) }}</td>
                <td class="px-3 py-2 text-right">{{ d.cnt }}</td>
                <td class="px-3 py-2 text-right">{{ d.cnt > 0 ? fc(d.rev / d.cnt) : 'Rp 0' }}</td>
              </tr>
              <tr v-if="!salesChart.length"><td colspan="4" class="px-3 py-8 text-center text-muted-foreground">Belum ada data</td></tr>
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  </AppLayout>
</template>
