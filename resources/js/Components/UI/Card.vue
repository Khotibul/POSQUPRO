<script setup>
defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  headerAction: { type: Object, default: null }, // { label, variant, icon, onClick }
  bordered: { type: Boolean, default: true },
  padded: { type: Boolean, default: true },
  hover: { type: Boolean, default: false },
})

const baseClass = 'bg-card text-card-foreground rounded-xl border shadow-sm transition-shadow duration-200'
</script>
<template>
  <div :class="[baseClass, bordered ? 'border-border' : 'border-0', hover ? 'hover:shadow-md cursor-pointer' : '', padded ? 'p-6' : 'p-0']">
    <div v-if="title || headerAction" class="flex items-center justify-between mb-4 pb-4 border-b border-border">
      <div>
        <h3 v-if="title" class="text-lg font-semibold text-foreground">{{ title }}</h3>
        <p v-if="subtitle" class="text-sm text-muted-foreground mt-0.5">{{ subtitle }}</p>
      </div>
      <Button v-if="headerAction" :variant="headerAction.variant" :icon="headerAction.icon" @click="headerAction.onClick">
        {{ headerAction.label }}
      </Button>
    </div>
    <slot />
  </div>
</template>