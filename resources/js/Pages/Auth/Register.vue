<script setup>
import { useForm, usePage } from '@inertiajs/vue3'
import { computed } from 'vue'

const page = usePage()
const flash = computed(() => page.props.flash || {})

const form = useForm({
  name: '',
  store_name: '',
  email: '',
  phone: '',
  password: '',
  password_confirmation: '',
  agree: false,
})

function submit() {
  form.post('/daftar')
}
</script>
<template>
  <div class="min-h-screen flex items-center justify-center bg-background p-4">
    <div class="bg-card border border-border p-6 sm:p-8 rounded-xl shadow-lg w-full max-w-md">
      <a href="/" class="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors mb-6">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/></svg>
        Kembali ke Beranda
      </a>

      <div class="flex justify-center mb-4">
        <img src="/logo.png" alt="POSQUPRO" class="h-16 sm:h-20 w-auto object-contain" />
      </div>
      <p class="text-center text-muted-foreground text-sm mb-1 font-medium">SIMPLE • SMART • SUCCESS</p>
      <h1 class="text-center text-xl font-bold mb-1">Buat Akun Baru</h1>
      <p class="text-center text-muted-foreground text-sm mb-6">Daftarkan bisnis Anda dalam hitungan menit.</p>

      <div v-if="flash.error" class="mb-4 p-3 bg-red-50 dark:bg-red-950 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm rounded-lg">
        {{ flash.error }}
      </div>

      <form @submit.prevent="submit" class="space-y-4">
        <div>
          <label class="text-sm font-medium">Nama Lengkap</label>
          <input v-model="form.name" type="text" placeholder="John Doe" autocomplete="name" required
            class="w-full px-3 py-2.5 border border-border rounded-lg text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary" />
          <div v-if="form.errors.name" class="text-red-500 text-xs mt-1">{{ form.errors.name }}</div>
        </div>
        <div>
          <label class="text-sm font-medium">Nama Bisnis</label>
          <input v-model="form.store_name" type="text" placeholder="Nama Toko atau Perusahaan" required
            class="w-full px-3 py-2.5 border border-border rounded-lg text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary" />
          <div v-if="form.errors.store_name" class="text-red-500 text-xs mt-1">{{ form.errors.store_name }}</div>
        </div>
        <div>
          <label class="text-sm font-medium">Email</label>
          <input v-model="form.email" type="email" placeholder="contoh@bisnis.com" autocomplete="email" required
            class="w-full px-3 py-2.5 border border-border rounded-lg text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary" />
          <div v-if="form.errors.email" class="text-red-500 text-xs mt-1">{{ form.errors.email }}</div>
        </div>
        <div>
          <label class="text-sm font-medium">Nomor Telepon <span class="text-muted-foreground font-normal">(opsional)</span></label>
          <input v-model="form.phone" type="tel" placeholder="0812 3456 7890" autocomplete="tel"
            class="w-full px-3 py-2.5 border border-border rounded-lg text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary" />
          <div v-if="form.errors.phone" class="text-red-500 text-xs mt-1">{{ form.errors.phone }}</div>
        </div>
        <div>
          <label class="text-sm font-medium">Password</label>
          <input v-model="form.password" type="password" placeholder="Min. 8 Karakter" autocomplete="new-password" required minlength="8"
            class="w-full px-3 py-2.5 border border-border rounded-lg text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary" />
          <div v-if="form.errors.password" class="text-red-500 text-xs mt-1">{{ form.errors.password }}</div>
        </div>
        <div>
          <label class="text-sm font-medium">Konfirmasi Password</label>
          <input v-model="form.password_confirmation" type="password" placeholder="Ulangi password" autocomplete="new-password" required
            class="w-full px-3 py-2.5 border border-border rounded-lg text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary" />
        </div>

        <label class="flex items-start gap-3 text-sm text-muted-foreground">
          <input v-model="form.agree" type="checkbox" class="mt-1 rounded border-border text-primary focus:ring-primary" />
          <span>
            Saya menyetujui
            <a href="#" class="text-primary hover:underline font-medium">Syarat dan Ketentuan</a>
            serta
            <a href="#" class="text-primary hover:underline font-medium">Kebijakan Privasi</a>
            yang berlaku di POSQUPRO.
          </span>
        </label>
        <div v-if="form.errors.agree" class="text-red-500 text-xs">{{ form.errors.agree }}</div>

        <button :disabled="form.processing" class="w-full bg-primary text-primary-foreground py-2.5 rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50 transition-colors">
          {{ form.processing ? 'Memproses...' : 'Daftar Sekarang' }}
        </button>
      </form>

      <p class="text-center text-sm text-muted-foreground mt-6">
        Sudah punya akun?
        <a href="/login" class="text-primary hover:underline font-medium">Masuk</a>
      </p>
    </div>
  </div>
</template>
