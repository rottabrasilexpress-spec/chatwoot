<script setup>
import SharedFiles from '../SharedFiles.vue';

const attachmentHeading = 'Anexos';
</script>

<template>
  <section
    class="rotta-contact-attachments"
    aria-labelledby="rotta-contact-attachments-title"
  >
    <h3 id="rotta-contact-attachments-title">{{ attachmentHeading }}</h3>
    <SharedFiles />
  </section>
</template>
