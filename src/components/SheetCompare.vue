<template>
  <div class="compare-page">

    <div v-if="loading" class="loading-modal">
      <div class="loading-box">
        <div class="spinner"></div>
        <p>Loading sheet data...</p>
      </div>
    </div>
    <span class="back-btn">
      <router-link :to="`/sheets`">Back</router-link>
    </span>
    <div>
      <div class="compare-box">
        <h3>Select Source & Target Sheets</h3>

        <div class="compare-selects">
          <div class="side-box">
            <p>Source Spreadsheet:</p>
            <select v-model="selectedSourceSpreadsheet">
              <option disabled value="">Select Spreadsheet</option>
              <option v-for="ss in allSpreadsheets" :key="ss.id" :value="ss.id">
                {{ ss.name }}
              </option>
            </select>
            <button @click="loadSourceSheets">Load Sheets</button>

            <p>Source Sheet:</p>
            <select v-model="selectedSourceSheet">
              <option disabled value="">Select Sheet</option>
              <option v-for="s in sourceSheets" :key="s.sheet_id" :value="s.title">
                {{ s.title }}
              </option>
            </select>
          </div>

          <div class="side-box">
            <p>Target Spreadsheet:</p>
            <select v-model="selectedTargetSpreadsheet">
              <option disabled value="">Select Spreadsheet</option>
              <option v-for="ss in allSpreadsheets" :key="ss.id" :value="ss.id">
                {{ ss.name }}
              </option>
            </select>
            <button @click="loadTargetSheets">Load Sheets</button>

            <p>Target Sheet:</p>
            <select v-model="selectedTargetSheet">
              <option disabled value="">Select Sheet</option>
              <option v-for="s in targetSheets" :key="s.sheet_id" :value="s.title">
                {{ s.title }}
              </option>
            </select>
          </div>
        </div>

        <div class="compare-actions">
          <button @click="compareSheets" class="btn">Compare</button>
          <button @click="reset" class="btn cancel">Reset</button>
        </div>
      </div>

      <div v-if="sourceSheet.length && targetSheet.length" class="compare-results">
        <div class="sheet-table">
          <p>{{ selectedSourceSheet }}</p>
          <table border="1">
            <tbody>
              <tr v-for="(row, r) in maxRows" :key="'src-'+r">
                <td
                  v-for="(cell, c) in maxCols"
                  :key="'src-'+r+'-'+c"
                  :class="{ highlight: sourceSheet[r]?.[c] !== targetSheet[r]?.[c] }"
                >
                  {{ sourceSheet[r]?.[c] ?? '' }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="sheet-table">
          <p>{{ selectedTargetSheet }}</p>
          <table border="1">
            <tbody>
              <tr v-for="(row, r) in maxRows" :key="'tgt-'+r">
                <td
                  v-for="(cell, c) in maxCols"
                  :key="'tgt-'+r+'-'+c"
                  :class="{ highlight: sourceSheet[r]?.[c] !== targetSheet[r]?.[c] }"
                >
                  {{ targetSheet[r]?.[c] ?? '' }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useStore } from 'vuex'

const store = useStore()
const loading = ref(false)

const allSpreadsheets = ref([])

const selectedSourceSpreadsheet = ref('')
const selectedTargetSpreadsheet = ref('')
const selectedSourceSheet = ref('')
const selectedTargetSheet = ref('')

const sourceSheets = ref([])
const targetSheets = ref([])

const sourceSheet = ref([])
const targetSheet = ref([])

const currentUser = computed(() => store.getters['auth/user'])
const maxRows = computed(() => Math.max(sourceSheet.value.length, targetSheet.value.length))
const maxCols = computed(() => {
  const srcCols = Math.max(...sourceSheet.value.map((r) => r.length || 0), 0)
  const tgtCols = Math.max(...targetSheet.value.map((r) => r.length || 0), 0)
  return Math.max(srcCols, tgtCols)
})

onMounted(async () => {
  try {
    loading.value = true
    await store.dispatch('sheets/fetchSpreadsheets')
    const response = store.getters['sheets/spreadsheets']
    allSpreadsheets.value = (response || []).filter(
      ss => ss.email === currentUser.value?.email
    )
  } catch (e) {
    console.error('Error loading spreadsheets', e)
  } finally {
    loading.value = false
  }
})

async function loadSourceSheets() {
  if (!selectedSourceSpreadsheet.value) return
  loading.value = true
  try {
    await store.dispatch('sheets/fetchSpreadsheet', selectedSourceSpreadsheet.value)
    sourceSheets.value = store.getters['sheets/selectedSpreadsheet']?.sheets || []
  } catch (err) {
    console.error('Failed to load source sheets:', err)
  } finally {
    loading.value = false
  }
}

async function loadTargetSheets() {
  if (!selectedTargetSpreadsheet.value) return
  loading.value = true
  try {
    await store.dispatch('sheets/fetchSpreadsheet', selectedTargetSpreadsheet.value)
    targetSheets.value = store.getters['sheets/selectedSpreadsheet']?.sheets || []
  } catch (err) {
    console.error('Failed to load target sheets:', err)
  } finally {
    loading.value = false
  }
}

async function compareSheets() {
  if (
    !selectedSourceSpreadsheet.value ||
    !selectedSourceSheet.value ||
    !selectedTargetSpreadsheet.value ||
    !selectedTargetSheet.value
  ) {
    return window.$toast?.error?.('Please select both source and target sheets.')
  }

  loading.value = true
  try {
    await store.dispatch('sheets/fetchSheetPreview', {
      spreadsheetId: selectedSourceSpreadsheet.value,
      sheetName: selectedSourceSheet.value
    })
    const src = store.getters['sheets/selectedSheetData']
    console.log('SOURCE SHEET RAW:', src)
    console.log('SOURCE SHEET STRUCTURE:', src.spreadsheet || src)
    sourceSheet.value = extractRows(src)

    await store.dispatch('sheets/fetchSheetPreview', {
      spreadsheetId: selectedTargetSpreadsheet.value,
      sheetName: selectedTargetSheet.value
    })
    const tgt = store.getters['sheets/selectedSheetData']
    console.log('TARGET SHEET RAW:', tgt)
    console.log('TARGET SHEET STRUCTURE:', tgt.spreadsheet || tgt)
    targetSheet.value = extractRows(tgt)

    console.log('Parsed Source Rows:', sourceSheet.value.length)
    console.log('Parsed Target Rows:', targetSheet.value.length)
  } catch (err) {
    console.error('Failed to compare sheets:', err)
  } finally {
    loading.value = false
  }
}

function extractRows(data) {
  if (!data) return []
  const sheets = data.sheets || data.spreadsheet?.sheets
  const sheetObj = sheets?.[0]
  if (!sheetObj) return []

  const dataBlock = sheetObj.data?.[0]
  if (!dataBlock) return []

  const rows = dataBlock.row_data || dataBlock.rowData || []
  return rows.map(row =>
    (row.values || []).map(cell =>
      cell.formatted_value ?? cell.formattedValue ?? ''
    )
  )
}

function reset() {
  selectedSourceSpreadsheet.value = ''
  selectedTargetSpreadsheet.value = ''
  selectedSourceSheet.value = ''
  selectedTargetSheet.value = ''
  sourceSheet.value = []
  targetSheet.value = []
}
</script>

<style scoped>
.back-btn {
  position: absolute;
  top: 32%;
  left: 9%;
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
  background-color: rgb(109, 109, 109);
  padding: 1rem 3rem;
  border-radius: 10%;
  font-size: 1.2rem;
  font-weight: bold;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}

.loading-box p {
  margin: 0 auto;
}

.spinner {
  border: 3px solid #f3f3f3;
  border-top: 3px solid #43e192;
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 1s linear infinite;
  margin: 0 auto 20px;
}

@keyframes spin {
  0% {
    transform: rotate(0deg);
  }

  100% {
    transform: rotate(360deg);
  }
}

.compare-page {
  padding: 20px;
  min-width: 1216px;
}

.compare-selects {
  display: flex;
  justify-content: center;
  gap: 40px;
}

.side-box {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 400px;
}

.side-box select {
    padding: 10px;
}

.compare-actions {
  max-width: 1035px;
  margin-top: 20px;
  display: flex;
  gap: 10px;
  justify-content: flex-end;
}

.btn {
  padding: 6px 12px;
  background: #4caf50;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
}

.btn.cancel {
  background: #f44336;
}

.sheet-table {
  flex: 1;
  overflow-x: auto;
}

.compare-results {
  display: flex;
  gap: 50px;
  margin-top: 30px;
}
.compare-results {
  display: flex;
  gap: 40px;
  margin-top: 30px;
  flex-wrap: wrap;
}

.sheet-table {
  flex: 1 1 45%; 
  overflow-x: auto;
  max-height: 70vh;
  display: flex;
  flex-direction: column;
}

.sheet-table p {
  font-weight: bold;
  margin-bottom: 8px;
}

.sheet-table table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed; 
}

.sheet-table td {
  padding: 12px 8px;
  border: 1px solid #080808;
  color: #000000;
  text-align: center;
  font-size: 14px;
  min-width: 60px; 
  word-break: break-word;
  background: #ffffff;
}

.sheet-table td.highlight {
    background-color: #c5e26e;
  /* background-color: #ffe082;  */
}

.sheet-table::-webkit-scrollbar {
  height: 8px;
}

.sheet-table::-webkit-scrollbar-thumb {
  background: #ccc;
  border-radius: 4px;
}

.sheet-table::-webkit-scrollbar-track {
  background: #f1f1f1;
}

.loading {
  font-size: 18px;
  color: #777;
}
</style>
