import { ref, computed } from 'vue'
import { router } from '@inertiajs/vue3'

const sidebarCollapsed = ref(false)
const mobileSidebarOpen = ref(false)

const isMobile = ref(typeof window !== 'undefined' ? window.innerWidth < 1024 : false)

function checkMobile() {
  isMobile.value = window.innerWidth < 1024
  if (isMobile.value) {
    sidebarCollapsed.value = false
    mobileSidebarOpen.value = false
  }
}

if (typeof window !== 'undefined') {
  window.addEventListener('resize', checkMobile)
  checkMobile()
}

const shortcuts = ref([
  { key: 'F1', label: 'Dashboard', route: '/dashboard' },
  { key: 'F2', label: 'POS', route: '/pos' },
  { key: 'F3', label: 'Produk', route: '/products' },
  { key: 'F4', label: 'Transaksi', route: '/transactions' },
  { key: 'F5', label: 'Inventory', route: '/inventory' },
  { key: 'F6', label: 'Laporan', route: '/reports' },
  { key: 'F7', label: 'PO', route: '/purchase-orders' },
  { key: 'F8', label: 'Stock Opname', route: '/stock-counts' },
  { key: 'F9', label: 'Register', route: '/register' },
  { key: 'F10', label: 'Pengaturan', route: '/settings' },
])

function toggleSidebar() {
  if (window.innerWidth < 1024) {
    mobileSidebarOpen.value = !mobileSidebarOpen.value
  } else {
    sidebarCollapsed.value = !sidebarCollapsed.value
  }
}

function openMobileSidebar() {
  mobileSidebarOpen.value = true
}

function closeMobileSidebar() {
  mobileSidebarOpen.value = false
}

function navigateShortcut(route) {
  router.visit(route)
  closeMobileSidebar()
}

const navItems = [
  { name: 'dashboard', label: 'Dashboard', icon: 'HomeIcon', route: '/dashboard', shortcut: 'F1', roles: ['Super Admin', 'Admin', 'Warehouse Manager', 'Cashier', 'Finance'] },
  { name: 'saas', label: 'SaaS Dashboard', icon: 'ChartBarIcon', route: '/saas', roles: ['Super Admin'] },
  { name: 'tenants', label: 'Tenant', icon: 'BuildingOffice2Icon', route: '/tenants', roles: ['Super Admin'] },
  { name: 'plans', label: 'Paket & Billing', icon: 'CurrencyDollarIcon', route: '/billing/plans', roles: ['Super Admin'] },
  { name: 'invoices', label: 'Invoice', icon: 'DocumentTextIcon', route: '/billing/invoices', roles: ['Super Admin'] },
  { name: 'pos', label: 'POS / Kasir', icon: 'CreditCardIcon', route: '/pos', shortcut: 'F2', roles: ['Super Admin', 'Admin', 'Cashier'] },
  { name: 'parked', label: 'Transaksi Tertunda', icon: 'PauseCircleIcon', route: '/parked-transactions', roles: ['Super Admin', 'Admin', 'Cashier'] },
  { name: 'transactions', label: 'Riwayat Transaksi', icon: 'ClipboardDocumentListIcon', route: '/transactions', shortcut: 'F4', roles: ['Super Admin', 'Admin', 'Finance'] },
  { name: 'register', label: 'Kas & Shift', icon: 'BanknotesIcon', route: '/register', shortcut: 'F9', roles: ['Super Admin', 'Admin', 'Cashier'] },
  { name: 'products', label: 'Produk', icon: 'CubeIcon', route: '/products', roles: ['Super Admin', 'Admin', 'Warehouse Manager', 'Cashier'] },
  { name: 'categories', label: 'Kategori', icon: 'TagIcon', route: '/categories', roles: ['Super Admin', 'Admin', 'Warehouse Manager'] },
  { name: 'units', label: 'Satuan', icon: 'ScaleIcon', route: '/units', roles: ['Super Admin', 'Admin', 'Warehouse Manager'] },
  { name: 'customers', label: 'Pelanggan', icon: 'UsersIcon', route: '/customers', roles: ['Super Admin', 'Admin', 'Cashier'] },
  { name: 'suppliers', label: 'Supplier', icon: 'TruckIcon', route: '/suppliers', roles: ['Super Admin', 'Admin', 'Warehouse Manager'] },
  { name: 'inventory', label: 'Inventory', icon: 'ArchiveBoxIcon', route: '/inventory', shortcut: 'F5', roles: ['Super Admin', 'Admin', 'Warehouse Manager'] },
  { name: 'warehouses', label: 'Gudang', icon: 'BuildingStorefrontIcon', route: '/warehouses', roles: ['Super Admin', 'Admin', 'Warehouse Manager'] },
  { name: 'branches', label: 'Cabang', icon: 'BuildingOffice2Icon', route: '/branches', roles: ['Super Admin', 'Admin'] },
  { name: 'purchaseOrders', label: 'Purchase Order', icon: 'ShoppingBagIcon', route: '/purchase-orders', shortcut: 'F7', roles: ['Super Admin', 'Admin', 'Warehouse Manager'] },
  { name: 'stockCounts', label: 'Stock Opname', icon: 'ClipboardDocumentListIcon', route: '/stock-counts', shortcut: 'F8', roles: ['Super Admin', 'Admin', 'Warehouse Manager'] },
  { name: 'reports', label: 'Laporan & Analitik', icon: 'ChartBarIcon', route: '/reports', shortcut: 'F6', roles: ['Super Admin', 'Admin', 'Finance'] },
  { name: 'taxes', label: 'Pajak', icon: 'ReceiptPercentIcon', route: '/taxes', roles: ['Super Admin', 'Admin', 'Finance'] },
  { name: 'users', label: 'Pengguna & RBAC', icon: 'UserGroupIcon', route: '/users', roles: ['Super Admin', 'Admin'] },
  { name: 'settings', label: 'Pengaturan', icon: 'Cog6ToothIcon', route: '/settings', shortcut: 'F10', roles: ['Super Admin', 'Admin'] },
]

export function useAppLayout() {
  return {
    sidebarCollapsed,
    mobileSidebarOpen,
    isMobile,
    shortcuts,
    navItems,
    toggleSidebar,
    openMobileSidebar,
    closeMobileSidebar,
    navigateShortcut,
  }
}
