<script>
import { mapGetters } from 'vuex';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { picoSearch } from '@chatwoot/pico-search';
import MenuItem from './menuItem.vue';
import MenuItemWithSubmenu from './menuItemWithSubmenu.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const MENU = {
  MARK_AS_READ: 'mark-as-read',
  MARK_AS_UNREAD: 'mark-as-unread',
  PRIORITY: 'priority',
  LABEL: 'label',
  DELETE: 'delete',
  OPEN_NEW_TAB: 'open-new-tab',
  COPY_LINK: 'copy-link',
  PIN: 'pin',
  ARCHIVE: 'archive',
  REQUEST_ATTENTION: 'request-attention',
  FINALIZE: 'finalize',
};

export default {
  components: {
    MenuItem,
    MenuItemWithSubmenu,
    NextInput,
    Icon,
  },
  props: {
    chatId: {
      type: Number,
      default: null,
    },
    hasUnreadMessages: {
      type: Boolean,
      default: false,
    },
    priority: {
      type: String,
      default: null,
    },
    conversationLabels: {
      type: Array,
      default: () => [],
    },
    conversationUrl: {
      type: String,
      default: '',
    },
    pinned: {
      type: Boolean,
      default: false,
    },
    allowedOptions: {
      type: Array,
      default: () => [],
    },
    canRequestAttention: {
      type: Boolean,
      default: false,
    },
    canFinalize: {
      type: Boolean,
      default: false,
    },
  },
  emits: [
    'assignPriority',
    'markAsUnread',
    'markAsRead',
    'assignLabel',
    'removeLabel',
    'deleteConversation',
    'togglePinned',
    'archiveConversation',
    'requestAttention',
    'finalizeConversation',
    'close',
  ],
  setup() {
    const { isAdmin } = useAdmin();
    return {
      isAdmin,
    };
  },
  data() {
    return {
      MENU,
      labelSearchQuery: '',
      readOption: {
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.MARK_AS_READ'),
        icon: 'mail',
      },
      unreadOption: {
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.MARK_AS_UNREAD'),
        icon: 'mail-unread',
      },
      priorityConfig: {
        key: MENU.PRIORITY,
        label: this.$t('CONVERSATION.PRIORITY.TITLE'),
        icon: 'warning',
        options: [
          {
            label: this.$t('CONVERSATION.PRIORITY.OPTIONS.NONE'),
            key: null,
          },
          {
            label: this.$t('CONVERSATION.PRIORITY.OPTIONS.URGENT'),
            key: 'urgent',
          },
          {
            label: this.$t('CONVERSATION.PRIORITY.OPTIONS.HIGH'),
            key: 'high',
          },
          {
            label: this.$t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM'),
            key: 'medium',
          },
          {
            label: this.$t('CONVERSATION.PRIORITY.OPTIONS.LOW'),
            key: 'low',
          },
        ].filter(item => item.key !== this.priority),
      },
      labelMenuConfig: {
        key: MENU.LABEL,
        icon: 'tag',
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.ASSIGN_LABEL'),
      },
      deleteOption: {
        key: MENU.DELETE,
        icon: 'delete',
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.DELETE'),
      },
      openInNewTabOption: {
        key: MENU.OPEN_NEW_TAB,
        icon: 'open',
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.OPEN_IN_NEW_TAB'),
      },
      copyLinkOption: {
        key: MENU.COPY_LINK,
        icon: 'copy',
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.COPY_LINK'),
      },
      archiveOption: {
        key: MENU.ARCHIVE,
        icon: 'archive',
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.ARCHIVE'),
      },
      requestAttentionOption: {
        key: MENU.REQUEST_ATTENTION,
        icon: 'i-lucide-bell-ring',
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.REQUEST_ATTENTION'),
      },
      finalizeOption: {
        key: MENU.FINALIZE,
        icon: 'i-lucide-circle-check-big',
        label: this.$t('CONVERSATION.CARD_CONTEXT_MENU.FINALIZE'),
      },
    };
  },
  computed: {
    ...mapGetters({
      labels: 'labels/getLabels',
    }),
    filteredLabels() {
      const labels = this.labelSearchQuery
        ? picoSearch(this.labels, this.labelSearchQuery, ['title'])
        : this.labels;
      // Assigned labels first, keeping each group's existing order.
      const isAssigned = label => this.conversationLabels.includes(label.title);
      return [...labels].sort((a, b) => isAssigned(b) - isAssigned(a));
    },
    pinOption() {
      return {
        key: MENU.PIN,
        icon: this.pinned ? 'pin-off' : 'pin',
        label: this.pinned ? 'Desafixar conversa' : 'Fixar conversa',
      };
    },
  },
  methods: {
    isAllowed(keys) {
      if (!this.allowedOptions.length) return true;
      return keys.some(key => this.allowedOptions.includes(key));
    },
    assignPriority(priority) {
      this.$emit('assignPriority', priority);
    },
    deleteConversation() {
      this.$emit('deleteConversation', this.chatId);
    },
    openInNewTab() {
      if (!this.conversationUrl) return;

      const url = `${window.chatwootConfig.hostURL}${this.conversationUrl}`;
      window.open(url, '_blank', 'noopener,noreferrer');
      this.$emit('close');
    },
    async copyConversationLink() {
      if (!this.conversationUrl) return;
      try {
        const url = `${window.chatwootConfig.hostURL}${this.conversationUrl}`;
        await copyTextToClipboard(url);
        useAlert(this.$t('CONVERSATION.CARD_CONTEXT_MENU.COPY_LINK_SUCCESS'));
        this.$emit('close');
      } catch (error) {
        // error
      }
    },
    requestAttention() {
      this.$emit('requestAttention', this.chatId);
      this.$emit('close');
    },
    finalizeConversation() {
      this.$emit('finalizeConversation', this.chatId);
      this.$emit('close');
    },
    generateMenuLabelConfig(option, type = 'text') {
      return {
        key: option.id,
        ...(type === 'icon' && { icon: option.icon }),
        ...(type === 'label' && { color: option.color }),
        ...(type === 'text' && { label: option.label }),
        ...(type === 'label' && { label: option.title }),
      };
    },
  },
};
</script>

<template>
  <div
    class="p-1 rounded-md shadow-xl bg-n-alpha-3/50 backdrop-blur-[100px] outline-1 outline outline-n-weak/50"
  >
    <template v-if="isAllowed([MENU.MARK_AS_READ, MENU.MARK_AS_UNREAD])">
      <MenuItem
        v-if="!hasUnreadMessages"
        :option="unreadOption"
        variant="icon"
        @click.stop="$emit('markAsUnread')"
      />
      <MenuItem
        v-else
        :option="readOption"
        variant="icon"
        @click.stop="$emit('markAsRead')"
      />
      <hr class="m-1 rounded border-b border-n-weak dark:border-n-weak" />
    </template>
    <MenuItem
      v-if="canRequestAttention && isAllowed([MENU.REQUEST_ATTENTION])"
      :option="requestAttentionOption"
      variant="attention"
      @click.stop="requestAttention"
    />
    <hr
      v-if="canRequestAttention && isAllowed([MENU.REQUEST_ATTENTION])"
      class="m-1 rounded border-b border-n-weak dark:border-n-weak"
    />
    <MenuItem
      v-if="canFinalize && isAllowed([MENU.FINALIZE])"
      :option="finalizeOption"
      variant="attention"
      @click.stop="finalizeConversation"
    />
    <hr
      v-if="canFinalize && isAllowed([MENU.FINALIZE])"
      class="m-1 rounded border-b border-n-weak dark:border-n-weak"
    />
    <MenuItem
      v-if="isAllowed([MENU.ARCHIVE])"
      :option="archiveOption"
      variant="icon"
      @click.stop="$emit('archiveConversation')"
    />
    <hr
      v-if="isAllowed([MENU.ARCHIVE])"
      class="m-1 rounded border-b border-n-weak dark:border-n-weak"
    />
    <template v-if="isAllowed([MENU.PRIORITY, MENU.LABEL])">
      <MenuItemWithSubmenu
        v-if="isAllowed([MENU.PRIORITY])"
        :option="priorityConfig"
      >
        <MenuItem
          v-for="(option, i) in priorityConfig.options"
          :key="i"
          :option="option"
          @click.stop="assignPriority(option.key)"
        />
      </MenuItemWithSubmenu>
      <MenuItemWithSubmenu
        v-if="isAllowed([MENU.LABEL])"
        :option="labelMenuConfig"
        :sub-menu-available="!!labels.length"
      >
        <div class="pb-1 w-[12.5rem]">
          <NextInput
            v-model="labelSearchQuery"
            type="search"
            size="sm"
            class="w-full"
            custom-input-class="!ps-8 !text-xs"
            :placeholder="$t('CONVERSATION.CARD_CONTEXT_MENU.SEARCH_LABELS')"
            @click.stop
            @keydown.stop
          >
            <template #prefix>
              <Icon
                icon="i-lucide-search"
                class="absolute z-10 -translate-y-1/2 pointer-events-none size-3.5 text-n-slate-10 top-1/2 start-2"
              />
            </template>
          </NextInput>
        </div>
        <div class="overflow-x-hidden overflow-y-auto max-h-[12.5rem]">
          <MenuItem
            v-for="label in filteredLabels"
            :key="label.id"
            :option="generateMenuLabelConfig(label, 'label')"
            :variant="
              conversationLabels.includes(label.title)
                ? 'label-assigned'
                : 'label'
            "
            @mousedown.prevent
            @click.stop="
              conversationLabels.includes(label.title)
                ? $emit('removeLabel', label)
                : $emit('assignLabel', label)
            "
          />
          <p
            v-if="!filteredLabels.length"
            class="px-2 py-2 m-0 text-xs text-center text-n-slate-11"
          >
            {{ $t('CONVERSATION.CARD_CONTEXT_MENU.NO_LABELS_FOUND') }}
          </p>
        </div>
      </MenuItemWithSubmenu>
      <hr class="m-1 rounded border-b border-n-weak dark:border-n-weak" />
    </template>
    <template v-if="isAllowed([MENU.OPEN_NEW_TAB, MENU.COPY_LINK])">
      <MenuItem
        v-if="isAllowed([MENU.OPEN_NEW_TAB])"
        :option="openInNewTabOption"
        variant="icon"
        @click.stop="openInNewTab"
      />
      <MenuItem
        v-if="isAllowed([MENU.COPY_LINK])"
        :option="copyLinkOption"
        variant="icon"
        @click.stop="copyConversationLink"
      />
    </template>
    <hr class="m-1 rounded border-b border-n-weak dark:border-n-weak" />
    <MenuItem
      v-if="isAllowed([MENU.PIN])"
      :option="pinOption"
      variant="icon"
      @click.stop="$emit('togglePinned')"
    />
    <template v-if="isAdmin && isAllowed([MENU.DELETE])">
      <hr class="m-1 rounded border-b border-n-weak dark:border-n-weak" />
      <MenuItem
        :option="deleteOption"
        variant="icon"
        @click.stop="deleteConversation"
      />
    </template>
  </div>
</template>
