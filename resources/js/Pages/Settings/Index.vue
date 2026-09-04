<script setup>
import { ref, computed } from 'vue'
import { router } from '@inertiajs/vue3'
import { useToast } from '@/Composables/useToast'
import AppLayout from '@/Layouts/AppLayout.vue'
import Card from '@/Components/UI/Card.vue'
import Badge from '@/Components/UI/Badge.vue'
import {
  BuildingOfficeIcon, CreditCardIcon, PrinterIcon,
  Cog6ToothIcon, CheckCircleIcon, XCircleIcon
} from '@heroicons/vue/24/outline'

const { success, error } = useToast()

const props = defineProps({
  settings: { type: Array, default: () => [] },
  taxes: { type: Array, default: () => [] },
  paymentMethods: { type: Array, default: () => [] },
  branches: { type: Array, default: () => [] },
})

const activeTab = ref('store')
const processing = ref(false)

const tabs = [
  { id: 'store', label: 'Toko', icon: BuildingOfficeIcon },
  { id: 'payment', label: 'Pembayaran', icon: CreditCardIcon },
  { id: 'printer', label: 'Printer', icon: PrinterIcon },
  { id: 'tax', label: 'Pajak', icon: Cog6ToothIcon },
]

function getSetting(key) {
  return props.settings.find(s => s.key === key)?.value || ''
}

function setSetting(key, value) {
  const idx = props.settings.findIndex(s => s.key === key)
  if (idx >= 0) props.settings[idx].value = value
  else props.settings.push({ key, value, group: '' })
}

// Store form
const storeForm = ref({
  store_name: getSetting('store.name'),
  store_phone: getSetting('store.phone'),
  store_address: getSetting('store.address'),
  receipt_header: getSetting('receipt.header'),
  receipt_footer: getSetting('receipt.footer'),
})

async function saveStore() {
  processing.value = true
  try {
    await router.post('/settings', {
      group: 'store',
      settings: Object.entries(storeForm.value).map(([key, value]) => ({ key, value })),
    }, { onFinish: () => { processing.value = false } })
  } catch (e) { error('Gagal menyimpan') }
}

// Printer form
const printerForm = ref({
  'printer.connection.type': getSetting('printer.connection.type'),
  'printer.name': getSetting('printer.name'),
  'printer.bluetooth.mac': getSetting('printer.bluetooth.mac'),
  'printer.paper.width': getSetting('printer.paper.width'),
  'printer.font.size': getSetting('printer.font.size'),
  'printer.font.family': getSetting('printer.font.family'),
  'printer.margin.top': getSetting('printer.margin.top'),
  'printer.margin.bottom': getSetting('printer.margin.bottom'),
  'printer.margin.left': getSetting('printer.margin.left'),
  'printer.spacing.line': getSetting('printer.spacing.line'),
  'printer.alignment': getSetting('printer.alignment'),
  'printer.auto.print': getSetting('printer.auto.print'),
  'drawer.printer': getSetting('drawer.printer'),
})

const printerType = computed({
  get: () => printerForm.value['printer.connection.type'] || 'Bluetooth',
  set: (v) => { printerForm.value['printer.connection.type'] = v }
})

const isAutoPrint = computed({
  get: () => printerForm.value['printer.auto.print'] === 'true',
  set: (v) => { printerForm.value['printer.auto.print'] = v ? 'true' : 'false' }
})

async function savePrinter() {
  processing.value = true
  try {
    await router.post('/settings', {
      group: 'printer',
      settings: Object.entries(printerForm.value).map(([key, value]) => ({ key, value })),
    }, { onFinish: () => { processing.value = false } })
  } catch (e) { error('Gagal menyimpan') }
}

// Tax
const showTaxModal = ref(false)
const editingTax = ref(null)
const taxForm = ref({ name: '', rate: 0 })

function openTaxModal(tax = null) {
  editingTax.value = tax
  taxForm.value = tax ? { name: tax.name, rate: tax.rate } : { name: '', rate: 0 }
  showTaxModal.value = true
}

async function saveTax() {
  if (!taxForm.value.name) { error('Nama wajib'); return }
  processing.value = true
  try {
    if (editingTax.value) {
      await router.put(`/settings/tax/${editingTax.value.id}`, taxForm.value, {
        onSuccess: () => { showTaxModal.value = false; success('Pajak diperbarui') },
        onFinish: () => { processing.value = false },
      })
    } else {
      await router.post('/settings/tax', taxForm.value, {
        onSuccess: () => { showTaxModal.value = false; success('Pajak ditambahkan') },
        onFinish: () => { processing.value = false },
      })
    }
  } catch (e) { error('Gagal') }
}

async function deleteTax(id) {
  if (!confirm('Hapus pajak ini?')) return
  await router.delete(`/settings/tax/${id}`, { onSuccess: () => success('Dihapus') })
}

async function toggleTaxActive(tax) {
  await router.put(`/settings/tax/${tax.id}`, { is_active: !tax.is_active }, { onSuccess: () => success('Diperbarui') })
}

// Payment Method
async function togglePaymentMethod(pm) {
  await router.put(`/settings/payment-method/${pm.id}`, { active: pm.active ? 0 : 1 }, { onSuccess: () => success('Diperbarui') })
}

// Receipt Preview
const showReceiptPreview = ref(false)

function printReceipt() { window.print() }
const receiptPreviewWidth = computed(() => {
  const w = Number(printerForm.value['printer.paper.width']) || 80
  return Math.max(280, Math.min(800, w * (80 / 30)))
})
</script>

<template>
  <AppLayout>
    <template #header>
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold">Pengaturan</h1>
      </div>
    </template>

    <!-- Tabs -->
    <div class="flex gap-2 mb-6 overflow-x-auto pb-2">
      <button v-for="t in tabs" :key="t.id" @click="activeTab = t.id"
        :class="['flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium whitespace-nowrap transition-colors',
          activeTab === t.id ? 'bg-primary text-primary-foreground' : 'bg-card text-muted-foreground border border-border hover:bg-accent']">
        <component :is="t.icon" class="w-4 h-4" /> {{ t.label }}
      </button>
    </div>

    <!-- ==================== STORE TAB ==================== -->
    <div v-if="activeTab === 'store'" class="space-y-6 max-w-3xl">
      <Card title="Informasi Toko">
        <div class="space-y-4">
          <div>
            <label class="text-sm font-medium">Nama Toko</label>
            <input v-model="storeForm.store_name" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="POSQUPRO" />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="text-sm font-medium">Telepon</label>
              <input v-model="storeForm.store_phone" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="0812..." />
            </div>
            <div>
              <label class="text-sm font-medium">Cabang</label>
              <div class="mt-1 px-3 py-2 bg-muted rounded-md text-sm">{{ branches[0]?.name || '-' }} ({{ branches[0]?.code || '-' }})</div>
            </div>
          </div>
          <div>
            <label class="text-sm font-medium">Alamat</label>
            <textarea v-model="storeForm.store_address" rows="2" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="Jl. ..."></textarea>
          </div>
        </div>
      </Card>

      <Card title="Struk">
        <div class="space-y-4">
          <div>
            <label class="text-sm font-medium">Header Struk</label>
            <input v-model="storeForm.receipt_header" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="Terima Kasih Telah Berbelanja" />
          </div>
          <div>
            <label class="text-sm font-medium">Footer Struk</label>
            <textarea v-model="storeForm.receipt_footer" rows="2" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="Terima kasih, kunjungi lagi!"></textarea>
          </div>
          <button @click="showReceiptPreview = true" class="text-sm text-primary hover:underline">Lihat Preview Struk</button>
        </div>
      </Card>

      <div class="flex justify-end">
        <button @click="saveStore" :disabled="processing" class="px-6 py-2.5 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50">
          {{ processing ? 'Menyimpan...' : 'Simpan Pengaturan Toko' }}
        </button>
      </div>
    </div>

    <!-- ==================== PAYMENT TAB ==================== -->
    <div v-if="activeTab === 'payment'" class="space-y-6 max-w-3xl">
      <Card title="Metode Pembayaran">
        <p class="text-sm text-muted-foreground mb-4">Aktifkan/nonaktifkan metode pembayaran yang tersedia di POS</p>
        <div class="space-y-2">
          <div v-for="pm in paymentMethods" :key="pm.id"
            class="flex items-center justify-between p-4 border border-border rounded-lg hover:bg-accent/50 transition-colors">
            <div class="flex items-center gap-3">
              <div :class="['w-10 h-10 rounded-lg flex items-center justify-center text-sm font-bold',
                pm.active ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground']">
                {{ pm.name.substring(0, 2) }}
              </div>
              <div>
                <p class="font-medium text-sm">{{ pm.label || pm.name }}</p>
                <p class="text-xs text-muted-foreground">{{ pm.name }}</p>
              </div>
            </div>
            <button @click="togglePaymentMethod(pm)"
              :class="['relative inline-flex h-6 w-11 items-center rounded-full transition-colors',
                pm.active ? 'bg-primary' : 'bg-muted']">
              <span :class="['inline-block h-4 w-4 transform rounded-full bg-white transition-transform',
                pm.active ? 'translate-x-6' : 'translate-x-1']" />
            </button>
          </div>
        </div>
      </Card>
    </div>

    <!-- ==================== PRINTER TAB ==================== -->
    <div v-if="activeTab === 'printer'" class="space-y-6 max-w-3xl">
      <Card title="Koneksi Printer">
        <div class="space-y-4">
          <div>
            <label class="text-sm font-medium">Tipe Koneksi</label>
            <div class="flex gap-3 mt-2">
              <button @click="printerType = 'USB'"
                :class="['flex-1 p-4 border-2 rounded-lg text-center transition-all',
                  printerType === 'USB' ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50']">
                <div class="text-2xl mb-1">🔌</div>
                <p class="font-medium text-sm">USB</p>
                <p class="text-xs text-muted-foreground">Kabel langsung</p>
              </button>
              <button @click="printerType = 'Bluetooth'"
                :class="['flex-1 p-4 border-2 rounded-lg text-center transition-all',
                  printerType === 'Bluetooth' ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50']">
                <div class="text-2xl mb-1">📶</div>
                <p class="font-medium text-sm">Bluetooth</p>
                <p class="text-xs text-muted-foreground">Nirkabel</p>
              </button>
              <button @click="printerType = 'Network'"
                :class="['flex-1 p-4 border-2 rounded-lg text-center transition-all',
                  printerType === 'Network' ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50']">
                <div class="text-2xl mb-1">🌐</div>
                <p class="font-medium text-sm">Network</p>
                <p class="text-xs text-muted-foreground">WiFi/LAN</p>
              </button>
            </div>
          </div>

          <div v-if="printerType === 'USB'">
            <label class="text-sm font-medium">Nama Printer USB</label>
            <input v-model="printerForm['printer.name']" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="auto / Epson TM-T82" />
            <p class="text-xs text-muted-foreground mt-1">Kosongkan untuk auto-detect</p>
          </div>

          <div v-if="printerType === 'Bluetooth'">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="text-sm font-medium">Nama Printer</label>
                <input v-model="printerForm['printer.name']" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="auto" />
              </div>
              <div>
                <label class="text-sm font-medium">MAC Address</label>
                <input v-model="printerForm['printer.bluetooth.mac']" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="XX:XX:XX:XX:XX:XX" />
              </div>
            </div>
          </div>

          <div v-if="printerType === 'Network'">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="text-sm font-medium">IP Address</label>
                <input v-model="printerForm['printer.name']" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="192.168.1.100" />
              </div>
              <div>
                <label class="text-sm font-medium">Port</label>
                <input v-model="printerForm['drawer.printer']" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="9100" />
              </div>
            </div>
          </div>
        </div>
      </Card>

      <Card title="Format Struk">
        <div class="space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="text-sm font-medium">Lebar Kertas (mm)</label>
              <select v-model="printerForm['printer.paper.width']" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background">
                <option value="58">58mm (Kecil)</option>
                <option value="72">72mm</option>
                <option value="80">80mm (Standard)</option>
              </select>
            </div>
            <div>
              <label class="text-sm font-medium">Alignment</label>
              <select v-model="printerForm['printer.alignment']" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background">
                <option value="left">Kiri</option>
                <option value="center">Tengah</option>
                <option value="right">Kanan</option>
              </select>
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="text-sm font-medium">Ukuran Font</label>
              <input type="number" v-model="printerForm['printer.font.size']" min="5" max="12" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" />
            </div>
            <div>
              <label class="text-sm font-medium">Font Family</label>
              <select v-model="printerForm['printer.font.family']" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background">
                <option value="monospace">Monospace</option>
                <option value="Courier New">Courier New</option>
                <option value="Arial Black">Arial Black</option>
              </select>
            </div>
          </div>
          <div class="grid grid-cols-3 gap-4">
            <div>
              <label class="text-sm font-medium">Margin Atas</label>
              <input type="number" v-model="printerForm['printer.margin.top']" min="0" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" />
            </div>
            <div>
              <label class="text-sm font-medium">Margin Bawah</label>
              <input type="number" v-model="printerForm['printer.margin.bottom']" min="0" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" />
            </div>
            <div>
              <label class="text-sm font-medium">Margin Kiri</label>
              <input type="number" v-model="printerForm['printer.margin.left']" min="0" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" />
            </div>
          </div>
          <div>
            <label class="text-sm font-medium">Spasi Antar Baris (px)</label>
            <input type="number" v-model="printerForm['printer.spacing.line']" min="40" max="120" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" />
          </div>
          <div class="flex items-center justify-between p-4 border border-border rounded-lg">
            <div>
              <p class="font-medium text-sm">Auto Print</p>
              <p class="text-xs text-muted-foreground">Cetak otomatis setelah transaksi berhasil</p>
            </div>
            <button @click="isAutoPrint = !isAutoPrint"
              :class="['relative inline-flex h-6 w-11 items-center rounded-full transition-colors',
                isAutoPrint ? 'bg-primary' : 'bg-muted']">
              <span :class="['inline-block h-4 w-4 transform rounded-full bg-white transition-transform',
                isAutoPrint ? 'translate-x-6' : 'translate-x-1']" />
            </button>
          </div>
        </div>
      </Card>

      <div class="flex justify-between">
        <button @click="showReceiptPreview = true" class="px-6 py-2.5 border border-border rounded-lg hover:bg-accent text-sm">
          Preview Struk
        </button>
        <button @click="savePrinter" :disabled="processing" class="px-6 py-2.5 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50">
          {{ processing ? 'Menyimpan...' : 'Simpan Pengaturan Printer' }}
        </button>
      </div>
    </div>

    <!-- ==================== TAX TAB ==================== -->
    <div v-if="activeTab === 'tax'" class="space-y-6 max-w-3xl">
      <Card title="Tarif Pajak">
        <template #actions>
          <button @click="openTaxModal()" class="px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm hover:bg-primary/90">+ Tambah Pajak</button>
        </template>
        <div class="space-y-2">
          <div v-if="!taxes.length" class="text-center py-8 text-muted-foreground">Belum ada pajak</div>
          <div v-for="tax in taxes" :key="tax.id"
            class="flex items-center justify-between p-4 border border-border rounded-lg">
            <div class="flex items-center gap-3">
              <div :class="['w-10 h-10 rounded-lg flex items-center justify-center text-sm font-bold',
                tax.is_active ? 'bg-green-100 text-green-600' : 'bg-muted text-muted-foreground']">
                {{ tax.rate }}%
              </div>
              <div>
                <p class="font-medium text-sm">{{ tax.name }}</p>
                <p class="text-xs text-muted-foreground">Rate: {{ tax.rate }}%</p>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <button @click="toggleTaxActive(tax)"
                :class="['px-3 py-1 rounded-md text-xs font-medium',
                  tax.is_active ? 'bg-green-100 text-green-600' : 'bg-muted text-muted-foreground']">
                {{ tax.is_active ? 'Aktif' : 'Nonaktif' }}
              </button>
              <button @click="openTaxModal(tax)" class="px-3 py-1 border border-border rounded-md text-xs hover:bg-accent">Edit</button>
              <button @click="deleteTax(tax.id)" class="px-3 py-1 border border-destructive/30 text-destructive rounded-md text-xs hover:bg-destructive/5">Hapus</button>
            </div>
          </div>
        </div>
      </Card>
    </div>

    <!-- ==================== RECEIPT PREVIEW MODAL ==================== -->
    <div v-if="showReceiptPreview" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" @click.self="showReceiptPreview = false">
      <div class="bg-card rounded-xl shadow-2xl max-h-[90vh] overflow-hidden flex flex-col">
        <div class="flex items-center justify-between px-6 py-4 border-b border-border">
          <h3 class="font-semibold">Preview Struk</h3>
          <button @click="showReceiptPreview = false" class="text-muted-foreground hover:text-foreground">&times;</button>
        </div>
        <div class="overflow-y-auto p-6 flex justify-center">
          <div :style="{ width: receiptPreviewWidth + 'px', fontFamily: printerForm['printer.font.family'] || 'monospace', fontSize: (printerForm['printer.font.size'] || 7) + 'px', lineHeight: (printerForm['printer.spacing.line'] || 80) / 10 + 'px' }"
            class="bg-white text-black p-4 border border-gray-300 shadow-inner text-left whitespace-pre-wrap break-words">
            <div class="text-center mb-2">
              <p class="font-bold text-base">{{ storeForm.store_name || 'TOKO POSQU PRO' }}</p>
              <p>{{ storeForm.store_address || 'Alamat Toko' }}</p>
              <p>Telp: {{ storeForm.store_phone || '-' }}</p>
              <p class="border-t border-dashed border-black mt-1 pt-1">--------------------------------</p>
            </div>
            <div class="text-center text-xs mb-2">
              <p>{{ storeForm.receipt_header || 'Terima Kasih Telah Berbelanja' }}</p>
            </div>
            <div class="border-t border-dashed border-black pt-1 mb-1">
              <p>INV-20260904-001</p>
              <p>Kasir: Admin</p>
              <p>Tgl: 04/09/2026 14:30</p>
            </div>
            <div class="border-t border-dashed border-black pt-1 mb-1">
              <div class="flex justify-between"><span>Kopi Arabica 1kg x2</span><span>170.000</span></div>
              <div class="flex justify-between"><span>Gula Pasir 1kg x1</span><span>15.000</span></div>
            </div>
            <div class="border-t border-dashed border-black pt-1 mb-1 space-y-1">
              <div class="flex justify-between"><span>Subtotal</span><span>185.000</span></div>
              <div class="flex justify-between"><span>Diskon</span><span>- 0</span></div>
              <div class="flex justify-between font-bold text-sm"><span>TOTAL</span><span>185.000</span></div>
              <div class="flex justify-between"><span>Tunai</span><span>200.000</span></div>
              <div class="flex justify-between"><span>Kembalian</span><span>15.000</span></div>
            </div>
            <div class="border-t border-dashed border-black pt-2 mt-2 text-center text-xs">
              <p>{{ storeForm.receipt_footer || '' }}</p>
              <p class="mt-1">=== TERIMA KASIH ===</p>
            </div>
          </div>
        </div>
        <div class="px-6 py-3 border-t border-border flex justify-end gap-2">
          <button @click="showReceiptPreview = false" class="px-4 py-2 border border-border rounded-lg text-sm hover:bg-accent">Tutup</button>
          <button @click="printReceipt" class="px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm hover:bg-primary/90">Cetak</button>
        </div>
      </div>
    </div>

    <!-- ==================== TAX MODAL ==================== -->
    <div v-if="showTaxModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" @click.self="showTaxModal = false">
      <div class="bg-card rounded-xl shadow-2xl w-full max-w-md p-6">
        <h3 class="font-semibold text-lg mb-4">{{ editingTax ? 'Edit Pajak' : 'Tambah Pajak' }}</h3>
        <div class="space-y-4">
          <div>
            <label class="text-sm font-medium">Nama Pajak</label>
            <input v-model="taxForm.name" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" placeholder="PPN 11%" />
          </div>
          <div>
            <label class="text-sm font-medium">Rate (%)</label>
            <input type="number" v-model.number="taxForm.rate" min="0" max="100" step="0.5" class="w-full mt-1 border border-input rounded-md px-3 py-2 bg-background" />
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button @click="showTaxModal = false" class="px-4 py-2 border border-border rounded-lg text-sm hover:bg-accent">Batal</button>
          <button @click="saveTax" :disabled="processing" class="px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm hover:bg-primary/90 disabled:opacity-50">
            {{ processing ? 'Menyimpan...' : 'Simpan' }}
          </button>
        </div>
      </div>
    </div>
  </AppLayout>
</template>
