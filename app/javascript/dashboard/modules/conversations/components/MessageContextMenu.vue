<script>
import { useAlert } from 'dashboard/composables';
import { mapGetters } from 'vuex';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import AddCannedModal from 'dashboard/routes/dashboard/settings/canned/AddCanned.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import { conversationUrl, frontendURL } from '../../../helper/URLHelper';
import {
  ACCOUNT_EVENTS,
  CONVERSATION_EVENTS,
} from '../../../helper/AnalyticsHelper/events';
import MenuItem from '../../../components/widgets/conversation/contextMenu/menuItem.vue';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ReportCaptainMessageDialog from './ReportCaptainMessageDialog.vue';

export default {
  components: {
    AddCannedModal,
    MenuItem,
    ContextMenu,
    NextButton,
    ReportCaptainMessageDialog,
  },
  props: {
    message: {
      type: Object,
      required: true,
    },
    isOpen: {
      type: Boolean,
      default: false,
    },
    enabledOptions: {
      type: Object,
      default: () => ({}),
    },
    contextMenuPosition: {
      type: Object,
      default: () => ({}),
    },
    hideButton: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['open', 'close', 'replyTo'],
  setup() {
    const { getPlainText } = useMessageFormatter();

    return {
      getPlainText,
    };
  },
  data() {
    return {
      isCannedResponseModalOpen: false,
      showDeleteModal: false,
      showEditModal: false,
      showReactionModal: false,
      showForwardModal: false,
      editedContent: '',
      forwardSearch: '',
      isActionPending: false,
      quickReactions: ['👍', '❤️', '😂', '😮', '😢', '🙏'],
    };
  },
  computed: {
    ...mapGetters({
      getAccount: 'accounts/getAccount',
      currentAccountId: 'getCurrentAccountId',
      getUISettings: 'getUISettings',
      getAllConversations: 'getAllConversations',
    }),
    plainTextContent() {
      return this.getPlainText(this.messageContent);
    },
    conversationId() {
      return this.message.conversation_id ?? this.message.conversationId;
    },
    messageId() {
      return this.message.id;
    },
    messageContent() {
      return this.message.content;
    },
    contentAttributes() {
      return useSnakeCase(
        this.message.content_attributes ?? this.message.contentAttributes
      );
    },
    isStarred() {
      return !!this.message.starred;
    },
    currentReaction() {
      return this.contentAttributes?.rotta_reaction || '';
    },
    pinActionLabel() {
      if (this.contentAttributes?.rotta_pinned) {
        return this.$t('CONVERSATION.CONTEXT_MENU.UNPIN');
      }
      return this.$t('CONVERSATION.CONTEXT_MENU.PIN');
    },
    starActionLabel() {
      if (this.isStarred) {
        return this.$t('CONVERSATION.CONTEXT_MENU.UNSTAR');
      }
      return this.$t('CONVERSATION.CONTEXT_MENU.STAR');
    },
    forwardableConversations() {
      const query = this.forwardSearch.trim().toLowerCase();
      return (this.getAllConversations || [])
        .filter(
          conversation =>
            Number(conversation.id) !== Number(this.conversationId)
        )
        .filter(conversation => {
          if (!query) return true;
          return this.conversationSearchText(conversation).includes(query);
        })
        .slice(0, 40);
    },
  },
  methods: {
    async copyLinkToMessage() {
      const fullConversationURL =
        window.chatwootConfig.hostURL +
        frontendURL(
          conversationUrl({
            id: this.conversationId,
            accountId: this.currentAccountId,
          })
        );
      await copyTextToClipboard(
        `${fullConversationURL}?messageId=${this.messageId}`
      );
      useAlert(this.$t('CONVERSATION.CONTEXT_MENU.LINK_COPIED'));
      this.handleClose();
    },
    async handleCopy() {
      await copyTextToClipboard(this.plainTextContent);
      useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESSFUL'));
      this.handleClose();
    },
    showCannedResponseModal() {
      useTrack(ACCOUNT_EVENTS.ADDED_TO_CANNED_RESPONSE);
      this.isCannedResponseModalOpen = true;
    },
    hideCannedResponseModal() {
      this.isCannedResponseModalOpen = false;
      this.handleClose();
    },
    handleOpen(e) {
      this.$emit('open', e);
    },
    handleClose(e) {
      this.$emit('close', e);
    },
    async handleTranslate() {
      const { locale: accountLocale } = this.getAccount(this.currentAccountId);
      const agentLocale = this.getUISettings?.locale;
      const targetLanguage = agentLocale || accountLocale || 'en';
      try {
        await this.$store.dispatch('translateMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
          targetLanguage,
        });
        useTrack(CONVERSATION_EVENTS.TRANSLATE_A_MESSAGE);
      } catch (error) {
        useAlert(parseAPIErrorResponse(error));
      }
      this.handleClose();
    },
    handleReplyTo() {
      this.$emit('replyTo', this.message);
      this.handleClose();
    },
    openEditModal() {
      this.handleClose();
      this.editedContent = this.plainTextContent;
      this.showEditModal = true;
    },
    closeEditModal() {
      this.showEditModal = false;
    },
    async confirmEdit() {
      if (!this.editedContent.trim() || this.isActionPending) return;

      this.isActionPending = true;
      try {
        await this.$store.dispatch('editMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
          text: this.editedContent.trim(),
        });
        useAlert(this.$t('CONVERSATION.CONTEXT_MENU.EDIT_SUCCESS'));
        this.closeEditModal();
      } catch (error) {
        useAlert(parseAPIErrorResponse(error));
      } finally {
        this.isActionPending = false;
      }
    },
    openReactionModal() {
      this.handleClose();
      this.showReactionModal = true;
    },
    closeReactionModal() {
      this.showReactionModal = false;
    },
    async selectReaction(emoji) {
      if (this.isActionPending) return;

      this.isActionPending = true;
      try {
        await this.$store.dispatch('reactToMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
          emoji,
        });
        useAlert(
          emoji
            ? this.$t('CONVERSATION.CONTEXT_MENU.REACTION_SUCCESS')
            : this.$t('CONVERSATION.CONTEXT_MENU.REACTION_REMOVED')
        );
        this.closeReactionModal();
      } catch (error) {
        useAlert(parseAPIErrorResponse(error));
      } finally {
        this.isActionPending = false;
      }
    },
    async togglePin() {
      if (this.isActionPending) return;

      const pin = !this.contentAttributes?.rotta_pinned;
      this.handleClose();
      this.isActionPending = true;
      try {
        await this.$store.dispatch('pinMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
          pin,
          duration: 30,
        });
        useAlert(
          pin
            ? this.$t('CONVERSATION.CONTEXT_MENU.PIN_SUCCESS')
            : this.$t('CONVERSATION.CONTEXT_MENU.UNPIN_SUCCESS')
        );
      } catch (error) {
        useAlert(parseAPIErrorResponse(error));
      } finally {
        this.isActionPending = false;
      }
    },
    async toggleStar() {
      if (this.isActionPending) return;

      const starred = !this.isStarred;
      this.handleClose();
      this.isActionPending = true;
      try {
        await this.$store.dispatch('toggleMessageStar', {
          conversationId: this.conversationId,
          messageId: this.messageId,
          starred,
        });
        useAlert(
          starred
            ? this.$t('CONVERSATION.CONTEXT_MENU.STAR_SUCCESS')
            : this.$t('CONVERSATION.CONTEXT_MENU.UNSTAR_SUCCESS')
        );
      } catch (error) {
        useAlert(parseAPIErrorResponse(error));
      } finally {
        this.isActionPending = false;
      }
    },
    openForwardModal() {
      this.handleClose();
      this.forwardSearch = '';
      this.showForwardModal = true;
    },
    closeForwardModal() {
      this.showForwardModal = false;
    },
    conversationSearchText(conversation) {
      const sender = conversation?.meta?.sender || conversation?.contact || {};
      return [
        sender.name,
        sender.phone_number,
        conversation?.id,
        conversation?.display_id,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
    },
    conversationTitle(conversation) {
      const sender = conversation?.meta?.sender || conversation?.contact || {};
      return sender.name || sender.phone_number || `#${conversation.id}`;
    },
    async forwardTo(targetConversationId) {
      if (this.isActionPending) return;

      this.isActionPending = true;
      try {
        await this.$store.dispatch('forwardMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
          targetConversationId,
        });
        useAlert(this.$t('CONVERSATION.CONTEXT_MENU.FORWARDED_SUCCESS'));
        this.closeForwardModal();
      } catch (error) {
        useAlert(parseAPIErrorResponse(error));
      } finally {
        this.isActionPending = false;
      }
    },
    openDeleteModal() {
      this.handleClose();
      this.showDeleteModal = true;
    },
    async confirmDeletion() {
      try {
        await this.$store.dispatch('deleteMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
        });
        useAlert(this.$t('CONVERSATION.SUCCESS_DELETE_MESSAGE'));
        this.handleClose();
      } catch (error) {
        useAlert(this.$t('CONVERSATION.FAIL_DELETE_MESSSAGE'));
      }
    },
    closeDeleteModal() {
      this.showDeleteModal = false;
    },
    openReportDialog() {
      this.handleClose();
      this.$refs.reportDialog?.open();
    },
  },
};
</script>

<template>
  <div class="context-menu">
    <!-- Edit text message -->
    <woot-modal
      v-if="showEditModal && enabledOptions['edit']"
      v-model:show="showEditModal"
      :on-close="closeEditModal"
    >
      <div class="rotta-action-modal">
        <woot-modal-header
          :header-title="$t('CONVERSATION.CONTEXT_MENU.EDIT_MESSAGE')"
        />
        <textarea
          v-model="editedContent"
          class="rotta-action-textarea"
          :placeholder="$t('CONVERSATION.CONTEXT_MENU.EDIT_PLACEHOLDER')"
          autofocus
          @keydown.meta.enter.prevent="confirmEdit"
          @keydown.ctrl.enter.prevent="confirmEdit"
        />
        <div class="rotta-action-modal__actions">
          <NextButton
            faded
            slate
            :label="$t('CONVERSATION.CONTEXT_MENU.CANCEL')"
            @click="closeEditModal"
          />
          <NextButton
            :label="$t('CONVERSATION.CONTEXT_MENU.SAVE')"
            :is-loading="isActionPending"
            :disabled="!editedContent.trim()"
            @click="confirmEdit"
          />
        </div>
      </div>
    </woot-modal>
    <!-- Reaction picker -->
    <woot-modal
      v-if="showReactionModal && enabledOptions['reaction']"
      v-model:show="showReactionModal"
      :on-close="closeReactionModal"
    >
      <div class="rotta-action-modal">
        <woot-modal-header
          :header-title="$t('CONVERSATION.CONTEXT_MENU.REACTION_TITLE')"
        />
        <div class="rotta-reaction-grid">
          <button
            v-for="emoji in quickReactions"
            :key="emoji"
            type="button"
            class="rotta-reaction-choice"
            :aria-label="emoji"
            @click="selectReaction(emoji)"
          >
            {{ emoji }}
          </button>
        </div>
        <NextButton
          v-if="currentReaction"
          faded
          slate
          class="mt-4 w-full"
          :label="$t('CONVERSATION.CONTEXT_MENU.REMOVE_REACTION')"
          :is-loading="isActionPending"
          @click="selectReaction('')"
        />
      </div>
    </woot-modal>
    <!-- Forward to another loaded conversation -->
    <woot-modal
      v-if="showForwardModal && enabledOptions['forward']"
      v-model:show="showForwardModal"
      :on-close="closeForwardModal"
    >
      <div class="rotta-action-modal">
        <woot-modal-header
          :header-title="$t('CONVERSATION.CONTEXT_MENU.FORWARD_TITLE')"
        />
        <input
          v-model="forwardSearch"
          class="rotta-forward-search"
          type="search"
          :placeholder="$t('CONVERSATION.CONTEXT_MENU.FORWARD_SEARCH')"
        />
        <div class="rotta-forward-list">
          <button
            v-for="conversation in forwardableConversations"
            :key="conversation.id"
            type="button"
            class="rotta-forward-item"
            :disabled="isActionPending"
            @click="forwardTo(conversation.id)"
          >
            <span class="rotta-forward-item__title truncate">
              {{ conversationTitle(conversation) }}
            </span>
            <span class="rotta-forward-item__id">{{ conversation.id }}</span>
          </button>
          <p v-if="!forwardableConversations.length" class="rotta-empty-state">
            {{ $t('CONVERSATION.CONTEXT_MENU.NO_CONVERSATIONS') }}
          </p>
        </div>
      </div>
    </woot-modal>
    <!-- Add To Canned Responses -->
    <woot-modal
      v-if="isCannedResponseModalOpen && enabledOptions['cannedResponse']"
      v-model:show="isCannedResponseModalOpen"
      :on-close="hideCannedResponseModal"
    >
      <AddCannedModal
        :response-content="plainTextContent"
        :on-close="hideCannedResponseModal"
      />
    </woot-modal>
    <!-- Confirm Deletion -->
    <woot-delete-modal
      v-if="showDeleteModal && enabledOptions['delete']"
      v-model:show="showDeleteModal"
      class="context-menu--delete-modal"
      :on-close="closeDeleteModal"
      :on-confirm="confirmDeletion"
      :title="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.TITLE')"
      :message="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.MESSAGE')"
      :confirm-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.DELETE')"
      :reject-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.CANCEL')"
    />
    <NextButton
      v-if="!hideButton"
      ghost
      slate
      sm
      icon="i-lucide-ellipsis-vertical"
      class="invisible group-hover/context-menu:visible"
      @click="handleOpen"
    />
    <ContextMenu
      v-if="isOpen && !isCannedResponseModalOpen"
      :x="contextMenuPosition.x"
      :y="contextMenuPosition.y"
      @close="handleClose"
    >
      <div class="menu-container">
        <MenuItem
          v-if="enabledOptions['replyTo']"
          :option="{
            icon: 'arrow-reply',
            label: $t('CONVERSATION.CONTEXT_MENU.REPLY_TO'),
          }"
          variant="icon"
          @click.stop="handleReplyTo"
        />
        <MenuItem
          v-if="enabledOptions['copy']"
          :option="{
            icon: 'clipboard',
            label: $t('CONVERSATION.CONTEXT_MENU.COPY'),
          }"
          variant="icon"
          @click.stop="handleCopy"
        />
        <MenuItem
          v-if="enabledOptions['reaction']"
          :option="{
            icon: 'i-lucide-smile-plus',
            label: $t('CONVERSATION.CONTEXT_MENU.REACT'),
          }"
          variant="icon"
          @click.stop="openReactionModal"
        />
        <MenuItem
          v-if="enabledOptions['edit']"
          :option="{
            icon: 'i-lucide-pencil',
            label: $t('CONVERSATION.CONTEXT_MENU.EDIT'),
          }"
          variant="icon"
          @click.stop="openEditModal"
        />
        <MenuItem
          v-if="enabledOptions['forward']"
          :option="{
            icon: 'i-lucide-forward',
            label: $t('CONVERSATION.CONTEXT_MENU.FORWARD'),
          }"
          variant="icon"
          @click.stop="openForwardModal"
        />
        <MenuItem
          v-if="enabledOptions['pin']"
          :option="{
            icon: 'i-lucide-pin',
            label: pinActionLabel,
          }"
          variant="icon"
          @click.stop="togglePin"
        />
        <MenuItem
          v-if="enabledOptions['star']"
          :option="{
            icon: 'i-lucide-star',
            label: starActionLabel,
          }"
          variant="icon"
          @click.stop="toggleStar"
        />
        <hr
          v-if="
            enabledOptions['translate'] ||
            enabledOptions['copyLink'] ||
            enabledOptions['cannedResponse']
          "
        />
        <MenuItem
          v-if="enabledOptions['translate']"
          :option="{
            icon: 'translate',
            label: $t('CONVERSATION.CONTEXT_MENU.TRANSLATE'),
          }"
          variant="icon"
          @click.stop="handleTranslate"
        />
        <hr />
        <MenuItem
          v-if="enabledOptions['copyLink']"
          :option="{
            icon: 'link',
            label: $t('CONVERSATION.CONTEXT_MENU.COPY_PERMALINK'),
          }"
          variant="icon"
          @click.stop="copyLinkToMessage"
        />
        <MenuItem
          v-if="enabledOptions['cannedResponse']"
          :option="{
            icon: 'comment-add',
            label: $t('CONVERSATION.CONTEXT_MENU.CREATE_A_CANNED_RESPONSE'),
          }"
          variant="icon"
          @click.stop="showCannedResponseModal"
        />
        <hr v-if="enabledOptions['report']" />
        <MenuItem
          v-if="enabledOptions['report']"
          :option="{
            icon: 'warning',
            label: $t('CONVERSATION.CONTEXT_MENU.REPORT_MESSAGE.LABEL'),
          }"
          variant="icon"
          @click.stop="openReportDialog"
        />
        <hr v-if="enabledOptions['delete']" />
        <MenuItem
          v-if="enabledOptions['delete']"
          :option="{
            icon: 'delete',
            label: $t('CONVERSATION.CONTEXT_MENU.DELETE'),
          }"
          variant="icon"
          @click.stop="openDeleteModal"
        />
      </div>
    </ContextMenu>
    <ReportCaptainMessageDialog
      v-if="enabledOptions['report']"
      ref="reportDialog"
      :message-id="messageId"
    />
  </div>
</template>

<style lang="scss" scoped>
.rotta-action-modal {
  @apply flex flex-col gap-4 p-1;
  min-width: min(34rem, 82vw);
}

.rotta-action-modal__actions {
  @apply flex justify-end gap-2;
}

.rotta-action-textarea,
.rotta-forward-search {
  @apply w-full rounded-lg border border-n-strong bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none;

  &:focus {
    @apply border-n-brand ring-1 ring-n-brand;
  }
}

.rotta-action-textarea {
  min-height: 7rem;
  resize: vertical;
}

.rotta-reaction-grid {
  @apply grid grid-cols-3 gap-2 sm:grid-cols-6;
}

.rotta-reaction-choice {
  @apply flex h-12 items-center justify-center rounded-lg bg-n-surface-2 text-2xl transition-colors hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand;
}

.rotta-forward-list {
  @apply flex max-h-80 flex-col gap-1 overflow-y-auto;
}

.rotta-forward-item {
  @apply flex min-w-0 items-center justify-between gap-3 rounded-lg px-3 py-2 text-left text-sm text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-50;
}

.rotta-forward-item__title {
  @apply min-w-0 flex-1 font-medium;
}

.rotta-forward-item__id {
  @apply shrink-0 text-xs text-n-slate-10;
}

.rotta-empty-state {
  @apply py-6 text-center text-sm text-n-slate-10;
}

.menu-container {
  @apply p-1 bg-n-background shadow-xl rounded-md;

  hr:first-child {
    @apply hidden;
  }

  hr {
    @apply m-1 border-b border-solid border-n-strong;
  }
}

.context-menu--delete-modal {
  :deep(.modal-container) {
    @apply max-w-[30rem];

    h2 {
      @apply font-medium text-base;
    }
  }
}
</style>
