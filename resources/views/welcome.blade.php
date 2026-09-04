<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>{{ config('app.name', 'POSQUPRO') }} — SIMPLE • SMART • SUCCESS</title>
        <meta name="description" content="POSQUPRO - Point of Sale modern untuk UMKM, retail & resto. SIMPLE • SMART • SUCCESS.">
        <link rel="icon" href="/logo.png" type="image/png">
        @vite(['resources/css/app.css', 'resources/js/app.js'])
    </head>
    <body class="bg-background text-foreground antialiased">
        <!-- Header -->
        <header class="sticky top-0 z-50 w-full border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
            <div class="container mx-auto max-w-7xl flex h-14 sm:h-16 items-center justify-between px-4 lg:px-8">
                <div class="flex items-center gap-2">
                    <img src="/logo.png" alt="POSQUPRO" class="h-7 sm:h-8 w-auto object-contain" />
                    <span class="hidden font-bold sm:inline-block">POSQUPRO</span>
                </div>
                <nav class="hidden md:flex items-center gap-6 text-sm font-medium text-muted-foreground">
                    <a href="#features" class="hover:text-foreground transition-colors">Fitur</a>
                    <a href="#about" class="hover:text-foreground transition-colors">Tentang</a>
                    <a href="#pricing" class="hover:text-foreground transition-colors">Harga</a>
                    <a href="#download" class="hover:text-foreground transition-colors">Download</a>
                </nav>
                <div class="flex items-center gap-2">
                    @auth
                        <a href="{{ url('/dashboard') }}" class="inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors">
                            Dashboard
                        </a>
                    @else
                        <a href="{{ url('/login') }}" class="inline-flex h-9 items-center justify-center rounded-md border border-input bg-background px-4 py-2 text-sm font-medium hover:bg-accent hover:text-accent-foreground transition-colors">
                            Masuk
                        </a>
                        <a href="{{ url('/login') }}" class="hidden sm:inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors">
                            Daftar Sekarang
                        </a>
                    @endauth
                </div>
            </div>
        </header>

        <!-- Hero -->
        <section class="container mx-auto max-w-7xl px-4 lg:px-8 py-10 sm:py-12 lg:py-20">
            <div class="grid lg:grid-cols-2 gap-8 lg:gap-12 items-center">
                <div class="space-y-5 sm:space-y-6">
                    <div class="inline-flex items-center rounded-full border border-border bg-muted px-3 py-1 text-xs font-medium">
                        <span class="mr-2 h-2 w-2 rounded-full bg-primary animate-pulse"></span>
                        POS Modern untuk UMKM
                    </div>
                    <h1 class="text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight">
                        POS Modern untuk
                        <span class="text-primary">UMKM, Retail & Resto</span>
                    </h1>
                    <p class="text-base sm:text-lg text-muted-foreground max-w-[600px]">
                        <span class="font-semibold text-foreground">SIMPLE • SMART • SUCCESS</span> — Kelola POS kasir, inventory real-time, laporan analytics, dan multi-cabang dalam satu dashboard yang cepat.
                    </p>
                    <div class="flex flex-col sm:flex-row gap-3">
                        <a href="{{ url('/login') }}" class="inline-flex h-11 items-center justify-center rounded-md bg-primary px-8 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors">
                            Mulai Gratis →
                        </a>
                        <a href="#features" class="inline-flex h-11 items-center justify-center rounded-md border border-input bg-background px-8 text-sm font-medium hover:bg-accent hover:text-accent-foreground transition-colors">
                            Lihat Fitur
                        </a>
                    </div>
                    <div class="flex items-center gap-4 text-sm text-muted-foreground pt-2">
                        <div class="flex -space-x-2">
                            <div class="h-8 w-8 rounded-full bg-primary/10 border-2 border-background flex items-center justify-center text-xs font-medium">A</div>
                            <div class="h-8 w-8 rounded-full bg-primary/20 border-2 border-background flex items-center justify-center text-xs font-medium">K</div>
                            <div class="h-8 w-8 rounded-full bg-primary/30 border-2 border-background flex items-center justify-center text-xs font-medium">W</div>
                        </div>
                        <span>Dipercaya 500+ toko</span>
                        <span class="h-4 w-px bg-border hidden sm:block"></span>
                        <span class="hidden sm:inline">4.9/5 ★★★★★</span>
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
                            <span class="ml-2 text-xs text-muted-foreground">POSQUPRO Dashboard</span>
                        </div>
                        <img src="/logo.png" alt="POSQUPRO Dashboard" class="w-full h-auto object-contain p-6 sm:p-8 bg-gradient-to-br from-card to-muted/20" />
                        <div class="grid grid-cols-3 gap-2 sm:gap-3 p-3 sm:p-4 bg-muted/30">
                            <div class="bg-card border border-border rounded-lg p-2 sm:p-3">
                                <p class="text-[10px] sm:text-xs text-muted-foreground">Hari Ini</p>
                                <p class="text-sm sm:text-base font-bold">Rp 2.4jt</p>
                                <p class="text-[10px] sm:text-xs text-green-600">+12%</p>
                            </div>
                            <div class="bg-card border border-border rounded-lg p-2 sm:p-3">
                                <p class="text-[10px] sm:text-xs text-muted-foreground">Transaksi</p>
                                <p class="text-sm sm:text-base font-bold">48</p>
                                <p class="text-[10px] sm:text-xs text-green-600">+8%</p>
                            </div>
                            <div class="bg-card border border-border rounded-lg p-2 sm:p-3">
                                <p class="text-[10px] sm:text-xs text-muted-foreground">Stok Rendah</p>
                                <p class="text-sm sm:text-base font-bold text-destructive">5</p>
                                <p class="text-[10px] sm:text-xs text-muted-foreground">Perlu restock</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Features -->
        <section id="features" class="container mx-auto max-w-7xl px-4 lg:px-8 py-12 sm:py-16 border-t border-border">
            <div class="text-center max-w-2xl mx-auto mb-8 sm:mb-10">
                <h2 class="text-2xl sm:text-3xl font-bold tracking-tight">Fitur Lengkap POS Modern</h2>
                <p class="text-muted-foreground mt-2 text-sm sm:text-base">Semua yang dibutuhkan toko Anda, dari kasir hingga laporan, dalam satu aplikasi.</p>
            </div>
            <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
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
                    <div class="bg-card border border-border rounded-xl p-5 sm:p-6 hover:shadow-md transition-shadow">
                        <div class="h-10 w-10 rounded-lg bg-primary/10 flex items-center justify-center mb-4">
                            <svg class="h-5 w-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="{{ $f['icon'] }}"/></svg>
                        </div>
                        <h3 class="font-semibold">{{ $f['title'] }}</h3>
                        <p class="text-sm text-muted-foreground mt-1">{{ $f['desc'] }}</p>
                    </div>
                @endforeach
            </div>
        </section>

        <!-- About -->
        <section id="about" class="container mx-auto max-w-7xl px-4 lg:px-8 py-12 sm:py-16 border-t border-border">
            <div class="grid lg:grid-cols-2 gap-8 lg:gap-16 items-center">
                <div class="space-y-5">
                    <div class="inline-flex items-center rounded-full border border-border bg-muted px-3 py-1 text-xs font-medium">
                        Tentang POSQUPRO
                    </div>
                    <h2 class="text-2xl sm:text-3xl font-bold tracking-tight">
                        Dibuat untuk UMKM Indonesia
                    </h2>
                    <div class="space-y-4 text-muted-foreground text-sm sm:text-base">
                        <p>
                            POSQUPRO lahir dari kebutuhan nyata UMKM, retail, dan resto di Indonesia akan sistem kasir yang <strong class="text-foreground">sederhana namun powerful</strong>. Tidak perlu lagi pakai kasir mahal atau Excel yang ribet.
                        </p>
                        <p>
                            Dibangun dengan teknologi modern — <strong class="text-foreground">Laravel + Vue 3 + MySQL</strong> — POSQUPRO menawarkan kecepatan, keamanan, dan kemudahan yang sebelumnya hanya dimiliki enterprise ERP.
                        </p>
                        <p>
                            Dari warung kopi kecil hingga jaringan restoran multi-cabang, POSQUPRO siap menemani pertumbuhan bisnis Anda.
                        </p>
                    </div>
                    <div class="grid grid-cols-3 gap-4 pt-2">
                        <div class="text-center">
                            <p class="text-2xl sm:text-3xl font-bold text-primary">500+</p>
                            <p class="text-xs sm:text-sm text-muted-foreground">Toko Aktif</p>
                        </div>
                        <div class="text-center">
                            <p class="text-2xl sm:text-3xl font-bold text-primary">50K+</p>
                            <p class="text-xs sm:text-sm text-muted-foreground">Transaksi/Bulan</p>
                        </div>
                        <div class="text-center">
                            <p class="text-2xl sm:text-3xl font-bold text-primary">99.9%</p>
                            <p class="text-xs sm:text-sm text-muted-foreground">Uptime</p>
                        </div>
                    </div>
                </div>
                <div class="relative">
                    <div class="absolute inset-0 bg-gradient-to-br from-primary/10 to-primary/5 rounded-2xl blur-2xl"></div>
                    <div class="relative bg-card border border-border rounded-2xl p-6 sm:p-8 space-y-4">
                        <div class="flex items-center gap-3">
                            <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                                <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                            </div>
                            <div>
                                <p class="font-medium text-sm">Open Source Friendly</p>
                                <p class="text-xs text-muted-foreground">Teknologi transparan, tidak vendor lock-in</p>
                            </div>
                        </div>
                        <div class="flex items-center gap-3">
                            <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                                <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
                            </div>
                            <div>
                                <p class="font-medium text-sm">Data Aman & Terenkripsi</p>
                                <p class="text-xs text-muted-foreground">Enkripsi password, session protection, RBAC</p>
                            </div>
                        </div>
                        <div class="flex items-center gap-3">
                            <div class="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
                                <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>
                            </div>
                            <div>
                                <p class="font-medium text-sm">Performa Tinggi</p>
                                <p class="text-xs text-muted-foreground">Load < 2 detik, POS responsif tanpa lag</p>
                            </div>
                        </div>
                        <div class="flex items-center gap-3">
                            <div class="w-10 h-10 bg-orange-100 rounded-lg flex items-center justify-center">
                                <svg class="w-5 h-5 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                            </div>
                            <div>
                                <p class="font-medium text-sm">Multi Bahasa & Currency</p>
                                <p class="text-xs text-muted-foreground">Bahasa Indonesia, Rupiah, format lokal</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Pricing — Dynamic from DB -->
        <section id="pricing" class="py-12 sm:py-16 border-t border-border bg-muted/20">
            <div class="container mx-auto max-w-7xl px-4 lg:px-8">
                <div class="text-center max-w-2xl mx-auto mb-8 sm:mb-10">
                    <h2 class="text-2xl sm:text-3xl font-bold">Harga Simpel</h2>
                    <p class="text-muted-foreground mt-2 text-sm sm:text-base">Mulai gratis, scale sesuai kebutuhan toko Anda.</p>
                </div>
                @php
                    try {
                        $plans = \App\Models\Plan::where('is_active', true)->orderBy('sort_order')->get();
                    } catch (\Exception $e) {
                        $plans = collect();
                    }
                    $popularIndex = $plans->search(fn($p) => $p->slug === 'pro') ?? 1;
                @endphp
                <div class="grid sm:grid-cols-2 lg:grid-cols-{{ min($plans->count(), 4) }} gap-4 sm:gap-6 max-w-5xl mx-auto">
                    @foreach($plans as $i => $plan)
                        @php
                            $isPopular = $i === $popularIndex;
                            $priceFormatted = number_format($plan->price, 0, ',', '.');
                            $yearlyFormatted = $plan->price_yearly ? number_format($plan->price_yearly, 0, ',', '.') : null;
                            $features = $plan->features ?? [];
                            $featureLabels = [
                                'pos' => 'POS Kasir',
                                'products' => 'Manajemen Produk',
                                'inventory' => 'Inventory & Stok',
                                'reports' => 'Laporan Analytics',
                                'purchase_orders' => 'Purchase Order',
                                'stock_counts' => 'Stock Opname',
                                'multi_branch' => 'Multi Cabang',
                                'api_access' => 'API Access',
                                'priority_support' => 'Support Prioritas',
                            ];
                        @endphp
                        <div class="bg-card border {{ $isPopular ? 'border-2 border-primary shadow-lg' : 'border-border' }} rounded-xl p-5 sm:p-6 {{ $isPopular ? 'relative' : '' }}">
                            @if($isPopular)
                                <div class="absolute -top-3 left-1/2 -translate-x-1/2 bg-primary text-primary-foreground px-3 py-1 rounded-full text-xs font-medium">Populer</div>
                            @endif
                            <h3 class="font-semibold">{{ $plan->name }}</h3>
                            @if($plan->price <= 0)
                                <p class="text-3xl font-bold mt-2">Gratis</p>
                            @else
                                <p class="text-3xl font-bold mt-2">Rp {{ $priceFormatted }} <span class="text-sm font-normal text-muted-foreground">/bulan</span></p>
                                @if($yearlyFormatted)
                                    <p class="text-xs text-green-600">Tahunan: Rp {{ $yearlyFormatted }}/tahun</p>
                                @endif
                            @endif
                            <p class="text-sm text-muted-foreground">{{ $plan->description }}</p>
                            <ul class="mt-4 space-y-2 text-sm {{ $plan->price > 0 ? '' : 'text-muted-foreground' }}">
                                <li>✓ {{ $plan->max_users }} User • {{ number_format($plan->max_products) }} Produk</li>
                                <li>✓ {{ $plan->max_branches }} Cabang</li>
                                @if($plan->trial_days > 0)
                                    <li>✓ {{ $plan->trial_days }} Hari Trial</li>
                                @endif
                                @foreach($features as $f)
                                    @if(isset($featureLabels[$f]))
                                        <li>✓ {{ $featureLabels[$f] }}</li>
                                    @endif
                                @endforeach
                            </ul>
                            @if($plan->price <= 0)
                                <a href="{{ url('/login') }}" class="mt-6 inline-flex w-full h-10 items-center justify-center rounded-md border border-input bg-background hover:bg-accent">Mulai Gratis</a>
                            @elseif($isPopular)
                                <a href="{{ url('/login') }}" class="mt-6 inline-flex w-full h-10 items-center justify-center rounded-md bg-primary text-primary-foreground hover:bg-primary/90">Pilih {{ $plan->name }}</a>
                            @else
                                <a href="{{ url('/login') }}" class="mt-6 inline-flex w-full h-10 items-center justify-center rounded-md border border-input bg-background hover:bg-accent">Pilih {{ $plan->name }}</a>
                            @endif
                        </div>
                    @endforeach
                </div>
            </div>
        </section>

        <!-- Download -->
        <section id="download" class="container mx-auto max-w-7xl px-4 lg:px-8 py-12 sm:py-16 border-t border-border">
            <div class="text-center max-w-2xl mx-auto mb-8 sm:mb-10">
                <h2 class="text-2xl sm:text-3xl font-bold tracking-tight">Download POSQUPRO</h2>
                <p class="text-muted-foreground mt-2 text-sm sm:text-base">Mulai gunakan POSQUPRO sekarang. GRATIS untuk plan Starter.</p>
            </div>
            <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6 max-w-4xl mx-auto">
                <!-- Web App -->
                <div class="bg-card border border-border rounded-xl p-6 text-center hover:shadow-md transition-shadow">
                    <div class="w-14 h-14 bg-blue-100 rounded-xl flex items-center justify-center mx-auto mb-4">
                        <svg class="w-7 h-7 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/></svg>
                    </div>
                    <h3 class="font-semibold">Web App</h3>
                    <p class="text-sm text-muted-foreground mt-1 mb-4">Akses dari browser, support semua device</p>
                    <a href="{{ url('/login') }}" class="inline-flex w-full h-10 items-center justify-center rounded-md bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors">
                        Buka Sekarang
                    </a>
                </div>

                <!-- APK Android -->
                <div class="bg-card border border-border rounded-xl p-6 text-center hover:shadow-md transition-shadow">
                    <div class="w-14 h-14 bg-green-100 rounded-xl flex items-center justify-center mx-auto mb-4">
                        <svg class="w-7 h-7 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"/></svg>
                    </div>
                    <h3 class="font-semibold">Android (APK)</h3>
                    <p class="text-sm text-muted-foreground mt-1 mb-4">Install di tablet atau HP Android kasir</p>
                    <a href="#" class="inline-flex w-full h-10 items-center justify-center rounded-md border border-input bg-background text-sm font-medium hover:bg-accent transition-colors">
                        Download APK
                    </a>
                </div>

                <!-- Desktop -->
                <div class="bg-card border border-border rounded-xl p-6 text-center hover:shadow-md transition-shadow">
                    <div class="w-14 h-14 bg-purple-100 rounded-xl flex items-center justify-center mx-auto mb-4">
                        <svg class="w-7 h-7 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>
                    </div>
                    <h3 class="font-semibold">Desktop App</h3>
                    <p class="text-sm text-muted-foreground mt-1 mb-4">Windows, macOS, Linux (Electron)</p>
                    <a href="#" class="inline-flex w-full h-10 items-center justify-center rounded-md border border-input bg-background text-sm font-medium hover:bg-accent transition-colors">
                        Download Desktop
                    </a>
                </div>
            </div>
        </section>

        <!-- CTA -->
        <section class="container mx-auto max-w-7xl px-4 lg:px-8 py-12 sm:py-16">
            <div class="bg-primary text-primary-foreground rounded-2xl p-6 sm:p-8 lg:p-12 text-center">
                <h2 class="text-2xl sm:text-3xl font-bold">Siap Scale Toko Anda?</h2>
                <p class="text-primary-foreground/80 mt-2 max-w-2xl mx-auto text-sm sm:text-base">Bergabung dengan 500+ pemilik toko yang sudah pakai POSQUPRO. Setup 2 menit, langsung jualan.</p>
                <div class="flex flex-col sm:flex-row gap-3 justify-center mt-6">
                    <a href="{{ url('/login') }}" class="inline-flex h-11 items-center justify-center rounded-md bg-background text-foreground px-8 font-medium hover:bg-background/90">Daftar Gratis</a>
                    <a href="#about" class="inline-flex h-11 items-center justify-center rounded-md border border-primary-foreground/20 bg-primary px-8 font-medium hover:bg-primary-foreground/10">Tentang Kami</a>
                </div>
            </div>
        </section>

        <!-- Footer -->
        <footer class="border-t border-border py-6 sm:py-8">
            <div class="container mx-auto max-w-7xl px-4 lg:px-8 flex flex-col sm:flex-row justify-between gap-4 text-sm text-muted-foreground">
                <div class="flex items-center gap-2">
                    <img src="/logo.png" alt="POSQUPRO" class="h-6 w-auto" />
                    <span>&copy; 2026 POSQUPRO &bull; SIMPLE &bull; SMART &bull; SUCCESS</span>
                </div>
                <div class="flex flex-wrap gap-6">
                    <a href="{{ url('/login') }}" class="hover:text-foreground">Masuk</a>
                    <a href="#features" class="hover:text-foreground">Fitur</a>
                    <a href="#about" class="hover:text-foreground">Tentang</a>
                    <a href="#pricing" class="hover:text-foreground">Harga</a>
                    <a href="#download" class="hover:text-foreground">Download</a>
                </div>
            </div>
        </footer>
    </body>
</html>
