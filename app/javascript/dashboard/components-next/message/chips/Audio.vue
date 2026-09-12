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
const PLAYBACK_SPEEDS = [1, 1.5, 2];
const playbackSpeed = ref(1);
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

const playbackSpeedLabel = computed(() => `${playbackSpeed.value}x`);

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

const changePlaybackSpeed = () => {
  const currentIndex = PLAYBACK_SPEEDS.indexOf(playbackSpeed.value);
  playbackSpeed.value =
    PLAYBACK_SPEEDS[(currentIndex + 1) % PLAYBACK_SPEEDS.length];
  if (audioPlayer.value) audioPlayer.value.playbackRate = playbackSpeed.value;
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
      <div class="rotta-audio__meta">
        <span class="rotta-audio__duration">
          {{ formatTime(currentTime) }}
          <span class="rotta-audio__time-separator" aria-hidden="true" />
          {{ formatTime(duration) }}
        </span>
        <button
          data-test="audio-speed"
          class="rotta-audio__speed"
          type="button"
          :aria-label="`Velocidade do áudio: ${playbackSpeedLabel}`"
          :title="`Velocidade do áudio: ${playbackSpeedLabel}`"
          @click="changePlaybackSpeed"
        >
          {{ playbackSpeedLabel }}
        </button>
      </div>
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
  width: min(22rem, 100%);
  flex-direction: column;
  gap: 0.45rem;
  padding: 0;
  color: inherit;
  background: transparent;
  border: 0;
}

.rotta-audio--outgoing {
  color: #111b21;
}

.rotta-audio__row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
}

.rotta-audio__play {
  display: grid;
  flex: 0 0 auto;
  width: 2.15rem;
  height: 2.15rem;
  place-items: center;
  color: #fff;
  background: #f97316;
  border: 0;
  border-radius: 999px;
  cursor: pointer;
}

.rotta-audio__play:hover {
  background: #ea580c;
}

.rotta-audio__waveform {
  position: relative;
  display: flex;
  flex: 1 1 auto;
  min-width: 0;
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
  background: #8696a0;
  border-radius: 99px;
  opacity: 0.82;
}

.rotta-audio__bar--played {
  background: #f97316;
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

.rotta-audio__meta {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 0.35rem;
}

.rotta-audio__duration {
  min-width: 5.5rem;
  color: #667781;
  font-size: 0.7rem;
  font-variant-numeric: tabular-nums;
  text-align: right;
}

.rotta-audio__time-separator::before {
  content: '/';
  padding: 0 0.15rem;
}

.rotta-audio__speed {
  min-width: 2.35rem;
  padding: 0.2rem 0.35rem;
  color: #c2410c;
  font-size: 0.7rem;
  font-variant-numeric: tabular-nums;
  font-weight: 600;
  background: rgb(249 115 22 / 0.12);
  border: 0;
  border-radius: 999px;
  cursor: pointer;
}

.rotta-audio__speed:hover {
  color: #9a3412;
  background: rgb(249 115 22 / 0.2);
}
</style>
