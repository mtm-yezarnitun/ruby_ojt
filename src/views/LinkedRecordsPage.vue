<template>
  <div class="container">
    <h1> ⧉ Sheet Links </h1>
    <LinkedRecords />
  </div>
</template>

<script setup>
import LinkedRecords from '../components/LinkedRecords.vue'
</script>

<style scoped>
.container {  
  min-width: 1216px;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 2rem;
}
</style>
