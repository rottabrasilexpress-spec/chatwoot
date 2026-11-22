<script setup>
import { ref, nextTick, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AudioTranscriptionAPI from 'dashboard/api/inbox/audioTranscription';
import DictationRecorder from 'dashboard/components/widgets/WootWriter/DictationRecorder.vue';

const props = defineProps({
  disabled: { type: Boolean, default: false },
  dictationConversationId: { type: [Number, String], default: null },
});
const emit = defineEmits(['send']);
const { t } = useI18n();
const message = ref('');
const textareaRef = ref(null);
const recorder = ref(null);
const recording = ref(false);
const transcribing = ref(false);
let disposed = false;

const adjustHeight = () => {
  if (!textareaRef.value) return;

  // Reset height to auto to get the correct scrollHeight
  textareaRef.value.style.height = 'auto';
  // Set the height to the scrollHeight
  textareaRef.value.style.height = `${textareaRef.value.scrollHeight}px`;
};

const sendMessage = () => {
  if (
    !props.disabled &&
    !recording.value &&
    !transcribing.value &&
    message.value.trim()
  ) {
    emit('send', message.value);
    message.value = '';
    // Reset textarea height after sending
    nextTick(() => {
      adjustHeight();
    });
  }
};

const handleInput = () => {
  nextTick(adjustHeight);
};

const handleEnterKey = event => {
  if (event.isComposing) return;
  event.preventDefault();
  sendMessage();
};

onMounted(() => {
  nextTick(adjustHeight);
});

onBeforeUnmount(() => {
  disposed = true;
});

const toggleDictation = () => {
  if (recording.value) recorder.value?.stopRecording();
  else recording.value = true;
};

const dictationError = ({ error } = {}) => {
  recording.value = false;
  if (!disposed)
    useAlert(
      t(
        ['NotAllowedError', 'PermissionDeniedError'].includes(error?.name)
          ? 'CONVERSATION.REPLYBOX.DICTATION_PERMISSION_ERROR'
          : 'CONVERSATION.REPLYBOX.DICTATION_ERROR'
      )
    );
};

const addDictation = async file => {
  if (disposed) return;
  recording.value = false;
  transcribing.value = true;
  let transcript = file.nativeTranscript?.trim();
  try {
    if (!transcript) {
      const { data } = await AudioTranscriptionAPI.create({
        conversationId: props.dictationConversationId,
        file,
      });
      transcript = data?.text?.trim();
    }
    if (disposed) return;
    if (!transcript) {
      useAlert(t('CONVERSATION.REPLYBOX.DICTATION_EMPTY'));
      return;
    }
    message.value += `${message.value.trim() ? '\n' : ''}${transcript}`;
    await nextTick();
    adjustHeight();
    textareaRef.value?.focus();
  } catch (error) {
    if (!disposed) dictationError({ error });
  } finally {
    transcribing.value = false;
  }
};
</script>

<template>
  <form class="relative" @submit.prevent="sendMessage">
    <textarea
      ref="textareaRef"
      v-model="message"
      :placeholder="$t('CAPTAIN.COPILOT.SEND_MESSAGE')"
      class="w-full reset-base bg-n-alpha-3 ltr:pl-4 ltr:pr-12 rtl:pl-12 rtl:pr-4 py-3 text-sm border border-n-weak rounded-lg focus:outline-0 focus:outline-none focus:ring-2 focus:ring-n-blue-11 focus:border-n-blue-11 resize-none overflow-hidden max-h-[200px] mb-0 text-n-slate-12"
      rows="1"
      :class="{ 'ltr:pr-20 rtl:pl-20': dictationConversationId }"
      @input="handleInput"
      @keydown.enter.exact="handleEnterKey"
    />
    <button
      v-if="dictationConversationId"
      type="button"
      class="absolute ltr:right-11 rtl:left-11 top-1/2 -translate-y-1/2 h-8 w-8 rounded-md flex items-center justify-center text-n-slate-11 hover:bg-n-alpha-2"
      :class="{ 'text-n-ruby-11 bg-n-ruby-3': recording }"
      :aria-label="
        t(
          recording
            ? 'CONVERSATION.COPILOT.STOP_DICTATION'
            : 'CONVERSATION.COPILOT.DICTATE'
        )
      "
      :title="
        t(
          recording
            ? 'CONVERSATION.COPILOT.STOP_DICTATION'
            : 'CONVERSATION.COPILOT.DICTATE'
        )
      "
      :disabled="disabled || transcribing"
      @click="toggleDictation"
    >
      <i
        :class="recording ? 'i-lucide-square' : 'i-lucide-mic'"
        aria-hidden="true"
      />
    </button>
    <button
      class="absolute ltr:right-1 rtl:left-1 top-1/2 -translate-y-1/2 h-9 w-10 flex items-center justify-center text-n-slate-11 hover:text-n-blue-11"
      type="submit"
      :disabled="disabled || recording || transcribing"
      :aria-label="$t('CAPTAIN.COPILOT.SEND_MESSAGE')"
    >
      <i class="i-ph-arrow-up" />
    </button>
  </form>
  <DictationRecorder
    v-if="recording"
    ref="recorder"
    @finish-record="addDictation"
    @record-error="dictationError"
  />
  <p v-if="transcribing" role="status" class="text-xs text-n-slate-11">
    {{ t('CONVERSATION.COPILOT.TRANSCRIBING') }}
  </p>
</template>
