<template>
  <div>
    <div class="title">
      <div class="name">
        <h1 v-if="sheetData" class="spreadsheet-title">{{ sheetData.spreadsheet_title.properties.title }} / </h1>
        <h2 class="sheet-name">{{ sheetName }}</h2>
        
        <span class="action-dropdown">
          <button class="action-toggle" @click="toggleActions">
            ⚙️
          </button>
          <div v-if="showActions" class="action-menu">
            <button v-if="isOwner" @click="renameBox()">Rename</button>
            <button v-if="isOwner" @click="openCopyModal()">Copy To</button>
            <button @click="openSortModal()">Sort</button>
            <button v-if="isOwner" @click="openPasteModal()">Data Copy</button>
            <button v-if="isOwner" @click="duplicateBox()">Duplicate</button>
            <button v-if="isOwner" @click="goToCompare"> Comparison</button>
            <button v-if="isOwner" @click="deleteBox()">Delete</button>
          </div>
        </span>
      </div>
        
      <div class="sheet-meta" v-if="sheetData">
        <p>Id : {{ sheetData.sheet_id }}</p>
        <p><strong>Row Count :</strong> {{actualRowCount}} |
        <strong>Column Count :</strong> {{ actualColCount }}</p>
        <p><strong>Owner:</strong> {{ sheetData.owner }}</p>
        <p v-if="sheetData.last_updated"><strong>Last Updated:</strong> {{ formatDate(sheetData.last_updated) }}</p>
      </div>

    </div>

    <span class="back-btn">
      <router-link :to="`/sheets`">Back</router-link>
    </span>

    <span  v-if="isOwner" class="edit-btn">
      <router-link :to="`/sheets/${spreadsheetId}/sheet/${sheetName}/edit`" class="edit-btn"> Edit</router-link>
    </span>

    <div v-if="deleting" class="delete-modal">
      <div class="delete-box">
        <p>Are you sure you want to delete this sheet ?</p>
        <button @click="deleteSheet()" class="del-btn">Confirm</button>
        <button @click="deleting = false" class="del-btn">Cancel</button>
      </div>
    </div>

    <div v-if="duplicating" class="duplicate-modal">
      <div class="duplicate-box">
        <p>Enter a name for the duplicated sheet:</p>
        <input type="text" v-model="duplicateTitle" placeholder="New sheet title" />
        <button @click="duplicateSheetAction" class="dup-btn">Duplicate</button>
        <button @click="duplicating = false" class="dup-btn">Cancel</button>
      </div>
    </div>

    <div v-if="renaming" class="rename-modal">
      <div class="rename-box">
        <p>Enter your new Title:</p>
        <input type="text" v-model="newTtl" placeholder="New sheet title" />
        <button @click="renameSheet" class="rnm-btn">Save</button>
        <button @click="renaming = false" class="rnm-btn">Cancel</button>
      </div>
    </div>

    <div v-if="loading" class="loading-modal">
      <div class="loading-box">
        <div class="spinner"></div>
        <p>Loading sheet data...</p>
      </div>
    </div>

    <div v-if="copying" class="copy-modal">
      <div class="copy-box">
        <p>Select destination spreadsheet:</p>
        <select v-model="selectedSpreadsheetToCopy">
          <option v-for="ss in allSpreadsheets" :key="ss.id" :value="ss.id">
            {{ ss.name }}
          </option>
        </select>
        <button @click="copySheetToSpreadsheet" class="cpy-btn">Copy</button>
        <button @click="copying = false" class="cpy-btn">Cancel</button>
      </div>
    </div>

    <div v-if="pasting" class="paste-modal">
      <div class="paste-box">
        <p>Select destination spreadsheet:</p>
        <select v-model="selectedSpreadsheetToCopy">
          <option v-for="ss in allSpreadsheets" :key="ss.id" :value="ss.id">
            {{ ss.name }}
          </option>
        </select>

        <button @click="loadSheets">Load Sheets</button>

        <div v-if="spreadsheetSelected" class="sheet-box">
          <p>Select destination sheet:</p>
          <select v-model="selectedSheetToCopy">
            <option disabled value="">Select Sheet</option>
            <option v-for="s in sourceSheets" :key="s.sheet_id" :value="s.title">
              {{ s.title }}
              </option>
          </select>
        </div>

        <div class="range-selector">
          <p>Copy Range (Source Sheet):</p>
          <label for="selectedRange.startRow"> Start Row : </label>
          <input type="number" v-model.number="selectedRange.startRow" placeholder="Start Row" />
          <label for="selectedRange.endRow"> End Row : </label>
          <input type="number" v-model.number="selectedRange.endRow" placeholder="End Row" />
          <label for="selectedRange.startCol"> Start Col : </label>
          <input type="number" v-model.number="selectedRange.startCol" placeholder="Start Col" />
          <label for="selectedRange.endCol"> End Col : </label>
          <input type="number" v-model.number="selectedRange.endCol" placeholder="End Col" />
        </div>

        <button @click="copySelectedRangeToTarget(selectedSpreadsheetToCopy, selectedSheetToCopy)" class="pst-btn">Copy Range</button>
        <button @click="pasting = false" class="pst-btn">Cancel</button>
      </div>
    </div>
    
    <div v-if="sorting" class="sheet-controls">
      <label for="filterText"> Filter : </label>
      <input v-model="filterText"/>
      <br>

      <button v-for="(col, index) in actualColCount" :key="index" @click="toggleSort(index)">
        Sort Col {{ index + 1 }} {{ sortColumnIndex === index ? (sortAsc ? '↑' : '↓') : '' }}
      </button>
      <button @click="reset"> Reset </button>
      <button @click="close"> Close </button>
    </div>

    <div v-if="sheetData" class="sheet-preview">
      <table>
        <tbody>
          <tr v-for="(row, rIndex) in displayedRows" :key="rIndex">
            <template v-for="(cell, cIndex) in (row.values || [])" :key="cIndex">
              <td v-if="!isMergedCellHidden(rIndex, cIndex)" :rowspan="getMergeSpan(rIndex, cIndex).rowspan"
                :colspan="getMergeSpan(rIndex, cIndex).colspan" :style="getCellStyle(cell.effective_format)">
                {{ getCellText(cell.formatted_value) }}
              </td>
            </template>
          </tr>
        </tbody>
      </table>
      <div v-if="rows.length == 0">
        <p>No Data inside Sheet Yet.</p>
      </div>
    </div>

    <div v-if="error">{{ error }}</div>
  </div>
</template>

<script setup>
import { onMounted, ref, computed } from 'vue'
import { useStore } from 'vuex'
import { useRouter, useRoute } from 'vue-router'

const store = useStore()
const router = useRouter()
const route = useRoute()

const spreadsheetId = route.params.spreadsheetId
const sheetName = ref(route.params.sheetName)

const sheetData = ref(null)
const loading = ref(true)
const error = ref(null)
const deleting = ref(null)

const renaming = ref(null)
const newTtl = ref()

const duplicating = ref()
const duplicateTitle = ref('')

const copying = ref(false)
const pasting = ref(false)
const spreadsheetSelected = ref(false)
const allSpreadsheets = ref([])
const sourceSheets= ref([])

const selectedSpreadsheetToCopy = ref(null)
const selectedSheetToCopy = ref(null)
const showActions = ref(false)

const sorting = ref(false)
const sortColumnIndex = ref(null)
const sortAsc = ref(true)
const filterText = ref(null)

const currentUser = computed(() => store.getters['auth/user'])
const sheet = computed(() => sheetData.value?.spreadsheet?.sheets?.[0])
const selectedRange = ref({ startRow: 0, endRow: 0, startCol: 0, endCol: 0 })

const merges = computed(() => sheet.value?.merges || [])
const isOwner = computed(() => {
  return sheetData.value?.owner === currentUser.value?.email
})

const rows = computed(() => {
  const rawRows = sheet.value?.data?.[0]?.row_data || []
  if (merges.value.length > 0) return rawRows
  return rawRows.filter(row => row.values && row.values.some(cell => cell.formatted_value))
})

const actualRowCount = computed(() => {
  return rows.value.length
})

const actualColCount = computed(() => {
  if (!rows.value || rows.value.length === 0) return 0

  let maxCols = 0
  rows.value.forEach(row => {
    const filledCols = (row.values || []).filter(cell => cell.formatted_value).length
    if (filledCols > maxCols) maxCols = filledCols
  })
  return maxCols
})

const formatDate = (isoString) => {
  return new Date(isoString).toLocaleString()
}

const displayedRows = computed(() => {
  let result = [...rows.value]

  if (filterText.value && filterText.value.trim() !== '') {
    const query = filterText.value.toLowerCase()
    result = result.filter(row =>
      row.values?.some(cell =>
        String(cell.formatted_value || '').toLowerCase().includes(query)
      )
    )
  }

  if (sortColumnIndex.value !== null) {
    result.sort((a, b) => {
      const valA = a.values?.[sortColumnIndex.value]?.formatted_value || ''
      const valB = b.values?.[sortColumnIndex.value]?.formatted_value || ''
      console.log(valA)
      console.log(valB)
      if (valA < valB) return sortAsc.value ? -1 : 1
      if (valA > valB) return sortAsc.value ? 1 : -1
      return 0
    })
  }

  return result
})

function goToCompare() {
  router.push({ name: 'SheetCompare' }) 
}

function toggleActions() {
  showActions.value = !showActions.value
}

function getMergeSpan(r, c) {
  for (const merge of merges.value) {
    const rowStart = merge.start_row_index ?? 0
    const rowEnd = merge.end_row_index ?? 0
    const colStart = merge.start_column_index ?? 0
    const colEnd = merge.end_column_index ?? 0

    if (r === rowStart && c === colStart) {
      return {
        rowspan: rowEnd - rowStart || 1,
        colspan: colEnd - colStart || 1,
      }
    }
  }
  return { rowspan: 1, colspan: 1 }
}

function isMergedCellHidden(r, c) {
  for (const merge of merges.value) {
    const rowStart = merge.start_row_index ?? 0
    const rowEnd = merge.end_row_index ?? 0
    const colStart = merge.start_column_index ?? 0
    const colEnd = merge.end_column_index ?? 0

    if (
      r >= rowStart &&
      r < rowEnd &&
      c >= colStart &&
      c < colEnd &&
      !(r === rowStart && c === colStart)
    ) {
      return true
    }
  }
  return false
}

function getCellText(formatted_value) {
  if (!formatted_value) return ''
  return (
    formatted_value ?? ''
  )
}

function bgColor(color) {
  if (!color) return '255, 255, 255'
  const r = Math.round((color.red ?? 0) * 255)
  const g = Math.round((color.green ?? 0) * 255)
  const b = Math.round((color.blue ?? 0) * 255)
  return `${r}, ${g}, ${b}`
}

function getCellStyle(format) {
  if (!format) return {}

  const bg = format.background_color
    ? `rgb(${bgColor(format.background_color)})`
    : 'white'

  const text = format.text_format || {}

  return {
    backgroundColor: bg,
    fontWeight: text.bold ? 'bold' : 'normal',
    fontFamily: text.font_family || 'Arial',
    color: text.foreground_color ? `rgb(${bgColor(text.foreground_color)})` : '#000',
    fontSize: text.font_size ? `${text.font_size}px` : 'inherit',
    fontStyle: text.italic ? 'italic' : 'normal',
    textDecoration: text.underline ? 'underline' : 'none',
    textAlign: format.horizontal_alignment?.toLowerCase() || 'center',
    verticalAlign: format.vertical_alignment?.toLowerCase() || 'middle',
    border: '1px solid #ccc',
    padding: '4px 8px',
    minWidth: '80px',
  }
}

function deleteBox() {
  deleting.value = true
  showActions.value = false
}

async function deleteSheet() {
  await store.dispatch('sheets/fetchSpreadsheet', spreadsheetId);
  const spreadsheet = store.getters['sheets/selectedSpreadsheet'];
  const allSheets = spreadsheet?.sheets || [];
  const currentSheet = allSheets.find(s => s.title === sheetName.value);

  if (!currentSheet)
  return window.$toast.error(`Cannot Delete Sheet! Sheet Doesn't Exists.`);

  if (allSheets.length <= 1) {
    return window.$toast.error('Cannot delete the last sheet in spreadsheet!');
  }

  try {
    loading.value = true;
    await store.dispatch('sheets/deleteSheet', [spreadsheetId, currentSheet.sheet_id]);
    deleting.value = null;
    
    store.dispatch('sheets/fetchSpreadsheet' , (spreadsheetId) )
    window.$toast.success(`Sheet Deleted Successfully!`);
    router.push({ path: `/sheets` })
    showActions.value = false
  } catch (err) {
    console.error(err);
    showActions.value = false
    deleting.value = false
    return window.$toast.error(`Cannot Delete Sheet!`);

  } finally {
    loading.value = false;
    showActions.value = false
    deleting.value = false
  }
}

function renameBox() {
  renaming.value = true
  showActions.value = false
  newTtl.value = sheet.value?.properties?.title || ''
}

async function renameSheet() {
  if (!newTtl.value || newTtl.value === sheet.value?.properties?.title) {
    window.$toast.error("Please enter a new sheet title")
    return
  }

  try {
    loading.value = true
    renaming.value = false
    await store.dispatch('sheets/renameSheet', {
      spreadsheetId,
      sheetId: sheet.value.properties.sheet_id,
      newTitle: newTtl.value
    })
    sheetName.value = newTtl.value
    await store.dispatch('sheets/fetchSheetPreview', { spreadsheetId, sheetName: newTtl.value })
    window.$toast.success(`Sheet renamed to "${newTtl.value}"`)
    router.push({ path: `/preview/${spreadsheetId}/${newTtl.value}` })
    showActions.value = false

  } catch (err) {
    console.error(err)
    window.$toast.error('Failed to rename sheet.')
    showActions.value = false
  } finally {
    loading.value = false
    newTtl.value = null
    showActions.value = false
  }
}

function duplicateBox() {
  showActions.value = false
  duplicating.value = true
  duplicateTitle.value = sheet.value?.properties?.title + " Copy" || ''
}

async function duplicateSheetAction() {
  if (!duplicateTitle.value) {
    return window.$toast.error("Please enter a title for the duplicated sheet")
  }

  try {
    loading.value = true
    duplicating.value = false

    await store.dispatch('sheets/duplicateSheet', {
      spreadsheetId,
      sheetId: sheet.value.properties.sheet_id,
      newTitle: duplicateTitle.value
    })

    store.dispatch('sheets/fetchSpreadsheet', (spreadsheetId) )
    window.$toast.success(`Sheet duplicated as "${duplicateTitle.value}"`)
    router.push({ path: `/sheets` })
    showActions.value = false
  } catch (err) {
    console.error(err)
    showActions.value = false
    window.$toast.error('Failed to duplicate sheet.')
  } finally {
    loading.value = false
    duplicateTitle.value = ''
    showActions.value = false
  }
}

async function openCopyModal() {
  copying.value = true
  showActions.value = false
  try {
    const response = store.getters['sheets/spreadsheets']
    allSpreadsheets.value = (response || []).filter(
      ss => ss.email === currentUser.value?.email
    )
  } catch (err) {
    console.error("Failed to fetch spreadsheets:", err)
    window.$toast.error("Failed to load spreadsheets")
  }
}

async function copySheetToSpreadsheet() {
  if (!selectedSpreadsheetToCopy.value) {
    return window.$toast.error("Please select a spreadsheet")
  }

  try {
    loading.value = true
    const sheetId = sheet.value.properties.sheet_id

    await store.dispatch('sheets/copySheetToSpreadsheet', {
      sourceSpreadsheetId: spreadsheetId,
      sheetId,
      destinationSpreadsheetId: selectedSpreadsheetToCopy.value
    })

    window.$toast.success("Sheet copied successfully!")
    copying.value = false
    showActions.value = false
  } catch (err) {
    console.error(err)
    showActions.value = false
    window.$toast.error("Failed to copy sheet")
  } finally {
    loading.value = false
    showActions.value = false
  }
}

async function openPasteModal() {
  pasting.value = true
  selectedSpreadsheetToCopy.value = false
  showActions.value = false
  spreadsheetSelected.value = false
  try {
    const response = store.getters['sheets/spreadsheets']
    allSpreadsheets.value = (response || []).filter(
      ss => ss.email === currentUser.value?.email
    )
  } catch (err) {
    console.error("Failed to fetch spreadsheets:", err)
    window.$toast.error("Failed to load spreadsheets")
  }
}

async function loadSheets() {
  if (!selectedSpreadsheetToCopy.value) return
  loading.value = true
  spreadsheetSelected.value = true
  try {
    await store.dispatch('sheets/fetchSpreadsheet', selectedSpreadsheetToCopy.value)
    sourceSheets.value = store.getters['sheets/selectedSpreadsheet']?.sheets || []
  } catch (err) {
    console.error('Failed to load source sheets:', err)
  } finally {
    loading.value = false
  }
}

async function copySelectedRangeToTarget() {
  if (!selectedSpreadsheetToCopy.value) {
    return window.$toast.error("Please select a destination spreadsheet")
  }
  if (!selectedSheetToCopy.value) {
    return window.$toast.error("Please select a destination sheet")
  }

  const { startRow, endRow, startCol, endCol } = selectedRange.value

  if (
    startRow == null || endRow == null ||
    startCol == null || endCol == null
  ) {
    return window.$toast.error("Please specify a valid range")
  }

  try {
    loading.value = true

    await store.dispatch('sheets/fetchSpreadsheet', selectedSpreadsheetToCopy.value)
    const destSpreadsheet = store.getters['sheets/selectedSpreadsheet']
    const destSheet = destSpreadsheet.sheets.find(s => s.title === selectedSheetToCopy.value)

    if (!destSheet) return window.$toast.error("Destination sheet not found")

    const destData = destSheet.data?.[0]?.row_data || []

    let lastRowIndex = destData.length
    for (let i = destData.length - 1; i >= 0; i--) {
      if (destData[i].values && destData[i].values.some(cell => cell.formatted_value)) {
        lastRowIndex = i + 1
        break
      }
    }

    const sourceData = sheet.value.data?.[0]?.row_data || []
    const rowsToCopy = []
    for (let r = startRow; r <= endRow; r++) {
      const row = sourceData[r]
      if (!row) continue
      const newRow = row.values.slice(startCol, endCol + 1).map(cell => cell?.formatted_value || "")
      rowsToCopy.push(newRow)
    }

    await store.dispatch('sheets/appendRows', {
      spreadsheetId: selectedSpreadsheetToCopy.value,
      sheet_name: selectedSheetToCopy.value,
      startRow: lastRowIndex,
      rows: rowsToCopy
    })

    window.$toast.success("Range copied successfully!")
    pasting.value = false

  } catch (err) {
    console.error(err)
    window.$toast.error("Failed to copy range")
  } finally {
    loading.value = false
  }
}

function toggleSort(colIndex) {
  if (merges.value.length > 0) {
  window.$toast.error("Sorting is disabled when merged cells exist.")
  return
  }

  if (sortColumnIndex.value === colIndex) {
    sortAsc.value = !sortAsc.value   
  } else {
    sortColumnIndex.value = colIndex
    sortAsc.value = true
  }
}

async function openSortModal() {
  sorting.value = true
  showActions.value = false
  filterText.value = ''
}

function reset(){
  sortColumnIndex.value = null
  sortAsc.value = true
  filterText.value = ''
}

function close(){
  sortColumnIndex.value = null
  sortAsc.value = true
  sorting.value = false
  filterText.value = ''
}

onMounted(async () => {
  try {
    const sheetName = route.params.sheetName
    loading.value = true
    error.value = null
    await store.dispatch('sheets/fetchSheetPreview', { spreadsheetId, sheetName })
    sheetData.value = store.getters['sheets/selectedSheetData']
    await store.dispatch('sheets/fetchSpreadsheets')
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape'){
      if (showActions.value) { showActions.value = false }
    }})


  } catch (e) {
    error.value = 'Failed to load sheet preview.'
    console.error(e)
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
.name {
  display: flex;
  align-items: center;

}
.sheet-name {
  margin-bottom: 0.7rem;
}

.sheet-meta {
  border: 3px dotted #555;
  padding: 10px;
  border-radius: 10px;
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

.delete-modal {
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

.delete-box {
  display: flex;
  flex-direction: column;
  background-color: rgb(109, 109, 109);
  padding: 1rem 3rem;
  border-radius: 10px;
  font-size: 1.2rem;
  font-weight: bold;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}

.del-btn {
  padding: 5px;
}
.compare-modal {
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

.compare-box {
  display: flex;
  flex-direction: column;
  background-color: rgb(109, 109, 109);
  padding: 1rem 3rem;
  border-radius: 10px;
  font-size: 1.2rem;
  font-weight: bold;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}
.compare-box select {
  padding: 10px;
  border-radius: 5px;
  font-family:monospace;
}

.cmp-btn {
  padding: 5px;
}

.paste-modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 9998;
}

.paste-box {
  display: flex;
  flex-direction: column;
  background-color: rgb(109, 109, 109);
  padding: 1rem 3rem;
  border-radius: 10px;
  font-size: 1.2rem;
  font-weight: bold;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}
.paste-box select {
  padding: 10px;
  border-radius: 5px;
  font-family:monospace;
}

.sheet-box select {
  min-width: 500px;
}

.sheet-controls {
  margin-top: 20px;
}

.sheet-controls input{
  padding: 10px;
  border-radius: 10px;
  margin-bottom: 10px;
}

.sheet-controls label {
  font-size: 18px;
}

.range-selector input {
  padding: 5px;
  border-radius: 5px;
}

.pst-btn {
  align-content: center;
  margin: 0 auto;
  margin-top: 20px;
}

.copy-modal {
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

.copy-box {
  display: flex;
  flex-direction: column;
  background-color: rgb(109, 109, 109);
  padding: 1rem 3rem;
  border-radius: 10px;
  font-size: 1.2rem;
  font-weight: bold;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}
.copy-box select {
  padding: 10px;
  border-radius: 5px;
  font-family:monospace;
}

.cpy-btn {
  padding: 5px;
}

.duplicate-modal {
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

.duplicate-box {
  display: flex;
  flex-direction: column;
  background-color: rgb(109, 109, 109);
  padding: 1rem 3rem;
  border-radius: 10px;
  font-size: 1.2rem;
  font-weight: bold;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}
.duplicate-box input {
  padding: 10px;
  border-radius: 5px;
  font-family:monospace;
}

.dup-btn {
  padding: 5px;
}

.rename-modal {
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

.rename-box {
  display: flex;
  flex-direction: column;
  background-color: rgb(109, 109, 109);
  padding: 1rem 3rem;
  border-radius: 10px;
  font-size: 1.2rem;
  font-weight: bold;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}
.rename-box input {
  padding: 10px;
  border-radius: 5px;
  font-family:monospace;
}

.rnm-btn {
  padding: 5px;
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
  background-color: white;
}

.sheet-preview td {
  border: 1px solid #cbd5e0;
  height: 40px;
  padding: 0.4rem;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sheet-preview th {
  border: 1px solid #cbd5e0;
  height: 40px;
  padding: 0.4rem;
  overflow: hidden;
  text-overflow: ellipsis;
  color: #333;
}

.back-btn {
  position: absolute;
  top: 40%;
  left: 9%;
}

.edit-btn {
  position: absolute;
  top: 37%;
  right: 9%;
}

.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-box {
  background: #555;
  border-radius: 12px;
  padding: 24px;
  width: 400px;
  box-shadow: 0 8px 20px rgba(0,0,0,0.2);
  text-align: center;
  animation: fadeIn 0.2s ease-in-out;
}

.modal-box h3 {
  margin-bottom: 16px;
}

.modal-input {
  width: 80%;
  padding: 5px;
  border: 1px solid #ccc;
  border-radius: 6px;
  margin-bottom: 16px;
  font-size: 14px;
}

.modal-actions {
  display: flex;
  justify-content: center;
  gap: 10px;
}

.action-dropdown {
  position: relative;
  display: inline-block;
}

.action-toggle {
  background: transparent;
  color: #fff;
  border: none;
  padding: 5px;
  border-radius: 70%;
  cursor: pointer;
}

.action-toggle:hover {
  background-color: #555;
}
.action-menu {
  position: absolute;
  top: 100%;
  right: 0;
  background: #333;
  color: #fff;
  display: flex;
  flex-direction: column;
  min-width: 120px;
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.3);
  z-index: 10;
}

.action-menu button {
  background: none;
  border: none;
  color: #fff;
  text-align: left;
  padding: 8px 12px;
  cursor: pointer;
}

.action-menu button:hover {
  background-color: #444;
}

</style>
