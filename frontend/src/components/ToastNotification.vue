<script setup lang="ts">
import { useToast } from '../useToast'

const { toasts, removeToast } = useToast()
</script>

<template>
  <div class="toast-container" v-if="toasts.length > 0">
    <div
      v-for="toast in toasts"
      :key="toast.id"
      :class="['toast', `toast-${toast.type}`]"
      @click="removeToast(toast.id)"
      style="cursor: pointer;"
      title="Click to dismiss"
    >
      <span class="toast-indicator" :class="`indicator-${toast.type}`"></span>
      <span style="flex: 1; word-break: break-word;">{{ toast.message }}</span>
    </div>
  </div>
</template>

<style scoped>
.toast-indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.indicator-success {
  background: var(--success);
  box-shadow: 0 0 8px var(--success);
}
.indicator-error {
  background: var(--danger);
  box-shadow: 0 0 8px var(--danger);
}
.indicator-info {
  background: var(--accent);
  box-shadow: 0 0 8px var(--accent);
}
</style>
