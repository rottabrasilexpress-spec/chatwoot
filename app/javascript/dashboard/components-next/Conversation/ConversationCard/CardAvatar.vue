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

const emit = defineEmits(['selectConversation']);

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
    <Avatar
      v-if="!hideThumbnail"
      :name="contact.name"
      :src="avatarUrl"
      :size="size"
      :status="contact.availability_status"
      class="rounded-full"
      hide-offline-status
    >
      <template v-if="enableSelection" #overlay>
        <div
          v-if="hovered || selected"
          class="flex items-center justify-center rounded-md cursor-pointer absolute inset-0 z-10 backdrop-blur-[2px] size-6"
          @click.stop
        >
          <Checkbox v-model="selectedModel" />
        </div>
      </template>
    </Avatar>
  </div>
</template>
