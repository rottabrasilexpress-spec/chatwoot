<script setup>
import { ref, computed } from 'vue';
import Avatar from 'next/avatar/Avatar.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import { getOriginalAvatarUrl } from 'dashboard/helper/avatarUrl';

const props = defineProps({
  contact: { type: Object, required: true },
  selected: { type: Boolean, default: false },
  enableSelection: { type: Boolean, default: true },
  hideThumbnail: { type: Boolean, default: false },
  size: { type: Number, default: 24 },
});

const emit = defineEmits(['selectConversation', 'openContact']);

const hovered = ref(false);

const onThumbnailHover = () => {
  hovered.value = !props.hideThumbnail;
};

const onThumbnailLeave = () => {
  hovered.value = false;
};

const selectedModel = computed({
  get: () => props.selected,
  set: value => {
    emit('selectConversation', value);
  },
});

const avatarUrl = computed(() =>
  getOriginalAvatarUrl(props.contact.avatar_url || props.contact.thumbnail)
);
</script>

<template>
  <div
    class="relative flex items-center flex-shrink-0"
    @mouseenter="onThumbnailHover"
    @mouseleave="onThumbnailLeave"
  >
    <button
      v-if="!hideThumbnail"
      type="button"
      class="p-0 bg-transparent border-0 rounded-full cursor-pointer"
      :aria-label="`Abrir perfil de ${contact.name}`"
      @click.stop="emit('openContact')"
    >
      <Avatar
        :name="contact.name"
        :src="avatarUrl"
        :size="size"
        :status="contact.availability_status"
        class="rounded-full"
        hide-offline-status
      />
    </button>
    <div
      v-if="enableSelection && (hovered || selected)"
      class="rotta-card-avatar-select absolute top-0.5 right-0.5 z-10 flex items-center justify-center rounded-md"
      @click.stop
    >
      <Checkbox v-model="selectedModel" />
    </div>
  </div>
</template>

<style scoped>
.rotta-card-avatar-select {
  width: 1.25rem;
  height: 1.25rem;
  background: rgb(255 255 255 / 88%);
  box-shadow: 0 1px 4px rgb(0 0 0 / 16%);
}
</style>
