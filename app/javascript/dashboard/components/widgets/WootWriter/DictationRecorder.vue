<script setup>
import { onMounted, onUnmounted, ref } from 'vue';

const emit = defineEmits(['finishRecord', 'recordError']);

const recorder = ref(null);
const stream = ref(null);
const chunks = ref([]);
const isRecording = ref(false);
const speechRecognition = ref(null);

let nativeTranscript = '';
let nativeRecognitionDone = null;
let resolveNativeRecognitionDone = null;

const MIME_TYPES = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4'];

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

const getSpeechRecognition = () => {
  if (typeof window === 'undefined') return null;

  return window.SpeechRecognition || window.webkitSpeechRecognition;
};

const resetSpeechRecognition = () => {
  try {
    speechRecognition.value?.abort();
  } catch {
    // The browser may already have ended recognition.
  }
  speechRecognition.value = null;
  nativeTranscript = '';
  resolveNativeRecognitionDone?.();
  resolveNativeRecognitionDone = null;
  nativeRecognitionDone = null;
};

const startSpeechRecognition = () => {
  const SpeechRecognition = getSpeechRecognition();
  if (!SpeechRecognition) return;

  try {
    const instance = new SpeechRecognition();
    nativeTranscript = '';
    nativeRecognitionDone = new Promise(resolve => {
      resolveNativeRecognitionDone = resolve;
    });
    instance.lang = 'pt-BR';
    instance.continuous = true;
    instance.interimResults = true;
    instance.onresult = event => {
      for (
        let index = event.resultIndex;
        index < event.results.length;
        index += 1
      ) {
        const result = event.results[index];
        if (result?.isFinal) {
          nativeTranscript += ` ${result[0]?.transcript || ''}`;
        }
      }
    };
    instance.onend = () => {
      speechRecognition.value = null;
      resolveNativeRecognitionDone?.();
      resolveNativeRecognitionDone = null;
    };
    instance.onerror = () => {
      // MediaRecorder and server transcription remain available when the
      // optional browser recognition service is unavailable.
    };
    speechRecognition.value = instance;
    instance.start();
  } catch {
    resetSpeechRecognition();
  }
};

const finishSpeechRecognition = async () => {
  const instance = speechRecognition.value;
  if (instance) {
    try {
      instance.stop();
    } catch {
      // The browser may already have stopped recognition.
    }
  }

  if (nativeRecognitionDone) {
    await Promise.race([
      nativeRecognitionDone,
      new Promise(resolve => {
        setTimeout(resolve, 750);
      }),
    ]);
  }

  return nativeTranscript.trim();
};

const resetRecorder = () => {
  recorder.value = null;
  chunks.value = [];
  isRecording.value = false;
  stopTracks();
  resetSpeechRecognition();
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
    recorder.value.onstop = async () => {
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
      const browserTranscript = await finishSpeechRecognition();
      if (browserTranscript) file.nativeTranscript = browserTranscript;
      resetRecorder();
      emit('finishRecord', file);
    };
    recorder.value.start();
    isRecording.value = true;
    startSpeechRecognition();
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
