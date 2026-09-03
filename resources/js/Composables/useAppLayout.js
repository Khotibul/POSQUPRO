import { ref, computed } from 'vue'
import { router } from '@inertiajs/vue3'

const sidebarOpen = ref(true)
const sidebarCollapsed = ref(false)
const mobileSidebarOpen = ref(false)

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

function closeMobileSidebar() {
  mobileSidebarOpen.value = false
}

function navigateShortcut(route) {
  router.visit(route)
  closeMobileSidebar()
}

const navItems = [
  { name: 'dashboard', label: 'Dashboard', icon: 'HomeIcon', route: '/dashboard', shortcut: 'F1' },
  { name: 'pos', label: 'POS / Kasir', icon: 'CreditCardIcon', route: '/pos', shortcut: 'F2', roles: ['Cashier', 'Super Admin', 'Admin'] },
  { name: 'parked', label: 'Transaksi Tertunda', icon: 'PauseCircleIcon', route: '/parked-transactions', shortcut: 'F3', roles: ['Cashier', 'Super Admin', 'Admin'] },
  { name: 'products', label: 'Produk', icon: 'CubeIcon', route: '/products', roles: ['Warehouse Manager', 'Super Admin', 'Admin'] },
  { name: 'categories', label: 'Kategori', icon: 'TagIcon', route: '/categories', roles: ['Warehouse Manager', 'Super Admin', 'Admin'] },
  { name: 'units', label: 'Satuan', icon: 'ScaleIcon', route: '/units', roles: ['Warehouse Manager', 'Super Admin', 'Admin'] },
  { name: 'taxes', label: 'Pajak', icon: 'ReceiptPercentIcon', route: '/taxes', roles: ['Super Admin', 'Admin'] },
  { name: 'inventory', label: 'Inventory', icon: 'ArchiveBoxIcon', route: '/inventory', shortcut: 'F5', roles: ['Warehouse Manager', 'Super Admin', 'Admin'] },
  { name: 'warehouses', label: 'Gudang', icon: 'BuildingStorefrontIcon', route: '/warehouses', roles: ['Warehouse Manager', 'Super Admin', 'Admin'] },
  { name: 'branches', label: 'Cabang', icon: 'BuildingOffice2Icon', route: '/branches', roles: ['Super Admin', 'Admin'] },
  { name: 'transactions', label: 'Transaksi', icon: 'DocumentTextIcon', route: '/transactions', shortcut: 'F4', roles: ['Super Admin', 'Admin', 'Finance'] },
  { name: 'customers', label: 'Pelanggan', icon: 'UsersIcon', route: '/customers', roles: ['Super Admin', 'Admin', 'Cashier'] },
  { name: 'suppliers', label: 'Supplier', icon: 'TruckIcon', route: '/suppliers', roles: ['Super Admin', 'Admin', 'Warehouse Manager'] },
  { name: 'purchaseOrders', label: 'Purchase Order', icon: 'ShoppingBagIcon', route: '/purchase-orders', shortcut: 'F7', roles: ['Warehouse Manager', 'Super Admin', 'Admin'] },
  { name: 'stockCounts', label: 'Stock Opname', icon: 'ClipboardDocumentListIcon', route: '/stock-counts', shortcut: 'F8', roles: ['Warehouse Manager', 'Super Admin', 'Admin'] },
  { name: 'register', label: 'Register & Shift', icon: 'BanknotesIcon', route: '/register', shortcut: 'F9', roles: ['Cashier', 'Super Admin', 'Admin'] },
  { name: 'reports', label: 'Laporan', icon: 'ChartBarIcon', route: '/reports', shortcut: 'F6', roles: ['Super Admin', 'Admin', 'Finance'] },
  { name: 'settings', label: 'Pengaturan', icon: 'Cog6ToothIcon', route: '/settings', shortcut: 'F10', roles: ['Super Admin', 'Admin'] },
  { name: 'users', label: 'Pengguna & RBAC', icon: 'UserGroupIcon', route: '/users', roles: ['Super Admin', 'Admin'] },
]

export function useAppLayout() {
  return {
    sidebarOpen,
    sidebarCollapsed,
    mobileSidebarOpen,
    shortcuts,
    navItems,
    toggleSidebar,
    closeMobileSidebar,
    navigateShortcut,
  }
}