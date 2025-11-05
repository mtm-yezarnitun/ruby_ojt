<template>
  <div>
    <div class="title">
      <h1 v-if="sheetData" class="spreadsheet-title">{{ sheetData.spreadsheet_title }} / </h1>
      <h2 class="sheet-name">{{ sheetName }}</h2>
    </div>
    <span class="back-btn">
      <router-link :to="`/sheets`">Back</router-link>
    </span>
    <div v-if="loading" class="loading-modal">
      <div class="loading-box">Loading...</div>
    </div>

    <div v-if="sheetData" class="sheet-preview">
      <table>
        <tbody>
          <tr v-for="(row, rIndex) in sheetData.values" :key="rIndex">
            <td v-for="(cell, cIndex) in row" :key="cIndex">
              {{ cell }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="error">{{ error }}</div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { useStore } from 'vuex'
import { useRoute } from 'vue-router'

const store = useStore()
const route = useRoute()

const spreadsheetId = route.params.spreadsheetId
const sheetName = route.params.sheetName

const sheetData = ref(null)
const loading = ref(true)
const error = ref(null)

onMounted(async () => {
  try {
    loading.value = true
    error.value = null
    await store.dispatch('sheets/fetchSheetPreview', { spreadsheetId, sheetName })
    sheetData.value = store.getters['sheets/selectedSheetData']
  } catch (e) {
    error.value = 'Failed to load sheet preview.'
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.title {
  display: flex;
  justify-content: center;
  align-items: center;
}

.sheet-name {
  margin-bottom: 0.7rem;
}

.loading-modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 9999;
}

.loading-box {
  background: #6d6d6d;
  padding: 3rem 5rem;
  border-radius: 10%;
  font-weight: bold;
  color: white;
  animation: floatPulse 1.5s ease-in-out infinite;
}

@keyframes floatPulse {

  0%,
  50%,
  100% {
    transform: translateY(0) scale(1);
    opacity: 0.85;
  }

  25% {
    transform: translateY(-8px) scale(1.02);
    opacity: 0.9;
  }

  75% {
    transform: translateY(8px) scale(1.02);
    opacity: 0.9;
  }
}

.sheet-preview {
  margin-top: 1rem;
  overflow-x: auto;
}

.spreadsheet-title {
  font-size: 2rem;
  font-weight: bold;
  margin-bottom: 1rem;
}

.sheet-preview table {
  border-collapse: collapse;
  width: 100%;
  table-layout: fixed;
}

.sheet-preview td {
  border: 1px solid #cbd5e0;
  padding: 0.4rem;
  text-align: left;
  width: 40%;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.back-btn {
  position: absolute;
  top: 32%;
  left: 9%;
}
</style>
