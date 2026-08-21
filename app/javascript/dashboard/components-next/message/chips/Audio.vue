<script setup>
import {
  computed,
  onMounted,
  useTemplateRef,
  ref,
  getCurrentInstance,
} from 'vue';
import Icon from 'next/icon/Icon.vue';
import { timeStampAppendedURL } from 'dashboard/helper/URLHelper';
import { useEmitter } from 'dashboard/composables/emitter';
import { emitter } from 'shared/helpers/mitt';
import { useMessageContext } from '../provider.js';
import { MESSAGE_TYPES } from '../constants.js';

const { attachment } = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
  showTranscribedText: {
    type: Boolean,
    default: true,
  },
});

defineOptions({
  inheritAttrs: false,
});

const timeStampURL = computed(() => {
  return timeStampAppendedURL(attachment.dataUrl);
});

const TRANSCRIPT_PREVIEW_LENGTH = 200;
const isTranscriptExpanded = ref(false);
const isTranscriptLong = computed(
  () => (attachment.transcribedText?.length || 0) > TRANSCRIPT_PREVIEW_LENGTH
);
const displayedTranscript = computed(() => {
  const text = attachment.transcribedText || '';
  if (!isTranscriptLong.value || isTranscriptExpanded.value) return text;
  return `${text.slice(0, TRANSCRIPT_PREVIEW_LENGTH).trimEnd()}…`;
});

const audioPlayer = useTemplateRef('audioPlayer');
const { messageType } = useMessageContext();

const isPlaying = ref(false);
const currentTime = ref(0);
const duration = ref(0);
const waveformLabel = 'Posição do áudio';
const waveformBars = [
  24, 42, 31, 58, 38, 72, 46, 88, 54, 36, 64, 80, 48, 30, 62, 44, 76, 52, 34,
  68, 45, 84, 58, 38, 70, 48, 30, 56, 74, 42, 64, 36, 82, 50, 28, 60, 44, 72,
  34, 54, 40, 66, 32, 48, 27,
];

const { uid } = getCurrentInstance();

// MediaRecorder-produced WebM/Opus blobs lack a Duration header → <audio>.duration
// resolves to Infinity until we seek past the end, which forces the engine to
// scan the file and compute the real length. Safe no-op for files with a real
// duration already (mp3/m4a/etc).
const resolveStreamingDuration = () => {
  const el = audioPlayer.value;
  if (!el) return;
  const onTimeUpdate = () => {
    el.removeEventListener('timeupdate', onTimeUpdate);
    el.currentTime = 0;
    duration.value = el.duration;
  };
  el.addEventListener('timeupdate', onTimeUpdate);
  try {
    el.currentTime = Number.MAX_SAFE_INTEGER;
  } catch {
    el.removeEventListener('timeupdate', onTimeUpdate);
  }
};

const onLoadedMetadata = () => {
  const d = audioPlayer.value?.duration;
  if (!Number.isFinite(d)) {
    resolveStreamingDuration();
    return;
  }
  duration.value = d;
};

// There maybe a chance that the audioPlayer ref is not available
// When the onLoadMetadata is called, so we need to set the duration
// value when the component is mounted
onMounted(() => {
  const d = audioPlayer.value?.duration;
  if (Number.isFinite(d)) duration.value = d;
});

// Listen for global audio play events and pause if it's not this audio
useEmitter('pause_playing_audio', currentPlayingId => {
  if (currentPlayingId !== uid && isPlaying.value) {
    try {
      audioPlayer.value.pause();
    } catch {
      /* ignore pause errors */
    }
    isPlaying.value = false;
  }
});

const formatTime = time => {
  if (!time || Number.isNaN(time)) return '00:00';
  const minutes = Math.floor(time / 60);
  const seconds = Math.floor(time % 60);
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
};

const onTimeUpdate = () => {
  currentTime.value = audioPlayer.value?.currentTime;
};

const waveformProgress = computed(() => {
  if (!duration.value) return 0;
  return Math.min(100, (currentTime.value / duration.value) * 100);
});

const audioActionLabel = computed(() =>
  isPlaying.value ? 'Pausar áudio' : 'Reproduzir áudio'
);

const seekWaveform = event => {
  const bounds = event.currentTarget.getBoundingClientRect();
  const ratio = Math.max(
    0,
    Math.min(1, (event.clientX - bounds.left) / bounds.width)
  );
  const time = ratio * duration.value;
  if (!Number.isFinite(time)) return;
  audioPlayer.value.currentTime = time;
  currentTime.value = time;
};

const seek = event => {
  const time = Number(event.target.value);
  audioPlayer.value.currentTime = time;
  currentTime.value = time;
};

const playOrPause = () => {
  if (isPlaying.value) {
    audioPlayer.value.pause();
    isPlaying.value = false;
  } else {
    // Emit event to pause all other audio
    emitter.emit('pause_playing_audio', uid);
    audioPlayer.value.play();
    isPlaying.value = true;
  }
};

const onEnd = () => {
  isPlaying.value = false;
  currentTime.value = 0;
};
</script>

<template>
  <audio
    ref="audioPlayer"
    controls
    class="hidden"
    playsinline
    @loadedmetadata="onLoadedMetadata"
    @timeupdate="onTimeUpdate"
    @ended="onEnd"
  >
    <source :src="timeStampURL" />
  </audio>
  <div
    v-bind="$attrs"
    class="rotta-audio"
    :class="{ 'rotta-audio--outgoing': messageType === MESSAGE_TYPES.OUTGOING }"
  >
    <div class="rotta-audio__row">
      <button
        class="rotta-audio__play"
        type="button"
        :aria-label="audioActionLabel"
        @click="playOrPause"
      >
        <Icon
          v-if="isPlaying"
          class="size-5"
          icon="i-teenyicons-pause-small-solid"
        />
        <Icon v-else class="size-5" icon="i-teenyicons-play-small-solid" />
      </button>
      <div
        class="rotta-audio__waveform"
        role="slider"
        tabindex="0"
        :aria-valuemin="0"
        :aria-valuemax="duration || 0"
        :aria-valuenow="currentTime"
        :aria-label="waveformLabel"
        @click="seekWaveform"
      >
        <span
          v-for="(bar, index) in waveformBars"
          :key="index"
          class="rotta-audio__bar"
          :class="{
            'rotta-audio__bar--played':
              index / waveformBars.length < waveformProgress / 100,
          }"
          :style="{ height: `${bar}%` }"
        />
        <input
          type="range"
          min="0"
          :max="duration"
          :value="currentTime"
          class="rotta-audio__range"
          @input="seek"
        />
      </div>
      <span class="rotta-audio__duration">{{ formatTime(duration) }}</span>
    </div>

    <div
      v-if="attachment.transcribedText && showTranscribedText"
      class="text-n-slate-12 p-3 text-sm bg-n-alpha-1 rounded-lg w-full break-words"
    >
      {{ displayedTranscript }}
      <button
        v-if="isTranscriptLong"
        class="block mt-1 p-0 border-0 bg-transparent text-n-slate-11 hover:text-n-slate-12 font-medium"
        @click="isTranscriptExpanded = !isTranscriptExpanded"
      >
        {{
          isTranscriptExpanded
            ? $t('CONVERSATION.VOICE_CALL.TRANSCRIPT_SHOW_LESS')
            : $t('CONVERSATION.VOICE_CALL.TRANSCRIPT_SHOW_MORE')
        }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.rotta-audio {
  display: flex;
  width: min(25rem, 100%);
  flex-direction: column;
  gap: 0.45rem;
  padding: 0.6rem 0.7rem;
  color: #e9edef;
  background: #202c33;
  border: 0;
  border-radius: 0.85rem;
  box-shadow: 0 1px 1px rgb(0 0 0 / 12%);
}

.rotta-audio--outgoing {
  background: #075e54;
}

.rotta-audio__row {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  width: 100%;
}

.rotta-audio__play {
  display: grid;
  flex: 0 0 auto;
  width: 2.15rem;
  height: 2.15rem;
  place-items: center;
  color: #fff;
  background: rgb(255 255 255 / 16%);
  border: 0;
  border-radius: 999px;
  cursor: pointer;
}

.rotta-audio__play:hover {
  background: rgb(255 255 255 / 24%);
}

.rotta-audio__waveform {
  position: relative;
  display: flex;
  flex: 1 1 auto;
  align-items: center;
  gap: 2px;
  height: 2rem;
  cursor: pointer;
}

.rotta-audio__bar {
  z-index: 1;
  flex: 1 1 0;
  min-width: 2px;
  max-width: 4px;
  background: #8eb9ae;
  border-radius: 99px;
  opacity: 0.82;
}

.rotta-audio__bar--played {
  background: #7fc8df;
  opacity: 1;
}

.rotta-audio__range {
  position: absolute;
  inset: 0;
  z-index: 2;
  width: 100%;
  height: 100%;
  margin: 0;
  cursor: pointer;
  opacity: 0;
}

.rotta-audio__duration {
  min-width: 2.5rem;
  color: #d7e3e0;
  font-size: 0.7rem;
  font-variant-numeric: tabular-nums;
  text-align: right;
}
</style>
