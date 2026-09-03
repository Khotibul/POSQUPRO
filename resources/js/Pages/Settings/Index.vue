<script setup>
import { ref, computed } from 'vue'
import { router, usePage } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Input from '@/Components/UI/Input.vue'
import Modal from '@/Components/UI/Modal.vue'
import Table from '@/Components/UI/Table.vue'
import Badge from '@/Components/UI/Badge.vue'
import {
  Cog6ToothIcon, BuildingOfficeIcon, CreditCardIcon,
  PrinterIcon, ShieldCheckIcon, UserGroupIcon, CircleStackIcon
} from '@heroicons/vue/24/outline'

const page = usePage()
const { success, error } = useToast()

const props = defineProps({
  settings: { type: Array, default: () => [] },
  users: { type: Object, default: () => ({ data: [] }) },
  roles: { type: Array, default: () => [] },
})

const activeTab = ref('store')
const showModal = ref(false)
const editingSetting = ref(null)
const form = ref({ key: '', group: 'general', value: '', type: 'string', label: '', description: '', is_public: false })

const tabs = [
  { id: 'store', label: 'Toko', icon: BuildingOfficeIcon },
  { id: 'payment', label: 'Pembayaran', icon: CreditCardIcon },
  { id: 'printer', label: 'Printer', icon: PrinterIcon },
  { id: 'tax', label: 'Pajak', icon: Cog6ToothIcon },
  { id: 'system', label: 'Sistem', icon: CircleStackIcon },
]

const filteredSettings = computed(() => props.settings.filter(s => s.group === activeTab.value))

const settingForm = ref({ store_name: '', store_phone: '', store_address: '', receipt_footer: '' })

function openModal(setting = null) {
  editingSetting.value = setting
  if (setting) form.value = { ...setting }
  else form.value = { key: '', group: activeTab.value, value: '', type: 'string', label: '', description: '', is_public: false }
  showModal.value = true
}
async function saveSetting() {
  if (!form.value.key) { error('Key wajib'); return }
  try {
    if (editingSetting.value) {
      await router.put(`/api/v1/settings/${editingSetting.value.id}`, form.value, { onSuccess: () => { showModal.value = false; success('Disimpan'); router.reload() } })
    } else {
      await router.post('/api/v1/settings', form.value, { onSuccess: () => { showModal.value = false; success('Ditambahkan'); router.reload() } })
    }
  } catch (e) { error('Gagal') }
}
</script>
<template>
  <AppLayout>
    <template #header>
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold">Pengaturan</h1>
        <button type="button" @click="openModal()" class="px-4 py-2 bg-indigo-600 text-white rounded-lg text-sm hover:bg-indigo-700">Tambah Setting</button>
      </div>
    </template>

    <!-- Tabs -->
    <div class="flex gap-2 mb-6 overflow-x-auto pb-2">
      <button v-for="t in tabs" :key="t.id" @click="activeTab=t.id" :class="['flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium whitespace-nowrap', activeTab===t.id ? 'bg-indigo-600 text-white' : 'bg-card text-gray-600 border hover:bg-muted']">
        <component :is="t.icon" class="w-4 h-4" /> {{ t.label }}
      </button>
    </div>

    <!-- Store Tab -->
    <div v-if="activeTab==='store'" class="space-y-6">
      <Card title="Informasi Toko">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Input v-model="settingForm.store_name" label="Nama Toko" placeholder="POSQUPRO" />
          <Input v-model="settingForm.store_phone" label="Telepon" placeholder="0812..." />
          <Input v-model="settingForm.store_address" label="Alamat" placeholder="Jl. ..." />
          <Input v-model="settingForm.receipt_footer" label="Footer Struk" placeholder="Terima kasih" />
        </div>
        <p class="text-xs text-gray-400 mt-4">DB: <b>posqu_pro_desktop</b> • Sinkron dengan POS Desktop Java • Cabang: MAIN</p>
      </Card>
      <Card title="Daftar Setting">
        <Table :columns="[{key:'key',label:'Key'},{key:'value',label:'Value'},{key:'group',label:'Group',width:100}]" :data="filteredSettings" emptyMessage="Belum ada setting" />
      </Card>
    </div>

    <!-- Payment Tab -->
    <div v-if="activeTab==='payment'" class="space-y-6">
      <Card title="Metode Pembayaran">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
          <label v-for="m in ['cash','card','qris','transfer']" :key="m" class="flex items-center gap-2 p-3 border rounded-lg">
            <input type="checkbox" checked class="w-4 h-4" /> <span class="capitalize">{{ m }}</span>
          </label>
        </div>
      </Card>
    </div>

    <!-- Printer Tab -->
    <div v-if="activeTab==='printer'" class="space-y-6">
      <Card title="Printer Thermal">
        <div class="grid grid-cols-2 gap-4">
          <Input v-model="settingForm.store_name" label="Tipe Printer" placeholder="thermal" />
          <Input v-model="settingForm.store_phone" label="Port / IP" placeholder="COM3 / 192.168.1.100" />
        </div>
      </Card>
    </div>

    <!-- Tax Tab -->
    <div v-if="activeTab==='tax'" class="space-y-6">
      <Card title="Tarif Pajak">
        <Table :columns="[{key:'key',label:'Key'},{key:'value',label:'Rate'}]" :data="filteredSettings" emptyMessage="Belum ada pajak" />
      </Card>
    </div>

    <!-- System Tab -->
    <div v-if="activeTab==='system'" class="space-y-6">
      <Card title="Sistem">
        <div class="grid grid-cols-2 gap-4 text-sm">
          <div><span class="text-muted-foreground">Laravel</span><p class="font-mono">13.x</p></div>
          <div><span class="text-muted-foreground">PHP</span><p class="font-mono">8.4</p></div>
          <div><span class="text-muted-foreground">Database</span><p class="font-mono">posqu_pro_desktop (MySQL 9.7)</p></div>
          <div><span class="text-muted-foreground">Produk</span><p class="font-mono">{{ props.settings.length }} settings</p></div>
        </div>
      </Card>
    </div>

    <Modal v-model="showModal" :title="editingSetting ? 'Edit Setting' : 'Tambah Setting'" @confirm="saveSetting">
      <div class="space-y-3">
        <Input v-model="form.key" label="Key *" required :disabled="!!editingSetting" />
        <Input v-model="form.value" label="Value" />
        <Input v-model="form.label" label="Label" />
        <select v-model="form.group" class="w-full border rounded px-3 py-2 text-sm"><option value="general">general</option><option value="store">store</option><option value="payment">payment</option><option value="printer">printer</option><option value="tax">tax</option><option value="system">system</option></select>
      </div>
    </Modal>
  </AppLayout>
</template>
