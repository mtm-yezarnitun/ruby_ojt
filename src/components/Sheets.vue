<template>
  <div>
    <div v-if="selectedSpreadsheet" class="selected-sheet">
      <h2 class="spreadsheet-title">{{ selectedSpreadsheet.spreadsheet_title }}</h2>

      <ul class="sheet-tabs">
        <li v-for="s in selectedSpreadsheet.sheets" :key="s.sheet_id" class="sheet-tab" @click="selectSheet(s.title)">
          {{ s.title }}
        </li>
      </ul>
    </div>

    <div class="spreadsheets-grid">
      <div v-for="sheet in spreadsheets" :key="sheet.id" class="sheet-card" @click="selectSpreadsheet(sheet.id)">
        <h3 class="sheet-name">{{ sheet.name }}</h3>
        <p class="sheet-owner">Owner: {{ sheet.owner }}</p>
      </div>
    </div>

    <div v-if="loading" class="loading-modal">
      <div class="loading-box">
        <div class="spinner"></div>
        <p>Loading sheets...</p>
      </div>
    </div>
    
    <div v-if="error" class="error">{{ error }}</div>
  </div>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useStore } from 'vuex'
import { useRouter } from 'vue-router'

const store = useStore()
const router = useRouter()

const spreadsheets = computed(() => store.getters['sheets/spreadsheets'])
const selectedSpreadsheet = computed(() => store.getters['sheets/selectedSpreadsheet'])
const loading = computed(() => store.getters['sheets/loading'])
const error = computed(() => store.getters['sheets/error'])
const selectedSheetData = computed(() => store.getters['sheets/selectedSheetData']);

const selectSpreadsheet = (id) => {
  store.dispatch('sheets/clearSelectedSpreadsheet');
  store.dispatch('sheets/clearSelectedSheetData');
  store.dispatch('sheets/fetchSpreadsheet', id)
}

const selectSheet = (sheetName) => {
  const spreadsheetId = selectedSpreadsheet.value.id
  router.push({ path: `/preview/${spreadsheetId}/${sheetName}` })
}

onMounted(() => {
  store.dispatch('sheets/fetchSpreadsheets')
})
</script>

<style scoped>
.title {
  font-size: 1.8rem;
  margin-bottom: 1rem;
  font-weight: bold;
}

.spreadsheets-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
}

.selected-sheet {
  padding: 1rem;
}

.spreadsheet-title {
  font-size: 2rem;
  font-weight: bold;
  margin-bottom: 1rem;
}
.spinner {
  border: 3px solid #f3f3f3;
  border-top: 3px solid #43e192;
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 1s linear infinite;
  margin: 0 auto;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.sheet-tabs {
    list-style: none;
    justify-content: center;
    align-self: center;
    align-items: center;
    align-content: center;
    padding: 0;
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin: 0 auto;
}

.loading-modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.4);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 9999;
}

.loading-box {
  background-color: rgb(109, 109, 109);
  padding: 1rem 3rem;
  border-radius: 10%;
  font-size: 1.2rem;
  font-weight: bold;
  opacity: 0.7;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}

.loading-box p {
  margin: 0 auto;
}

.sheet-tab {
  padding: 0.4rem 0.8rem;
  background-color: #000000;
  border: 1px solid #cbd5e0;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 500;
  transition: background-color 0.2s, transform 0.1s;
}

.sheet-tab:hover {
  background-color: #000000;
  transform: translateY(-1px);
}

.sheet-card {
  flex: 1 1 250px;
  padding: 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background-color: #000000;
  cursor: pointer;
  transition: transform 0.1s ease, box-shadow 0.2s ease;
}

.sheet-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.sheet-name {
  font-weight: 600;
  margin-bottom: 0.3rem;

}

.sheet-owner {
  font-size: 0.85rem;
  color: #bebebe;
}

.loading,
.error {
  margin-top: 1rem;
  font-weight: bold;
  color: #e53e3e;
}

.spreadsheets-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
}

.sheet-tab {
  padding: 0.3rem 0.6rem;
  background: #000000;
  border: 1px solid #cbd5e0;
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.1s;
}

.sheet-tab:hover {
  background: #8c8d8e;
  color: black;
}
</style>
