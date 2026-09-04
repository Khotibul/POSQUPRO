<script setup>
import { useForm, usePage } from '@inertiajs/vue3'
import { computed } from 'vue'

const page = usePage()
const flash = computed(() => page.props.flash || {})

const form = useForm({ email: '', password: '' })
function submit() { form.post('/login') }

const googleUrl = '/auth/google/redirect'
</script>
<template>
  <div class="min-h-screen flex items-center justify-center bg-background p-4">
    <div class="bg-card border border-border p-6 sm:p-8 rounded-xl shadow-lg w-full max-w-md">
      <!-- Back to home -->
      <a href="/" class="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors mb-6">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/></svg>
        Kembali ke Beranda
      </a>

      <div class="flex justify-center mb-4">
        <img src="/logo.png" alt="POSQUPRO" class="h-16 sm:h-20 w-auto object-contain" />
      </div>
      <p class="text-center text-muted-foreground text-sm mb-6 font-medium">SIMPLE • SMART • SUCCESS</p>

      <!-- Flash error (from Google OAuth) -->
      <div v-if="flash.error" class="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg">
        {{ flash.error }}
      </div>

      <!-- Login Form -->
      <form @submit.prevent="submit" class="space-y-4">
        <div>
          <label class="text-sm font-medium">Email</label>
          <input v-model="form.email" type="email" placeholder="email@toko.com"
            class="w-full px-3 py-2.5 border border-border rounded-lg text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary" />
          <div v-if="form.errors.email" class="text-red-500 text-xs mt-1">{{ form.errors.email }}</div>
        </div>
        <div>
          <label class="text-sm font-medium">Password</label>
          <input v-model="form.password" type="password" placeholder="••••••••"
            class="w-full px-3 py-2.5 border border-border rounded-lg text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary" />
          <div v-if="form.errors.password" class="text-red-500 text-xs mt-1">{{ form.errors.password }}</div>
        </div>
        <button :disabled="form.processing" class="w-full bg-primary text-primary-foreground py-2.5 rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50 transition-colors">
          {{ form.processing ? 'Masuk...' : 'Masuk' }}
        </button>
      </form>

      <!-- Divider -->
      <div class="relative my-6">
        <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-border"></div></div>
        <div class="relative flex justify-center text-xs uppercase"><span class="bg-card px-2 text-muted-foreground">Atau</span></div>
      </div>

      <!-- Google Login -->
      <a :href="googleUrl"
        class="flex items-center justify-center gap-3 w-full border border-border bg-background py-2.5 rounded-lg text-sm font-medium hover:bg-accent hover:text-accent-foreground transition-colors">
        <svg class="w-5 h-5" viewBox="0 0 24 24">
          <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/>
          <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
          <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
          <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
        </svg>
        Masuk dengan Google
      </a>

      <!-- Register link -->
      <p class="text-center text-sm text-muted-foreground mt-6">
        Belum punya akun?
        <a :href="googleUrl" class="text-primary hover:underline font-medium">Daftar dengan Google</a>
      </p>
    </div>
  </div>
</template>
