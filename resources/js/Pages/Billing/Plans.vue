<script setup>
import { ref } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Button from '@/Components/UI/Button.vue'
import Modal from '@/Components/UI/Modal.vue'
import {
  PlusIcon, PencilIcon, TrashIcon, CheckIcon, CurrencyDollarIcon
} from '@heroicons/vue/24/outline'

const { success, error } = useToast()

const props = defineProps({
  plans: { type: Array, default: () => [] },
})

const showModal = ref(false)
const editingPlan = ref(null)
const loading = ref(false)
const form = ref({
  name: '', slug: '', description: '', price: 0, price_yearly: 0,
  trial_days: 14, max_users: 1, max_products: 100, max_branches: 1,
  features: [], is_active: true,
})

const featureOptions = ['pos', 'inventory', 'reports', 'purchase_orders', 'stock_counts', 'multi_branch', 'api_access', 'priority_support']
const fc = (v) => 'Rp ' + Number(v || 0).toLocaleString('id-ID')

function openCreate() {
  editingPlan.value = null
  form.value = { name: '', slug: '', description: '', price: 0, price_yearly: 0, trial_days: 14, max_users: 1, max_products: 100, max_branches: 1, features: [], is_active: true }
  showModal.value = true
}

function openEdit(plan) {
  editingPlan.value = plan
  form.value = {
    name: plan.name, slug: plan.slug, description: plan.description || '',
    price: plan.price, price_yearly: plan.price_yearly || 0,
    trial_days: plan.trial_days || 0, max_users: plan.max_users,
    max_products: plan.max_products, max_branches: plan.max_branches,
    features: plan.features || [], is_active: plan.is_active,
  }
  showModal.value = true
}

async function savePlan() {
  loading.value = true
  const url = editingPlan.value ? `/billing/plans/${editingPlan.value.id}` : '/billing/plans'
  const method = editingPlan.value ? router.put : router.post
  try {
    await method(url, form.value, {
      onSuccess: () => { showModal.value = false; success(editingPlan.value ? 'Paket diperbarui' : 'Paket ditambahkan') },
      onError: (err) => error(err),
      onFinish: () => { loading.value = false },
    })
  } catch (e) { loading.value = false }
}

function deletePlan(plan) {
  if (confirm(`Hapus paket "${plan.name}"?`)) {
    router.delete(`/billing/plans/${plan.id}`, {
      onSuccess: () => success('Paket dihapus'),
      onError: (err) => error(err),
    })
  }
}

function toggleFeature(f) {
  const idx = form.value.features.indexOf(f)
  if (idx === -1) form.value.features.push(f)
  else form.value.features.splice(idx, 1)
}
</script>

<template>
  <AppLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold">Paket Langganan</h1>
          <p class="text-sm text-muted-foreground">Kelola paket billing SaaS</p>
        </div>
        <Button @click="openCreate"><PlusIcon class="w-4 h-4" /> Tambah Paket</Button>
      </div>
    </template>

    <!-- Plan Cards -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
      <div v-for="plan in props.plans" :key="plan.id" class="relative">
        <Card :class="!plan.is_active ? 'opacity-50' : ''">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-2">
              <div class="w-10 h-10 bg-primary/10 rounded-lg flex items-center justify-center">
                <CurrencyDollarIcon class="w-5 h-5 text-primary" />
              </div>
              <div>
                <h3 class="font-bold text-lg">{{ plan.name }}</h3>
                <p class="text-xs text-muted-foreground">{{ plan.slug }}</p>
              </div>
            </div>
            <div class="flex gap-1">
              <button @click="openEdit(plan)" class="p-1.5 rounded hover:bg-muted"><PencilIcon class="w-4 h-4" /></button>
              <button @click="deletePlan(plan)" class="p-1.5 rounded hover:bg-destructive/10 text-destructive"><TrashIcon class="w-4 h-4" /></button>
            </div>
          </div>

          <div class="text-center py-4 border-y border-border mb-4">
            <p class="text-3xl font-bold">{{ fc(plan.price) }}</p>
            <p class="text-sm text-muted-foreground">/ bulan</p>
            <p v-if="plan.price_yearly" class="text-sm text-green-600 mt-1">Tahunan: {{ fc(plan.price_yearly) }}/tahun (hemat {{ Math.round((1 - plan.price_yearly / (plan.price * 12)) * 100) }}%)</p>
          </div>

          <div class="space-y-2 text-sm mb-4">
            <div class="flex items-center gap-2"><CheckIcon class="w-4 h-4 text-green-600" /> <span>Maks {{ plan.max_users }} user</span></div>
            <div class="flex items-center gap-2"><CheckIcon class="w-4 h-4 text-green-600" /> <span>Maks {{ plan.max_products }} produk</span></div>
            <div class="flex items-center gap-2"><CheckIcon class="w-4 h-4 text-green-600" /> <span>Maks {{ plan.max_branches }} cabang</span></div>
            <div v-if="plan.trial_days" class="flex items-center gap-2"><CheckIcon class="w-4 h-4 text-blue-600" /> <span>{{ plan.trial_days }} hari trial</span></div>
          </div>

          <div v-if="plan.features?.length" class="flex flex-wrap gap-1 mb-4">
            <span v-for="f in plan.features" :key="f" class="px-2 py-0.5 bg-primary/10 text-primary text-xs rounded-full">{{ f }}</span>
          </div>

          <div class="flex items-center justify-between text-xs text-muted-foreground">
            <span>{{ plan.tenants_count || 0 }} tenant</span>
            <Badge :variant="plan.is_active ? 'success' : 'warning'" :label="plan.is_active ? 'Aktif' : 'Nonaktif'" />
          </div>
        </Card>
      </div>

      <!-- Add Plan Card -->
      <button @click="openCreate" class="border-2 border-dashed border-border rounded-xl p-6 flex flex-col items-center justify-center text-muted-foreground hover:border-primary hover:text-primary transition-colors min-h-[300px]">
        <PlusIcon class="w-12 h-12 mb-2" />
        <p class="font-medium">Tambah Paket Baru</p>
      </button>
    </div>

    <!-- Create/Edit Modal -->
    <Modal v-model="showModal" :title="editingPlan ? 'Edit Paket' : 'Tambah Paket Baru'" @confirm="savePlan" :loading="loading" size="lg">
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-1">Nama Paket *</label>
            <input v-model="form.name" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" placeholder="Pro" required />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Slug</label>
            <input v-model="form.slug" type="text" class="w-full px-3 py-2 border border-border rounded-lg text-sm" placeholder="auto-generated" />
          </div>
          <div class="col-span-2">
            <label class="block text-sm font-medium mb-1">Deskripsi</label>
            <textarea v-model="form.description" rows="2" class="w-full px-3 py-2 border border-border rounded-lg text-sm"></textarea>
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Harga Bulanan (Rp) *</label>
            <input v-model.number="form.price" type="number" min="0" class="w-full px-3 py-2 border border-border rounded-lg text-sm" required />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Harga Tahunan (Rp)</label>
            <input v-model.number="form.price_yearly" type="number" min="0" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Trial (hari)</label>
            <input v-model.number="form.trial_days" type="number" min="0" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Maks User</label>
            <input v-model.number="form.max_users" type="number" min="1" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Maks Produk</label>
            <input v-model.number="form.max_products" type="number" min="1" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Maks Cabang</label>
            <input v-model.number="form.max_branches" type="number" min="1" class="w-full px-3 py-2 border border-border rounded-lg text-sm" />
          </div>
        </div>
        <div>
          <label class="block text-sm font-medium mb-2">Fitur</label>
          <div class="flex flex-wrap gap-2">
            <button v-for="f in featureOptions" :key="f" @click="toggleFeature(f)"
              class="px-3 py-1 rounded-full text-sm border transition-colors"
              :class="form.features.includes(f) ? 'bg-primary text-primary-foreground border-primary' : 'border-border text-muted-foreground hover:border-primary'">
              {{ f.replace('_', ' ') }}
            </button>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <input type="checkbox" v-model="form.is_active" class="w-4 h-4 text-primary rounded" />
          <label class="text-sm">Paket Aktif</label>
        </div>
      </div>
    </Modal>
  </AppLayout>
</template>
