<script setup>
import { useForm } from '@inertiajs/vue3'
const form = useForm({ email: 'cashier@posqupro.test', password: 'password' })
function submit() { form.post('/login') }
</script>
<template>
  <div class="min-h-screen flex items-center justify-center bg-background p-4">
    <div class="bg-card border border-border p-8 rounded-xl shadow-lg w-full max-w-md">
      <!-- Back to home -->
      <a href="/" class="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors mb-6">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/></svg>
        Kembali ke Beranda
      </a>

      <div class="flex justify-center mb-6">
        <img src="/logo.png" alt="POSQUPRO" class="h-20 w-auto object-contain" />
      </div>
      <p class="text-center text-muted-foreground text-sm mb-6 font-medium">SIMPLE • SMART • SUCCESS</p>

      <form @submit.prevent="submit" class="space-y-4">
        <div>
          <label class="text-sm font-medium">Email</label>
          <input v-model="form.email" type="email" class="w-full px-3 py-2 border border-border rounded-lg text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary" />
          <div v-if="form.errors.email" class="text-red-500 text-xs mt-1">{{ form.errors.email }}</div>
        </div>
        <div>
          <label class="text-sm font-medium">Password</label>
          <input v-model="form.password" type="password" class="w-full px-3 py-2 border border-border rounded-lg text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary" />
          <div v-if="form.errors.password" class="text-red-500 text-xs mt-1">{{ form.errors.password }}</div>
        </div>
        <button :disabled="form.processing" class="w-full bg-primary text-primary-foreground py-2.5 rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50 transition-colors">
          {{ form.processing ? 'Masuk...' : 'Masuk' }}
        </button>
      </form>

      <div class="mt-6 p-3 bg-muted rounded-lg text-xs text-muted-foreground text-center space-y-1">
        <p class="font-medium">Test Akun:</p>
        <p>superadmin@posqupro.test (Super Admin)</p>
        <p>admin@posqupro.test • cashier@posqupro.test</p>
        <p>Password: <code class="bg-background px-1 rounded">password</code></p>
      </div>
    </div>
  </div>
</template>
