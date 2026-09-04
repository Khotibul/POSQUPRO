<script setup>
import Button from './Button.vue'
const props = defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  headerAction: { type: Object, default: null },
  bordered: { type: Boolean, default: true },
  padded: { type: Boolean, default: true },
  hover: { type: Boolean, default: false },
})

const baseClass = 'bg-card text-card-foreground rounded-xl border shadow-sm transition-shadow duration-200'
</script>
<template>
  <div :class="[baseClass, props.bordered ? 'border-border' : 'border-0', props.hover ? 'hover:shadow-md cursor-pointer' : '', props.padded ? 'p-6' : 'p-0']">
    <div v-if="props.title || props.headerAction" class="flex items-center justify-between mb-4 pb-4 border-b border-border">
      <div>
        <h3 v-if="props.title" class="text-lg font-semibold text-foreground">{{ props.title }}</h3>
        <p v-if="props.subtitle" class="text-sm text-muted-foreground mt-0.5">{{ props.subtitle }}</p>
      </div>
      <Button v-if="props.headerAction" :variant="props.headerAction.variant" :icon="props.headerAction.icon" @click="props.headerAction.onClick">
        {{ props.headerAction.label }}
      </Button>
    </div>
    <slot />
  </div>
</template>