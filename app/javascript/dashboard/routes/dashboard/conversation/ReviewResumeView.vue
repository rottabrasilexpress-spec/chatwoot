<script setup>
import ReviewResume from 'dashboard/components-next/Conversation/Review/ReviewResume.vue';
import FollowingClients from 'dashboard/components-next/Conversation/Review/FollowingClients.vue';
</script>

<template>
  <main class="flex-1 min-w-0 overflow-y-auto bg-n-background p-4 sm:p-6">
    <div
      class="mx-auto w-full max-w-7xl grid grid-cols-1 xl:grid-cols-2 gap-6 items-start"
    >
      <div
        class="min-w-0 overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
      >
        <ReviewResume />
      </div>
      <div
        class="min-w-0 overflow-hidden rounded-xl border border-n-teal-4 bg-n-solid-1"
      >
        <FollowingClients />
      </div>
    </div>
  </main>
</template>
