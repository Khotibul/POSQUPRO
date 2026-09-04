<script setup>
import { computed } from 'vue'
import { router } from '@inertiajs/vue3'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Button from '@/Components/UI/Button.vue'
import Badge from '@/Components/UI/Badge.vue'
import {
  BuildingOffice2Icon, CurrencyDollarIcon, UsersIcon,
  ExclamationTriangleIcon, ArrowUpTrayIcon, ArrowDownTrayIcon,
  CheckCircleIcon, ClockIcon, XCircleIcon
} from '@heroicons/vue/24/outline'

const props = defineProps({
  stats: { type: Object, default: () => ({}) },
  recentTenants: { type: Array, default: () => [] },
  recentInvoices: { type: Array, default: () => [] },
  planDistribution: { type: Array, default: () => [] },
  revenueByMonth: { type: Array, default: () => [] },
})

const fc = (v) => 'Rp ' + Number(v || 0).toLocaleString('id-ID')
const statusColor = { active: 'success', trial: 'info', suspended: 'danger', inactive: 'warning' }
const invoiceColor = { paid: 'success', pending: 'warning', overdue: 'danger', draft: 'info', cancelled: 'danger' }

const maxRevenue = computed(() => Math.max(...(props.revenueByMonth?.map(d => Number(d.revenue)) || [1]), 1))
</script>

<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold">SaaS Dashboard</h1>
          <p class="text-sm text-muted-foreground">Overview platform POSQUPRO</p>
        </div>
        <div class="flex gap-2">
          <Button variant="outline" @click="router.visit('/tenants')"><BuildingOffice2Icon class="w-4 h-4" /> Kelola Tenant</Button>
          <Button @click="router.visit('/billing/plans')"><CurrencyDollarIcon class="w-4 h-4" /> Kelola Paket</Button>
        </div>
      </div>
    </template>

    <!-- KPI Cards -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center"><BuildingOffice2Icon class="w-6 h-6 text-blue-600" /></div>
          <div><p class="text-sm text-muted-foreground">Total Tenant</p><p class="text-2xl font-bold">{{ stats.total_tenants || 0 }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center"><CheckCircleIcon class="w-6 h-6 text-green-600" /></div>
          <div><p class="text-sm text-muted-foreground">Aktif</p><p class="text-2xl font-bold text-green-600">{{ stats.active_tenants || 0 }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-yellow-100 rounded-xl flex items-center justify-center"><ClockIcon class="w-6 h-6 text-yellow-600" /></div>
          <div><p class="text-sm text-muted-foreground">Trial</p><p class="text-2xl font-bold text-yellow-600">{{ stats.trial_tenants || 0 }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-red-100 rounded-xl flex items-center justify-center"><XCircleIcon class="w-6 h-6 text-red-600" /></div>
          <div><p class="text-sm text-muted-foreground">Suspended</p><p class="text-2xl font-bold text-red-600">{{ stats.suspended_tenants || 0 }}</p></div>
        </div>
      </Card>
    </div>

    <!-- Revenue Cards -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center"><CurrencyDollarIcon class="w-6 h-6 text-indigo-600" /></div>
          <div><p class="text-sm text-muted-foreground">Total Revenue</p><p class="text-2xl font-bold text-indigo-600">{{ fc(stats.total_revenue) }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center"><ArrowUpTrayIcon class="w-6 h-6 text-green-600" /></div>
          <div><p class="text-sm text-muted-foreground">Revenue Bulan Ini</p><p class="text-2xl font-bold text-green-600">{{ fc(stats.monthly_revenue) }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-orange-100 rounded-xl flex items-center justify-center"><ArrowDownTrayIcon class="w-6 h-6 text-orange-600" /></div>
          <div><p class="text-sm text-muted-foreground">Outstanding</p><p class="text-2xl font-bold text-orange-600">{{ fc(stats.outstanding) }}</p></div>
        </div>
      </Card>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
      <!-- Revenue Chart -->
      <Card title="Revenue 12 Bulan" class="lg:col-span-2">
        <div v-if="!revenueByMonth?.length" class="h-48 flex items-center justify-center text-muted-foreground">Belum ada data</div>
        <div v-else class="h-48 flex items-end gap-1 px-2 pb-6">
          <div v-for="d in revenueByMonth" :key="d.month" class="flex-1 min-w-[24px] flex flex-col items-center justify-end h-full">
            <span class="text-[9px] text-muted-foreground mb-1">{{ fc(d.revenue) }}</span>
            <div class="w-full bg-indigo-500 rounded-t hover:bg-indigo-600 transition-colors" :style="{ height: (Number(d.revenue) / maxRevenue * 100) + '%' }" />
            <span class="text-[9px] text-muted-foreground mt-1">{{ d.month.slice(5) }}</span>
          </div>
        </div>
      </Card>

      <!-- Plan Distribution -->
      <Card title="Distribusi Paket">
        <div v-if="!planDistribution?.length" class="py-8 text-center text-muted-foreground">Belum ada paket</div>
        <div v-else class="space-y-3">
          <div v-for="plan in planDistribution" :key="plan.id" class="flex items-center justify-between p-3 bg-muted rounded-lg">
            <div>
              <p class="font-medium">{{ plan.name }}</p>
              <p class="text-xs text-muted-foreground">{{ plan.Tenants_count || 0 }} tenant</p>
            </div>
            <span class="text-sm font-bold">{{ fc(plan.price) }}/bln</span>
          </div>
        </div>
      </Card>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Recent Tenants -->
      <Card title="Tenant Terbaru">
        <div v-if="!recentTenants?.length" class="py-8 text-center text-muted-foreground">Belum ada tenant</div>
        <div v-else class="space-y-2">
          <div v-for="t in recentTenants" :key="t.id" class="flex items-center justify-between p-3 bg-muted rounded-lg hover:bg-muted/80 cursor-pointer" @click="router.visit('/tenants/' + t.id)">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-primary/10 rounded-lg flex items-center justify-center font-bold text-primary">{{ t.name?.charAt(0) }}</div>
              <div>
                <p class="font-medium text-sm">{{ t.name }}</p>
                <p class="text-xs text-muted-foreground">{{ t.owner?.name || '-' }} • {{ t.plan?.name || 'Free' }}</p>
              </div>
            </div>
            <Badge :variant="statusColor[t.status] || 'info'" :label="t.status" />
          </div>
        </div>
      </Card>

      <!-- Recent Invoices -->
      <Card title="Invoice Terbaru">
        <div v-if="!recentInvoices?.length" class="py-8 text-center text-muted-foreground">Belum ada invoice</div>
        <div v-else class="space-y-2">
          <div v-for="inv in recentInvoices" :key="inv.id" class="flex items-center justify-between p-3 bg-muted rounded-lg">
            <div>
              <p class="font-medium text-sm">{{ inv.invoice_number }}</p>
              <p class="text-xs text-muted-foreground">{{ inv.tenant?.name || '-' }} • {{ inv.plan?.name }}</p>
            </div>
            <div class="text-right">
              <p class="font-medium text-sm">{{ fc(inv.total) }}</p>
              <Badge :variant="invoiceColor[inv.status] || 'info'" :label="inv.status" />
            </div>
          </div>
        </div>
      </Card>
    </div>
  </AppLayout>
</template>
