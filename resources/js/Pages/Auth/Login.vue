<script setup>
import { useForm } from '@inertiajs/vue3';
const form = useForm({ email: 'cashier@posqupro.test', password: 'password' });
function submit(){ form.post('/login'); }
</script>
<template>
  <div class="min-h-screen flex items-center justify-center bg-background p-4">
    <div class="bg-card border border-border p-8 rounded-xl shadow-lg w-full max-w-md">
      <div class="flex justify-center mb-6">
        <img src="/logo.png" alt="POSQUPRO" class="h-20 w-auto object-contain" />
      </div>
      <p class="text-center text-muted-foreground text-sm mb-6 font-medium">SIMPLE • SMART • SUCCESS</p>
      <form @submit.prevent="submit" class="space-y-4">
        <div>
          <label class="text-sm">Email</label>
          <input v-model="form.email" type="email" class="w-full border rounded px-3 py-2" />
          <div v-if="form.errors.email" class="text-red-500 text-xs">{{ form.errors.email }}</div>
        </div>
        <div>
          <label class="text-sm">Password</label>
          <input v-model="form.password" type="password" class="w-full border rounded px-3 py-2" />
        </div>
        <button :disabled="form.processing" class="w-full bg-indigo-600 text-white py-2 rounded hover:bg-indigo-700">Login</button>
        <div class="text-xs text-gray-400 text-center mt-2">
          Test: cashier@posqupro.test / superadmin@posqupro.test / password
        </div>
      </form>
    </div>
  </div>
</template>
