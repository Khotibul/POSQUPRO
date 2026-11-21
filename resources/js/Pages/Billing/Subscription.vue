<script setup>
import { computed, ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Button from '@/Components/UI/Button.vue'
import Badge from '@/Components/UI/Badge.vue'
import {
  CheckCircleIcon, ClockIcon, SparklesIcon, CreditCardIcon,
  ArrowUpRightIcon, ExclamationTriangleIcon, ShieldCheckIcon
} from '@heroicons/vue/24/outline'

const props = defineProps({
  plans: { type: Array, default: () => [] },
  invoices: { type: Array, default: () => [] },
  limits: { type: Object, default: () => ({}) },
  subscription: { type: Object, default: () => ({}) },
  tenantStatus: { type: String, default: '' },
  daysRemaining: { type: Number, default: 0 },
  ipaymuEnabled: { type: Boolean, default: false },
})

const { success, error } = useToast()
const loading = ref('')

const currentPlanName = computed(() => props.limits?.plan_name || 'Tidak ada paket')
const isTrial = computed(() => props.tenantStatus === 'trial')
const isExpired = computed(() => props.subscription?.is_expired || props.tenantStatus === 'expired')
const isSuspended = computed(() => props.tenantStatus === 'suspended')

const featureLabel = (key) => props.plans?.[0]?.feature_labels?.[key] || key.replaceAll('_', ' ')

const usageRows = computed(() => [
  { key: 'users', label: 'Pengguna', data: props.limits?.users },
  { key: 'products', label: 'Produk', data: props.limits?.products },
  { key: 'customers', label: 'Pelanggan', data: props.limits?.customers },
  { key: 'branches', label: 'Cabang', data: props.limits?.branches },
  { key: 'transactions_month', label: 'Transaksi bulan ini', data: props.limits?.transactions_month },
])

const fc = (v) => 'Rp ' + Number(v || 0).toLocaleString('id-ID')
const statusLabel = (status) => ({
  paid: 'Lunas', pending: 'Menunggu Pembayaran', cancelled: 'Dibatalkan', expired: 'Kedaluwarsa'
}[status] || status)

function usagePercent(row) {
  if (!row?.data || row.data.unlimited || !row.data.max) return 0
  return Math.min(100, Math.round((row.data.current / row.data.max) * 100))
}

function checkout(plan, cycle) {
  if (!props.ipaymuEnabled) {
    error('Payment gateway iPaymu belum dikonfigurasi oleh administrator.')
    return
  }

  loading.value = `${plan.id}-${cycle}`
  router.post('/billing/checkout', { plan_id: plan.id, billing_cycle: cycle }, {
    onError: (err) => error(err.message || Object.values(err)[0] || 'Gagal membuat pembayaran'),
    onFinish: () => { loading.value = '' },
  })
}

function continuePayment(invoice) {
  if (invoice.payment_url) {
    window.location.href = invoice.payment_url
  }
}
</script>

<template>
  <AppLayout>
    <template #header>
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 class="text-2xl font-bold">Langganan & Billing</h1>
          <p class="text-sm text-muted-foreground">Kelola paket, kuota, dan pembayaran langganan POSQUPRO.</p>
        </div>
        <Badge
          :variant="isExpired || isSuspended ? 'danger' : isTrial ? 'info' : 'success'"
          :label="isSuspended ? 'Ditangguhkan' : isExpired ? 'Kedaluwarsa' : isTrial ? 'Demo Aktif' : 'Aktif'"
        />
      </div>
    </template>

    <!-- Status / trial banner -->
    <div
      v-if="isExpired || isSuspended"
      class="mb-6 rounded-2xl border border-red-200 bg-red-50 p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
    >
      <div class="flex items-start gap-3">
        <ExclamationTriangleIcon class="w-6 h-6 text-red-600 shrink-0" />
        <div>
          <p class="font-semibold text-red-800">
            {{ isSuspended ? 'Akun tenant ditangguhkan' : 'Masa demo/langganan telah berakhir' }}
          </p>
          <p class="text-sm text-red-700">
            {{ isSuspended ? 'Hubungi administrator POSQUPRO untuk mengaktifkan kembali.' : 'Pilih paket di bawah untuk melanjutkan penggunaan seluruh fitur.' }}
          </p>
        </div>
      </div>
    </div>

    <div v-else class="mb-6 rounded-2xl border border-primary/20 bg-gradient-to-r from-primary/10 via-card to-card p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div class="flex items-start gap-3">
        <SparklesIcon class="w-6 h-6 text-primary shrink-0" />
        <div>
          <p class="font-semibold">{{ isTrial ? 'Demo 30 hari — semua fitur terbuka' : `Paket ${currentPlanName} aktif` }}</p>
          <p class="text-sm text-muted-foreground">
            <template v-if="isTrial">Sisa {{ daysRemaining }} hari. Upgrade kapan saja tanpa kehilangan data.</template>
            <template v-else>Sisa {{ daysRemaining }} hari masa aktif.</template>
          </p>
        </div>
      </div>
      <a href="#paket" class="text-sm font-semibold text-primary inline-flex items-center gap-1">
        Lihat paket <ArrowUpRightIcon class="w-4 h-4" />
      </a>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
      <!-- Current plan + usage -->
      <Card class="lg:col-span-1">
        <div class="flex items-center gap-3 mb-4">
          <div class="w-11 h-11 rounded-xl bg-primary/10 flex items-center justify-center">
            <ShieldCheckIcon class="w-6 h-6 text-primary" />
          </div>
          <div>
            <p class="text-xs uppercase tracking-wide text-muted-foreground">Paket Saat Ini</p>
            <p class="text-lg font-bold">{{ currentPlanName }}</p>
          </div>
        </div>

        <div class="space-y-4">
          <div v-for="row in usageRows" :key="row.key">
            <div class="flex justify-between text-sm mb-1">
              <span class="text-muted-foreground">{{ row.label }}</span>
              <span class="font-medium">
                {{ row.data?.current ?? 0 }} / {{ row.data?.unlimited ? '∞' : (row.data?.max ?? 0) }}
              </span>
            </div>
            <div class="h-2 rounded-full bg-muted overflow-hidden">
              <div
                class="h-full rounded-full transition-all"
                :class="usagePercent(row) >= 100 ? 'bg-red-500' : usagePercent(row) >= 80 ? 'bg-amber-500' : 'bg-primary'"
                :style="{ width: (row.data?.unlimited ? 0 : usagePercent(row)) + '%' }"
              />
            </div>
          </div>
        </div>

        <p class="mt-4 text-xs text-muted-foreground">
          Kuota dihitung otomatis. Data lama tetap aman jika Anda berganti paket.
        </p>
      </Card>

      <!-- Plan chooser -->
      <div id="paket" class="lg:col-span-2">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div
            v-for="plan in plans"
            :key="plan.id"
            class="relative rounded-2xl border border-border bg-card p-5 flex flex-col shadow-sm hover:shadow-md transition-shadow"
            :class="plan.slug === 'business' ? 'ring-2 ring-primary/30' : ''"
          >
            <div v-if="plan.slug === 'business'" class="absolute -top-3 left-4">
              <span class="px-2.5 py-1 rounded-full bg-primary text-primary-foreground text-[11px] font-semibold">Paling Populer</span>
            </div>

            <h3 class="text-lg font-bold">{{ plan.name }}</h3>
            <p class="text-xs text-muted-foreground min-h-[32px]">{{ plan.description }}</p>

            <div class="my-4">
              <p class="text-2xl font-extrabold">{{ fc(plan.price) }}<span class="text-xs font-normal text-muted-foreground"> /bulan</span></p>
              <p v-if="plan.price_yearly" class="text-xs text-green-600 mt-1">Tahunan {{ fc(plan.price_yearly) }}</p>
            </div>

            <ul class="space-y-1.5 text-xs text-muted-foreground mb-4 flex-1">
              <li class="flex gap-1.5"><CheckCircleIcon class="w-4 h-4 text-green-600 shrink-0" /> {{ plan.max_users ? plan.max_users + ' pengguna' : 'Pengguna tanpa batas' }}</li>
              <li class="flex gap-1.5"><CheckCircleIcon class="w-4 h-4 text-green-600 shrink-0" /> {{ plan.max_products ? plan.max_products + ' produk' : 'Produk tanpa batas' }}</li>
              <li class="flex gap-1.5"><CheckCircleIcon class="w-4 h-4 text-green-600 shrink-0" /> {{ plan.max_customers ? plan.max_customers + ' pelanggan' : 'Pelanggan tanpa batas' }}</li>
              <li class="flex gap-1.5"><CheckCircleIcon class="w-4 h-4 text-green-600 shrink-0" /> {{ plan.max_transactions_per_month ? plan.max_transactions_per_month + ' transaksi/bulan' : 'Transaksi tanpa batas' }}</li>
              <li class="flex gap-1.5"><CheckCircleIcon class="w-4 h-4 text-green-600 shrink-0" /> {{ plan.max_branches ? plan.max_branches + ' cabang' : 'Cabang tanpa batas' }}</li>
            </ul>

            <div class="flex flex-wrap gap-1 mb-4">
              <span v-for="f in (plan.features || []).slice(0, 4)" :key="f" class="px-2 py-0.5 rounded-full bg-primary/10 text-primary text-[10px]">
                {{ featureLabel(f) }}
              </span>
              <span v-if="(plan.features || []).length > 4" class="px-2 py-0.5 rounded-full bg-muted text-muted-foreground text-[10px]">
                +{{ plan.features.length - 4 }} fitur
              </span>
            </div>

            <div class="space-y-2">
              <Button class="w-full" :disabled="loading !== ''" @click="checkout(plan, 'monthly')">
                <CreditCardIcon class="w-4 h-4" />
                {{ loading === plan.id + '-monthly' ? 'Memproses...' : 'Pilih Bulanan' }}
              </Button>
              <Button
                v-if="plan.price_yearly"
                variant="outline"
                class="w-full"
                :disabled="loading !== ''"
                @click="checkout(plan, 'yearly')"
              >
                {{ loading === plan.id + '-yearly' ? 'Memproses...' : 'Pilih Tahunan' }}
              </Button>
            </div>
          </div>
        </div>

        <div class="mt-4 flex items-start gap-2 text-xs text-muted-foreground">
          <ShieldCheckIcon class="w-4 h-4 text-green-600 shrink-0 mt-0.5" />
          <p>
            Pembayaran diproses aman oleh <strong>iPaymu</strong> (VA, QRIS, e-wallet, kartu).
            <span v-if="!ipaymuEnabled" class="text-red-600"> Gateway belum dikonfigurasi — hubungi administrator.</span>
            Harga belum termasuk PPN 11%.
          </p>
        </div>
      </div>
    </div>

    <!-- Invoice history -->
    <Card>
      <div class="flex items-center justify-between mb-4">
        <h2 class="font-bold">Riwayat Invoice</h2>
        <ClockIcon class="w-5 h-5 text-muted-foreground" />
      </div>

      <div v-if="!invoices.length" class="py-8 text-center text-sm text-muted-foreground">
        Belum ada invoice. Invoice dibuat otomatis saat Anda memilih paket.
      </div>

      <div v-else class="space-y-2">
        <div v-for="invoice in invoices" :key="invoice.id" class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 rounded-xl border border-border p-3">
          <div>
            <p class="font-medium text-sm">{{ invoice.invoice_number }}</p>
            <p class="text-xs text-muted-foreground">
              {{ invoice.plan?.name || '-' }} • {{ invoice.billing_cycle === 'yearly' ? 'Tahunan' : 'Bulanan' }} •
              {{ invoice.issued_at ? new Date(invoice.issued_at).toLocaleDateString('id-ID') : '-' }}
            </p>
          </div>
          <div class="flex items-center gap-3">
            <div class="text-right">
              <p class="font-semibold text-sm">{{ fc(invoice.total) }}</p>
              <Badge
                :variant="invoice.status === 'paid' ? 'success' : invoice.status === 'pending' ? 'warning' : 'default'"
                :label="statusLabel(invoice.status)"
              />
            </div>
            <Button
              v-if="invoice.status === 'pending' && invoice.payment_url"
              size="sm"
              variant="outline"
              @click="continuePayment(invoice)"
            >
              Bayar
            </Button>
          </div>
        </div>
      </div>
    </Card>
  </AppLayout>
</template>
