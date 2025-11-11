<template>
  <div class="container">
    <h1> ⧉ Sheet Comparison </h1>
    <SheetCompare />
  </div>
</template>

<script setup>
import SheetCompare from '../components/SheetCompare.vue'
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
