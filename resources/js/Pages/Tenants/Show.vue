<script setup>
import { ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Button from '@/Components/UI/Button.vue'
import Badge from '@/Components/UI/Badge.vue'
import Modal from '@/Components/UI/Modal.vue'
import {
  BuildingOffice2Icon, CheckCircleIcon, ClockIcon, XCircleIcon,
  PencilIcon, NoSymbolIcon, CurrencyDollarIcon, UsersIcon
} from '@heroicons/vue/24/outline'

const { success, error } = useToast()

const props = defineProps({
  tenant: { type: Object, required: true },
  invoices: { type: Object, default: () => ({ data: [] }) },
  stats: { type: Object, default: () => ({}) },
})

const showEditModal = ref(false)
const loading = ref(false)
const form = ref({
  name: props.tenant.name,
  email: props.tenant.email,
  phone: props.tenant.phone,
  address: props.tenant.address,
  city: props.tenant.city,
  province: props.tenant.province,
  status: props.tenant.status,
  plan_id: props.tenant.plan_id,
})

const statusColor = { active: 'success', trial: 'info', suspended: 'danger', inactive: 'warning' }
const statusLabel = { active: 'Aktif', trial: 'Trial', suspended: 'Suspended', inactive: 'Nonaktif' }
const invoiceColor = { paid: 'success', pending: 'warning', overdue: 'danger', draft: 'info' }
const fc = (v) => 'Rp ' + Number(v || 0).toLocaleString('id-ID')

function openEdit() {
  form.value = {
    name: props.tenant.name,
    email: props.tenant.email,
    phone: props.tenant.phone,
    address: props.tenant.address,
    city: props.tenant.city,
    province: props.tenant.province,
    status: props.tenant.status,
    plan_id: props.tenant.plan_id,
  }
  showEditModal.value = true
}

async function saveEdit() {
  loading.value = true
  try {
    await router.put(`/tenants/${props.tenant.id}`, form.value, {
      onSuccess: () => { showEditModal.value = false; success('Tenant diperbarui') },
      onError: (err) => error(err),
      onFinish: () => { loading.value = false },
    })
  } catch (e) { loading.value = false }
}

function suspendTenant() {
  if (confirm('Tangguhkan tenant ini?')) {
    router.post(`/tenants/${props.tenant.id}/suspend`, { reason: 'Ditangguhkan oleh admin' }, {
      onSuccess: () => success('Tenant ditangguhkan'),
      onError: (err) => error(err),
    })
  }
}

function activateTenant() {
  router.post(`/tenants/${props.tenant.id}/activate`, {}, {
    onSuccess: () => success('Tenant diaktifkan'),
    onError: (err) => error(err),
  })
}
</script>

<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="w-12 h-12 bg-primary/10 rounded-xl flex items-center justify-center font-bold text-primary text-xl">{{ tenant.name?.charAt(0) }}</div>
          <div>
            <h1 class="text-2xl font-bold">{{ tenant.name }}</h1>
            <p class="text-sm text-muted-foreground">{{ tenant.email || '-' }} • <Badge :variant="statusColor[tenant.status]" :label="statusLabel[tenant.status]" /></p>
          </div>
        </div>
        <div class="flex gap-2">
          <Button variant="outline" @click="openEdit"><PencilIcon class="w-4 h-4" /> Edit</Button>
          <Button v-if="tenant.status === 'active' || tenant.status === 'trial'" variant="danger" @click="suspendTenant"><NoSymbolIcon class="w-4 h-4" /> Tangguhkan</Button>
          <Button v-else @click="activateTenant"><CheckCircleIcon class="w-4 h-4" /> Aktifkan</Button>
        </div>
      </div>
    </template>

    <!-- Info Cards -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center"><BuildingOffice2Icon class="w-5 h-5 text-blue-600" /></div>
          <div><p class="text-xs text-muted-foreground">Status</p><p class="font-bold">{{ statusLabel[tenant.status] }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-indigo-100 rounded-lg flex items-center justify-center"><CurrencyDollarIcon class="w-5 h-5 text-indigo-600" /></div>
          <div><p class="text-xs text-muted-foreground">Paket</p><p class="font-bold">{{ tenant.plan?.name || 'Free' }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center"><CheckCircleIcon class="w-5 h-5 text-green-600" /></div>
          <div><p class="text-xs text-muted-foreground">Pemilik</p><p class="font-bold">{{ tenant.owner?.name || '-' }}</p></div>
        </div>
      </Card>
      <Card>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-yellow-100 rounded-lg flex items-center justify-center"><ClockIcon class="w-5 h-5 text-yellow-600" /></div>
          <div><p class="text-xs text-muted-foreground">Bergabung</p><p class="font-bold">{{ tenant.created_at ? new Date(tenant.created_at).toLocaleDateString('id-ID') : '-' }}</p></div>
        </div>
      </Card>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Detail -->
      <Card title="Detail Tenant" class="lg:col-span-1">
        <div class="space-y-3 text-sm">
          <div class="flex justify-between"><span class="text-muted-foreground">Telepon</span><span>{{ tenant.phone || '-' }}</span></div>
          <div class="flex justify-between"><span class="text-muted-foreground">Alamat</span><span class="text-right max-w-[200px]">{{ tenant.address || '-' }}</span></div>
          <div class="flex justify-between"><span class="text-muted-foreground">Kota</span><span>{{ tenant.city || '-' }}</span></div>
          <div class="flex justify-between"><span class="text-muted-foreground">Provinsi</span><span>{{ tenant.province || '-' }}</span></div>
          <div class="flex justify-between"><span class="text-muted-foreground">NPWP</span><span>{{ tenant.tax_number || '-' }}</span></div>
          <div class="flex justify-between"><span class="text-muted-foreground">Domain</span><span>{{ tenant.domain || '-' }}</span></div>
          <div v-if="tenant.trial_ends_at" class="flex justify-between"><span class="text-muted-foreground">Trial Berakhir</span><span :class="tenant.status === 'trial' ? 'text-yellow-600 font-medium' : ''">{{ new Date(tenant.trial_ends_at).toLocaleDateString('id-ID') }}</span></div>
          <div v-if="tenant.suspended_at" class="flex justify-between"><span class="text-muted-foreground">Suspensi</span><span class="text-red-600">{{ tenant.suspension_reason || 'Ditangguhkan' }}</span></div>
        </div>
      </Card>

      <!-- Invoices -->
      <Card title="Riwayat Invoice" class="lg:col-span-2">
        <div v-if="!invoices.data?.length" class="py-8 text-center text-muted-foreground">Belum ada invoice</div>
        <div v-else class="space-y-2">
          <div v-for="inv in invoices.data" :key="inv.id" class="flex items-center justify-between p-3 bg-muted rounded-lg">
            <div>
              <p class="font-medium text-sm">{{ inv.invoice_number }}</p>
              <p class="text-xs text-muted-foreground">{{ inv.plan?.name }} • {{ inv.issued_at ? new Date(inv.issued_at).toLocaleDateString('id-ID') : '-' }}</p>
            </div>
            <div class="text-right">
              <p class="font-medium">{{ fc(inv.total) }}</p>
              <Badge :variant="invoiceColor[inv.status]" :label="inv.status" />
            </div>
          </div>
        </div>
      </Card>
    </div>

    <!-- Edit Modal -->
    <Modal v-model="showEditModal" title="Edit Tenant" @confirm="saveEdit" :loading="loading" size="lg">
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div class="col-span-2">
            <label class="block text-sm font-medium mb-1">Nama *</label>
            <input v-model="form.name" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" required />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Email</label>
            <input v-model="form.email" type="email" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Telepon</label>
            <input v-model="form.phone" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div class="col-span-2">
            <label class="block text-sm font-medium mb-1">Alamat</label>
            <input v-model="form.address" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Kota</label>
            <input v-model="form.city" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Provinsi</label>
            <input v-model="form.province" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Status</label>
            <select v-model="form.status" class="w-full px-3 py-2 border border-border rounded-lg text-sm">
              <option value="active">Aktif</option>
              <option value="trial">Trial</option>
              <option value="inactive">Nonaktif</option>
              <option value="suspended">Suspended</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Paket</label>
            <select v-model="form.plan_id" class="w-full px-3 py-2 border border-border rounded-lg text-sm">
              <option :value="null">Free</option>
              <option v-for="p in $page.props.plans || []" :key="p.id" :value="p.id">{{ p.name }}</option>
            </select>
          </div>
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>
