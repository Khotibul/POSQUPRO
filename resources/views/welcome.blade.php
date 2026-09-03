<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>{{ config('app.name', 'POSQUPRO') }} — SIMPLE • SMART • SUCCESS</title>
        <meta name="description" content="POSQUPRO - Point of Sale modern untuk UMKM, retail & resto. SIMPLE • SMART • SUCCESS. Laravel 13 + Vue 3 + MySQL.">
        <link rel="icon" href="/logo.png" type="image/png">
        @vite(['resources/css/app.css', 'resources/js/app.js'])
    </head>
    <body class="bg-background text-foreground antialiased">
        <!-- Header pos-next-js shadcn -->
        <header class="sticky top-0 z-50 w-full border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
            <div class="container mx-auto max-w-7xl flex h-16 items-center justify-between px-4 lg:px-8">
                <div class="flex items-center gap-2">
                    <img src="/logo.png" alt="POSQUPRO" class="h-8 w-auto object-contain" />
                    <span class="hidden font-bold sm:inline-block">POSQUPRO</span>
                </div>
                <nav class="hidden md:flex items-center gap-6 text-sm font-medium text-muted-foreground">
                    <a href="#features" class="hover:text-foreground transition-colors">Fitur</a>
                    <a href="#pricing" class="hover:text-foreground transition-colors">Harga</a>
                    <a href="https://github.com" target="_blank" class="hover:text-foreground transition-colors">Docs</a>
                </nav>
                <div class="flex items-center gap-2">
                    @auth
                        <a href="{{ url('/dashboard') }}" class="inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors">
                            Dashboard
                        </a>
                    @else
                        <a href="{{ route('login') }}" class="inline-flex h-9 items-center justify-center rounded-md border border-input bg-background px-4 py-2 text-sm font-medium hover:bg-accent hover:text-accent-foreground transition-colors">
                            Log in
                        </a>
                        <a href="{{ route('login') }}" class="hidden sm:inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors">
                            Masuk POS
                        </a>
                    @endauth
                </div>
            </div>
        </header>

        <!-- Hero pos-next-js -->
        <section class="container mx-auto max-w-7xl px-4 lg:px-8 py-12 lg:py-20">
            <div class="grid lg:grid-cols-2 gap-12 items-center">
                <div class="space-y-6">
                    <div class="inline-flex items-center rounded-full border border-border bg-muted px-3 py-1 text-xs font-medium">
                        <span class="mr-2 h-2 w-2 rounded-full bg-primary animate-pulse"></span>
                        v{{ app()->version() }} • Laravel 13 + Vue 3 + MySQL
                    </div>
                    <h1 class="text-4xl lg:text-5xl font-bold tracking-tight">
                        POS Modern untuk
                        <span class="text-primary">UMKM, Retail & Resto</span>
                    </h1>
                    <p class="text-lg text-muted-foreground max-w-[600px]">
                        <span class="font-semibold text-foreground">SIMPLE • SMART • SUCCESS</span> — Kelola POS kasir, inventory real-time, laporan analytics, dan multi-cabang dalam satu dashboard shadcn yang cepat.
                    </p>
                    <div class="flex flex-col sm:flex-row gap-3">
                        <a href="{{ url('/dashboard') }}" class="inline-flex h-11 items-center justify-center rounded-md bg-primary px-8 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors">
                            Buka Dashboard →
                        </a>
                        <a href="{{ url('/pos') }}" class="inline-flex h-11 items-center justify-center rounded-md border border-input bg-background px-8 text-sm font-medium hover:bg-accent hover:text-accent-foreground transition-colors">
                            Coba POS Kasir
                        </a>
                    </div>
                    <div class="flex items-center gap-4 text-sm text-muted-foreground pt-2">
                        <div class="flex -space-x-2">
                            <div class="h-8 w-8 rounded-full bg-primary/10 border-2 border-background flex items-center justify-center text-xs font-medium">A</div>
                            <div class="h-8 w-8 rounded-full bg-primary/20 border-2 border-background flex items-center justify-center text-xs font-medium">K</div>
                            <div class="h-8 w-8 rounded-full bg-primary/30 border-2 border-background flex items-center justify-center text-xs font-medium">W</div>
                        </div>
                        <span>Dipercaya 500+ toko</span>
                        <span class="h-4 w-px bg-border"></span>
                        <span>4.9/5 ★★★★★</span>
                    </div>
                </div>
                <div class="relative lg:h-[480px]">
                    <div class="absolute inset-0 bg-gradient-to-br from-primary/20 to-primary/5 rounded-2xl blur-2xl"></div>
                    <div class="relative bg-card border border-border rounded-2xl shadow-xl overflow-hidden">
                        <div class="flex items-center gap-2 px-4 py-3 border-b border-border bg-muted/50">
                            <div class="flex gap-1.5">
                                <div class="h-3 w-3 rounded-full bg-red-500"></div>
                                <div class="h-3 w-3 rounded-full bg-yellow-500"></div>
                                <div class="h-3 w-3 rounded-full bg-green-500"></div>
                            </div>
                            <span class="ml-2 text-xs text-muted-foreground">POSQUPRO • Dashboard</span>
                        </div>
                        <img src="/logo.png" alt="POSQUPRO Dashboard" class="w-full h-auto object-contain p-8 bg-gradient-to-br from-card to-muted/20" />
                        <div class="grid grid-cols-3 gap-3 p-4 bg-muted/30">
                            <div class="bg-card border border-border rounded-lg p-3">
                                <p class="text-xs text-muted-foreground">Hari Ini</p>
                                <p class="font-bold">Rp 2.4jt</p>
                                <p class="text-xs text-green-600">+12%</p>
                            </div>
                            <div class="bg-card border border-border rounded-lg p-3">
                                <p class="text-xs text-muted-foreground">Transaksi</p>
                                <p class="font-bold">48</p>
                                <p class="text-xs text-green-600">+8%</p>
                            </div>
                            <div class="bg-card border border-border rounded-lg p-3">
                                <p class="text-xs text-muted-foreground">Stok Rendah</p>
                                <p class="font-bold text-destructive">5</p>
                                <p class="text-xs text-muted-foreground">Perlu restock</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Features pos-next-js 6 grid -->
        <section id="features" class="container mx-auto max-w-7xl px-4 lg:px-8 py-16 border-t border-border">
            <div class="text-center max-w-2xl mx-auto mb-10">
                <h2 class="text-3xl font-bold tracking-tight">Fitur Lengkap POS Modern</h2>
                <p class="text-muted-foreground mt-2">Semua yang dibutuhkan toko Anda, dari kasir hingga laporan, dalam satu aplikasi.</p>
            </div>
            <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
                @php
                    $features = [
                        ['title' => 'POS Kasir Cepat', 'desc' => 'Barcode scan, keranjang, diskon, split payment (cash/card/QRIS), cetak struk thermal.', 'icon' => 'M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z'],
                        ['title' => 'Inventory Real-time', 'desc' => 'Stok, min_stock, adjustment, stock opname blind count, transfer antar gudang.', 'icon' => 'M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10m0 0l8-4'],
                        ['title' => 'Laporan Analytics', 'desc' => 'Penjualan harian/bulanan, top produk, payment breakdown, profit, export PDF/Excel.', 'icon' => 'M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z'],
                        ['title' => 'Pelanggan & Supplier', 'desc' => 'Manajemen pelanggan (limit kredit), supplier, hutang/piutang, riwayat transaksi.', 'icon' => 'M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z'],
                        ['title' => 'Purchase Order', 'desc' => 'Buat PO, terima parsial/full, auto update stok & hutang supplier (AP).', 'icon' => 'M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2'],
                        ['title' => 'Multi Cabang & RBAC', 'desc' => 'Branch, warehouse, 5 roles (Owner/Admin/Manager/Cashier/Finance) + permission granular.', 'icon' => 'M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4'],
                    ];
                @endphp
                @foreach ($features as $f)
                    <div class="bg-card border border-border rounded-xl p-6 hover:shadow-md transition-shadow">
                        <div class="h-10 w-10 rounded-lg bg-primary/10 flex items-center justify-center mb-4">
                            <svg class="h-5 w-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="{{ $f['icon'] }}"/></svg>
                        </div>
                        <h3 class="font-semibold">{{ $f['title'] }}</h3>
                        <p class="text-sm text-muted-foreground mt-1">{{ $f['desc'] }}</p>
                    </div>
                @endforeach
            </div>
        </section>

        <!-- Pricing pos-next-js -->
        <section id="pricing" class="container mx-auto max-w-7xl px-4 lg:px-8 py-16 border-t border-border bg-muted/20 -mx-4 lg:-mx-8 px-4 lg:px-8">
            <div class="text-center max-w-2xl mx-auto mb-10">
                <h2 class="text-3xl font-bold">Harga Simpel</h2>
                <p class="text-muted-foreground mt-2">Mulai gratis, scale sesuai kebutuhan toko Anda.</p>
            </div>
            <div class="grid md:grid-cols-3 gap-6 max-w-5xl mx-auto">
                <div class="bg-card border border-border rounded-xl p-6">
                    <h3 class="font-semibold">Starter</h3>
                    <p class="text-3xl font-bold mt-2">Gratis</p>
                    <p class="text-sm text-muted-foreground">Untuk 1 toko kecil</p>
                    <ul class="mt-4 space-y-2 text-sm text-muted-foreground">
                        <li>✓ 1 Kasir • 100 Produk</li>
                        <li>✓ POS & Inventory dasar</li>
                        <li>✓ Laporan harian</li>
                    </ul>
                    <a href="{{ url('/login') }}" class="mt-6 inline-flex w-full h-10 items-center justify-center rounded-md border border-input bg-background hover:bg-accent">Mulai Gratis</a>
                </div>
                <div class="bg-card border-2 border-primary rounded-xl p-6 shadow-lg relative">
                    <div class="absolute -top-3 left-1/2 -translate-x-1/2 bg-primary text-primary-foreground px-3 py-1 rounded-full text-xs font-medium">Populer</div>
                    <h3 class="font-semibold">Pro</h3>
                    <p class="text-3xl font-bold mt-2">Rp 149k <span class="text-sm font-normal text-muted-foreground">/bulan</span></p>
                    <p class="text-sm text-muted-foreground">Untuk retail & resto</p>
                    <ul class="mt-4 space-y-2 text-sm">
                        <li>✓ Unlimited Produk & Transaksi</li>
                        <li>✓ Multi Cabang & Gudang</li>
                        <li>✓ Laporan Lengkap + Export</li>
                        <li>✓ Support Prioritas</li>
                    </ul>
                    <a href="{{ url('/login') }}" class="mt-6 inline-flex w-full h-10 items-center justify-center rounded-md bg-primary text-primary-foreground hover:bg-primary/90">Pilih Pro</a>
                </div>
                <div class="bg-card border border-border rounded-xl p-6">
                    <h3 class="font-semibold">Enterprise</h3>
                    <p class="text-3xl font-bold mt-2">Custom</p>
                    <p class="text-sm text-muted-foreground">Untuk franchise</p>
                    <ul class="mt-4 space-y-2 text-sm text-muted-foreground">
                        <li>✓ Multi Toko Unlimited</li>
                        <li>✓ API & Integrasi</li>
                        <li>✓ On-premise + Training</li>
                    </ul>
                    <a href="mailto:hello@posqupro.id" class="mt-6 inline-flex w-full h-10 items-center justify-center rounded-md border border-input bg-background hover:bg-accent">Hubungi Sales</a>
                </div>
            </div>
        </section>

        <!-- CTA -->
        <section class="container mx-auto max-w-7xl px-4 lg:px-8 py-16">
            <div class="bg-primary text-primary-foreground rounded-2xl p-8 lg:p-12 text-center">
                <h2 class="text-3xl font-bold">Siap Scale Toko Anda?</h2>
                <p class="text-primary-foreground/80 mt-2 max-w-2xl mx-auto">Bergabung dengan 500+ pemilik toko yang sudah pakai POSQUPRO. Setup 2 menit, langsung jualan.</p>
                <div class="flex flex-col sm:flex-row gap-3 justify-center mt-6">
                    <a href="{{ url('/dashboard') }}" class="inline-flex h-11 items-center justify-center rounded-md bg-background text-foreground px-8 font-medium hover:bg-background/90">Buka Dashboard</a>
                    <a href="{{ url('/pos') }}" class="inline-flex h-11 items-center justify-center rounded-md border border-primary-foreground/20 bg-primary px-8 font-medium hover:bg-primary-foreground/10">Coba POS Sekarang</a>
                </div>
            </div>
        </section>

        <!-- Footer -->
        <footer class="border-t border-border py-8">
            <div class="container mx-auto max-w-7xl px-4 lg:px-8 flex flex-col md:flex-row justify-between gap-4 text-sm text-muted-foreground">
                <div class="flex items-center gap-2">
                    <img src="/logo.png" alt="POSQUPRO" class="h-6 w-auto" />
                    <span>© 2026 POSQUPRO • SIMPLE • SMART • SUCCESS</span>
                </div>
                <div class="flex gap-6">
                    <a href="{{ url('/login') }}" class="hover:text-foreground">Login</a>
                    <a href="{{ url('/pos') }}" class="hover:text-foreground">POS</a>
                    <a href="{{ url('/reports') }}" class="hover:text-foreground">Laporan</a>
                </div>
            </div>
        </footer>
    </body>
</html>
