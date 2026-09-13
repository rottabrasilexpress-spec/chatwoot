<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';

const props = defineProps({
  storageKey: { type: String, required: true },
  label: { type: String, default: 'Painel ajustável' },
  minWidth: { type: Number, default: 240 },
  minHeight: { type: Number, default: 120 },
  maxWidth: { type: Number, default: 1600 },
  maxHeight: { type: Number, default: 1400 },
});

const panel = ref(null);
const size = ref({ width: null, height: null });
const isResizing = ref(false);
let removePointerListeners;

const panelStyle = computed(() => ({
  ...(size.value.width ? { width: `${size.value.width}px` } : {}),
  ...(size.value.height ? { height: `${size.value.height}px` } : {}),
}));

const clamp = (value, minimum, maximum) =>
  Math.min(maximum, Math.max(minimum, value));

const persistSize = () => {
  if (typeof window === 'undefined') return;

  window.localStorage.setItem(
    props.storageKey,
    JSON.stringify({
      width: size.value.width,
      height: size.value.height,
    })
  );
};

const resetSize = () => {
  size.value = { width: null, height: null };
  if (typeof window !== 'undefined')
    window.localStorage.removeItem(props.storageKey);
};

const applySize = (width, height) => {
  if (width) size.value.width = Math.round(width);
  if (height) size.value.height = Math.round(height);
  persistSize();
};

const stopResize = () => {
  removePointerListeners?.();
  removePointerListeners = undefined;
  isResizing.value = false;
  persistSize();
};

const startResize = (axis, event, direction = 1) => {
  if (!panel.value || (event.button !== undefined && event.button !== 0))
    return;

  event.preventDefault();
  event.stopPropagation();
  removePointerListeners?.();

  const rect = panel.value.getBoundingClientRect();
  const parentRect = panel.value.parentElement?.getBoundingClientRect();
  const startWidth = size.value.width || rect.width;
  const startHeight = size.value.height || rect.height;
  const maximumWidth = Math.max(
    props.minWidth,
    Math.min(props.maxWidth, parentRect?.width || props.maxWidth)
  );
  const maximumHeight = Math.max(props.minHeight, props.maxHeight);
  const startX = event.clientX;
  const startY = event.clientY;

  isResizing.value = true;

  const handlePointerMove = pointerEvent => {
    const deltaX = (pointerEvent.clientX - startX) * direction;
    const deltaY = (pointerEvent.clientY - startY) * direction;
    const nextWidth = axis.includes('x')
      ? clamp(startWidth + deltaX, props.minWidth, maximumWidth)
      : undefined;
    const nextHeight = axis.includes('y')
      ? clamp(startHeight + deltaY, props.minHeight, maximumHeight)
      : undefined;

    applySize(nextWidth, nextHeight);
  };

  const handlePointerUp = () => stopResize();
  document.addEventListener('pointermove', handlePointerMove);
  document.addEventListener('pointerup', handlePointerUp, { once: true });
  document.addEventListener('pointercancel', handlePointerUp, { once: true });
  removePointerListeners = () => {
    document.removeEventListener('pointermove', handlePointerMove);
    document.removeEventListener('pointerup', handlePointerUp);
    document.removeEventListener('pointercancel', handlePointerUp);
  };
};

const resizeWithKeyboard = (axis, event) => {
  const delta = event.shiftKey ? 64 : 16;
  const isHorizontalKey = ['ArrowLeft', 'ArrowRight'].includes(event.key);
  const isVerticalKey = ['ArrowUp', 'ArrowDown'].includes(event.key);
  if (
    (isHorizontalKey && !axis.includes('x')) ||
    (isVerticalKey && !axis.includes('y'))
  )
    return;

  const direction = ['ArrowLeft', 'ArrowUp'].includes(event.key) ? -1 : 1;
  if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key))
    return;

  event.preventDefault();
  const rect = panel.value?.getBoundingClientRect();
  const nextWidth = axis.includes('x')
    ? clamp(
        (size.value.width || rect?.width || props.minWidth) + delta * direction,
        props.minWidth,
        props.maxWidth
      )
    : undefined;
  const nextHeight = axis.includes('y')
    ? clamp(
        (size.value.height || rect?.height || props.minHeight) +
          delta * direction,
        props.minHeight,
        props.maxHeight
      )
    : undefined;

  applySize(nextWidth, nextHeight);
};

const handleLayoutReset = event => {
  const storagePrefix = event.detail?.storagePrefix;
  if (storagePrefix && props.storageKey.startsWith(storagePrefix)) resetSize();
};

onMounted(() => {
  try {
    const saved = JSON.parse(window.localStorage.getItem(props.storageKey));
    if (Number.isFinite(saved?.width) && saved.width >= props.minWidth)
      size.value.width = Math.min(saved.width, props.maxWidth);
    if (Number.isFinite(saved?.height) && saved.height >= props.minHeight)
      size.value.height = Math.min(saved.height, props.maxHeight);
  } catch {
    // A stale or blocked local layout preference never blocks the calculator.
  }
  window.addEventListener('rotta-calculator-reset-layout', handleLayoutReset);
});

onBeforeUnmount(() => {
  removePointerListeners?.();
  window.removeEventListener(
    'rotta-calculator-reset-layout',
    handleLayoutReset
  );
});
</script>

<template>
  <div
    ref="panel"
    class="calculator-resizable-panel group"
    :class="{ 'is-resizing': isResizing }"
    :style="panelStyle"
    :aria-label="label"
    tabindex="-1"
  >
    <div class="calculator-resizable-panel__content">
      <slot />
    </div>
    <button
      type="button"
      class="calculator-resizable-panel__handle calculator-resizable-panel__handle--left"
      :aria-label="`Ajustar largura de ${label} pela esquerda`"
      @pointerdown="startResize('x', $event, -1)"
      @keydown="resizeWithKeyboard('x', $event)"
    />
    <button
      type="button"
      class="calculator-resizable-panel__handle calculator-resizable-panel__handle--right"
      :aria-label="`Ajustar largura de ${label} pela direita`"
      @pointerdown="startResize('x', $event)"
      @keydown="resizeWithKeyboard('x', $event)"
    />
    <button
      type="button"
      class="calculator-resizable-panel__handle calculator-resizable-panel__handle--top"
      :aria-label="`Ajustar altura de ${label} por cima`"
      @pointerdown="startResize('y', $event, -1)"
      @keydown="resizeWithKeyboard('y', $event)"
    />
    <button
      type="button"
      class="calculator-resizable-panel__handle calculator-resizable-panel__handle--bottom"
      :aria-label="`Ajustar altura de ${label} por baixo`"
      @pointerdown="startResize('y', $event)"
      @keydown="resizeWithKeyboard('y', $event)"
    />
    <button
      type="button"
      class="calculator-resizable-panel__handle calculator-resizable-panel__handle--corner"
      :aria-label="`Ajustar largura e altura de ${label}`"
      @pointerdown="startResize('xy', $event)"
      @keydown="resizeWithKeyboard('xy', $event)"
    />
  </div>
</template>

<style scoped>
.calculator-resizable-panel {
  position: relative;
  min-width: 0;
  max-width: 100%;
}

.calculator-resizable-panel__content {
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
  overflow: auto;
}

.calculator-resizable-panel__handle {
  position: absolute;
  z-index: 30;
  display: block;
  padding: 0;
  border: 0;
  border-radius: 999px;
  background: rgba(234, 88, 12, 0.55);
  opacity: 0;
  transition:
    opacity 120ms ease,
    background 120ms ease;
}

.calculator-resizable-panel:hover > .calculator-resizable-panel__handle,
.calculator-resizable-panel:focus-within > .calculator-resizable-panel__handle,
.calculator-resizable-panel.is-resizing > .calculator-resizable-panel__handle {
  opacity: 1;
}

.calculator-resizable-panel__handle:hover,
.calculator-resizable-panel__handle:focus-visible {
  background: rgba(234, 88, 12, 0.95);
  outline: 2px solid rgba(234, 88, 12, 0.28);
  outline-offset: 2px;
}

.calculator-resizable-panel__handle--left,
.calculator-resizable-panel__handle--right {
  top: 1.25rem;
  bottom: 1.25rem;
  width: 0.5rem;
  cursor: ew-resize;
}

.calculator-resizable-panel__handle--left {
  left: -0.25rem;
}

.calculator-resizable-panel__handle--right {
  right: -0.25rem;
}

.calculator-resizable-panel__handle--top,
.calculator-resizable-panel__handle--bottom {
  right: 1.25rem;
  left: 1.25rem;
  height: 0.5rem;
  cursor: ns-resize;
}

.calculator-resizable-panel__handle--top {
  top: -0.25rem;
}

.calculator-resizable-panel__handle--bottom {
  bottom: -0.25rem;
}

.calculator-resizable-panel__handle--corner {
  right: -0.35rem;
  bottom: -0.35rem;
  width: 1rem;
  height: 1rem;
  cursor: nwse-resize;
}

@media (max-width: 767px) {
  .calculator-resizable-panel {
    width: 100% !important;
    height: auto !important;
  }

  .calculator-resizable-panel__handle {
    display: none;
  }
}
</style>
