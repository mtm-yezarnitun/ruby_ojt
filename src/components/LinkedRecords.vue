<template>
  <div class="link-manager-page">
    <div v-if="loading" class="loading-modal">
      <div class="loading-box">
        <div class="spinner"></div>
        <p>Loading Links...</p>
      </div>
    </div>
    <span class="back-btn">
      <router-link :to="`/sheets`">Back</router-link>
    </span>

    <div class="link-selects">
      <div class="side-box">
        <p>Source Spreadsheet:</p>
        <select v-model="selectedSourceSpreadsheet">
          <option disabled value="">Select Spreadsheet</option>
          <option v-for="ss in allSpreadsheets" :key="ss.id" :value="ss.id">
            {{ ss.name }}
          </option>
        </select>
        <button @click="loadSourceSheets">Load Sheets</button>
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
      </div>
    </div>

    <div class="link-selects">
      <div v-if="sourceSheets.length" class="side-box">
        <p>Source Sheet:</p>
        <select v-model="selectedSourceSheet" @change="loadSourceColumns">
          <option disabled value="">Select Sheet</option>
          <option v-for="s in sourceSheets" :key="s.sheet_id" :value="s">
            {{ s.title }}
          </option>
        </select>

        <p>Source Column:</p>
        <select v-model="selectedSourceColumn">
          <option disabled value="">Select Column</option>
          <option v-for="col in sourceColumns" :key="col">{{ col }}</option>
        </select>
      </div>

      <div  v-if="targetSheets.length" class="side-box">
        <p>Target Sheet:</p>
        <select v-model="selectedTargetSheet" @change="loadTargetColumns">
          <option disabled value="">Select Sheet</option>
          <option v-for="s in targetSheets" :key="s.sheet_id" :value="s">
            {{ s.title }}
          </option>
        </select>

        <p>Target Column:</p>
        <select v-model="selectedTargetColumn">
          <option disabled value="">Select Column</option>
          <option v-for="col in targetColumns" :key="col">{{ col }}</option>
        </select>
      </div>
    </div>

    <div class="link-actions">
      <button
        class="btn"
        :disabled="!canLink"
        @click="createLink"
      >
        Create Link
      </button>
      <button class="btn cancel" @click="reset">Reset</button>
    </div>

    <div class="link-list">
      <button @click="linksToggle()">Existing Links</button>
      <div v-if="link">
        <div v-if="!linkedRecords.length">No links yet.</div>
          <ul v-else>
            <li
              v-for="link in linkedRecords"
              :key="link.id"
            >
              <span>
                {{ sheetNames[link.source_sheet_id] || 'Unknown' }}'s {{ link.source_column }} --→
                {{ sheetNames[link.target_sheet_id] || 'Unknown' }}'s {{ link.target_column }}
              </span>
              <button @click="unlink(link.id)" class="rmv-btn">Remove</button>
            </li>
          </ul>
        </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useStore } from 'vuex'

const store = useStore()
const loading = ref(false)

const link = ref(false)
const allSpreadsheets = ref([])
const linkedRecords = ref([])
const currentUser = computed(() => store.getters['auth/user'])

const selectedSourceSpreadsheet = ref('')
const selectedTargetSpreadsheet = ref('')
const selectedSourceSheet = ref([])
const selectedTargetSheet = ref([])
const selectedSourceColumn = ref('')
const selectedTargetColumn = ref('')

const sourceSheets = ref([])
const targetSheets = ref([])
const sourceColumns = ref([])
const targetColumns = ref([])

const sheetNames = ref({})

const canLink = computed(() =>
  selectedSourceSpreadsheet.value &&
  selectedTargetSpreadsheet.value &&
  selectedSourceSheet.value &&
  selectedTargetSheet.value &&
  selectedSourceColumn.value &&
  selectedTargetColumn.value
)

onMounted(async () => {
  try {
    loading.value = true
    await store.dispatch('sheets/fetchSpreadsheets')
    const response = store.getters['sheets/spreadsheets']
    allSpreadsheets.value = ( response || []).filter(ss => ss.email === currentUser.value?.email )
    
    await store.dispatch('sheets/fetchLinkedRecords')
    const res = store.getters['sheets/linkedRecords']
    linkedRecords.value = ( res || [] )
    
  } catch (e) {
      console.error('Error loading spreadsheets', e)
  } finally {
      loading.value = false
  }
});

async function linksToggle(){
  link.value = !link.value
  await loadSheetNames()
}
async function loadSheetNames() {
  loading.value = true
  await store.dispatch('sheets/fetchSpreadsheets');
  const spreadsheets = store.getters['sheets/spreadsheets'] || [];

  for (const ss of spreadsheets) {
    await store.dispatch('sheets/fetchSpreadsheet', ss.id);
    const data = store.getters['sheets/selectedSpreadsheet'];

    (data.sheets || []).forEach(sheet => {
      sheetNames.value[sheet.sheet_id] = sheet.title;
    });
  }
  loading.value = false;
}

function extractColumns(data) {
  if (!data) return []
  const sheet = data.sheets?.[0] || data.spreadsheet?.sheets?.[0]
  const rows = sheet?.data?.[0]?.row_data || []
  const firstRow = rows[0]?.values || []
  return firstRow.map(cell => cell.formatted_value ?? cell.formattedValue ?? '')
}

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

async function loadSourceColumns() {
  if (!selectedSourceSheet.value) return
  loading.value = true
  try {
    await store.dispatch('sheets/fetchSheetPreview', {
      spreadsheetId: selectedSourceSpreadsheet.value,
      sheetName: selectedSourceSheet.value.title
    })
    const src = store.getters['sheets/selectedSheetData']

    sourceColumns.value = extractColumns(src)
  } catch (err) {
    console.error('Error loading source columns:', err)
  } finally {
    loading.value = false
  }
}

async function loadTargetColumns() {
  if (!selectedTargetSheet.value) return
  loading.value = true
  try {
    await store.dispatch('sheets/fetchSheetPreview', {
      spreadsheetId: selectedTargetSpreadsheet.value,
      sheetName: selectedTargetSheet.value.title
    })
    const tag = store.getters['sheets/selectedSheetData']

    targetColumns.value = extractColumns(tag)


  } catch (err) {
    console.error('Error loading target columns:', err)
  } finally {
    loading.value = false
  }
}

async function createLink() {
  try {
    loading.value = true
    await store.dispatch('sheets/createLink', {
      source_spreadsheet_id: selectedSourceSpreadsheet.value,
      source_sheet_id: selectedSourceSheet.value.sheet_id,
      source_sheet_name: selectedSourceSheet.value.title,
      source_column: selectedSourceColumn.value,
      target_spreadsheet_id: selectedTargetSpreadsheet.value,
      target_sheet_id: selectedTargetSheet.value.sheet_id,
      target_sheet_name: selectedTargetSheet.value.title,
      target_column: selectedTargetColumn.value
    })

    await store.dispatch('sheets/fetchLinkedRecords')
    const res = store.getters['sheets/linkedRecords']
    linkedRecords.value = ( res || [] )
    window.$toast?.success?.('Link created successfully!')
  } catch (err) {
    console.error('Error creating link:', err)
    window.$toast?.error?.('Failed to create link')
  } finally {
    loading.value = false
  }
}

async function unlink(id) {
  try {
    await store.dispatch('sheets/unlinkLink', id)
    await store.dispatch('sheets/fetchLinkedRecords')
    const res = store.getters['sheets/linkedRecords']
    linkedRecords.value = ( res || [] )
    window.$toast?.success?.('Link removed successfully!')
  } catch (err) {
    console.error('Error unlinking:', err)
    window.$toast?.error?.('Failed to remove link')
  }
}

function reset() {
  selectedSourceSpreadsheet.value = ''
  selectedTargetSpreadsheet.value = ''
  selectedSourceSheet.value = ''
  selectedTargetSheet.value = ''
  selectedSourceColumn.value = ''
  selectedTargetColumn.value = ''
  sourceSheets.value = []
  targetSheets.value = []
  sourceColumns.value = []
  targetColumns.value = []
}
</script>

<style scoped>
.rmv-btn {
  margin-left: 20px;
}
.back-btn {
  position: absolute;
  top: 32%;
  left: 9%;
}
.link-manager-page {
  padding: 20px;
  min-width: 1200px;
}
.link-selects {
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
.link-actions {
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
.loading-modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0,0,0,0.4);
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
  box-shadow: 0 4px 12px rgba(0,0,0,0.3);
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
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
.link-list {
  margin-top: 30px;
}
.link-list ul {
  padding: 0;
  justify-content: space-evenly;
  width: 70%;
  flex-direction: column;
  align-items: end;
}
</style>
