<template>
  <div class="container">
    <h1> ⧉ Sheet Preview </h1>
    <SheetPreview />
  </div>
</template>

<script setup>
import SheetPreview from '../components/SheetPreview.vue'
</script>

<style scoped>
.container {  
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 2rem;
}
</style>
