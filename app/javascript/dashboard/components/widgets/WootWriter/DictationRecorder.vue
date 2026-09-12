<script setup>
import { onMounted, onUnmounted, ref } from 'vue';

const emit = defineEmits(['finishRecord', 'recordError']);

const recorder = ref(null);
const stream = ref(null);
const chunks = ref([]);
const isRecording = ref(false);

const MIME_TYPES = [
  'audio/webm;codecs=opus',
  'audio/webm',
  'audio/mp4',
];

const getSupportedMimeType = () => {
  if (typeof MediaRecorder === 'undefined') return '';

  return MIME_TYPES.find(type => MediaRecorder.isTypeSupported(type)) || '';
};

const extensionFor = mimeType => {
  if (mimeType.startsWith('audio/mp4')) return 'mp4';
  return 'webm';
};

const stopTracks = () => {
  stream.value?.getTracks().forEach(track => track.stop());
  stream.value = null;
};

const resetRecorder = () => {
  recorder.value = null;
  chunks.value = [];
  isRecording.value = false;
  stopTracks();
};

const reportError = error => {
  resetRecorder();
  emit('recordError', { error });
};

const startRecording = async () => {
  if (
    !navigator.mediaDevices?.getUserMedia ||
    typeof MediaRecorder === 'undefined'
  ) {
    reportError(new Error('Audio recording is not supported by this browser'));
    return;
  }

  try {
    stream.value = await navigator.mediaDevices.getUserMedia({ audio: true });
    const mimeType = getSupportedMimeType();
    recorder.value = new MediaRecorder(
      stream.value,
      mimeType ? { mimeType } : undefined
    );
    chunks.value = [];

    recorder.value.ondataavailable = event => {
      if (event.data?.size) chunks.value.push(event.data);
    };
    recorder.value.onerror = event => reportError(event.error);
    recorder.value.onstop = () => {
      const actualType = recorder.value?.mimeType || mimeType || 'audio/webm';
      const blob = new Blob(chunks.value, { type: actualType });

      if (!blob.size) {
        reportError(new Error('No audio was recorded'));
        return;
      }

      const file = new File(
        [blob],
        `dictation-${Date.now()}.${extensionFor(actualType)}`,
        { type: actualType }
      );
      resetRecorder();
      emit('finishRecord', file);
    };
    recorder.value.start();
    isRecording.value = true;
  } catch (error) {
    reportError(error);
  }
};

const stopRecording = () => {
  if (!recorder.value || !isRecording.value) return;
  recorder.value.stop();
  isRecording.value = false;
  stopTracks();
};

onMounted(startRecording);
onUnmounted(() => {
  if (recorder.value && isRecording.value) recorder.value.stop();
  resetRecorder();
});

defineExpose({ startRecording, stopRecording });
</script>

<template>
  <div
    v-if="isRecording"
    class="px-3 py-1 text-xs text-n-slate-11"
    data-testid="dictation-recording-status"
  >
    {{ $t('CONVERSATION.REPLYBOX.DICTATION_RECORDING') }}
  </div>
</template>
