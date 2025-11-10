<template>
  <div>
    <div class="title">
      <h1 v-if="sheetData" class="spreadsheet-title">{{ sheetData.spreadsheet_title.properties.title }} / </h1>
      <h2 class="sheet-name">{{ sheetName }}</h2>
    </div>

    <span class="back-btn">
      <router-link :to="`/sheets`">Back</router-link>
    </span>

    <span class="edit-btn">
      <router-link :to="`/sheets/${spreadsheetId}/sheet/${sheetName}/edit`" class="edit-btn"> Edit</router-link>
    </span>

    <span class="rename-btn" v-if="isOwner">
        <button
          class="btn-rename"
          @click="renameBox()"  
        >Rename
      </button>
    </span>

    <span class="del-btn" v-if="isOwner">
        <button
          class="btn-delete"
          @click="deleteSheet()"  
        >Delete
      </button>
    </span>

    <div v-if="renaming" class="rename-modal">
      <div class="rename-box">
        <p>Enter your new Title:</p>
        <input type="text" v-model="newTtl" placeholder="New sheet title" />
        <button @click="renameSheet" class="rnm-btn">Save</button>
        <button @click="renaming = false" class="rnm-btn">Cancel</button>
      </div>
    </div>

    <span class="copy-btn" v-if="isOwner">
      <button class="btn-copy" @click="duplicateBox()">Duplicate</button>
    </span>

    <div v-if="duplicating" class="duplicate-modal">
      <div class="duplicate-box">
        <p>Enter a name for the duplicated sheet:</p>
        <input type="text" v-model="duplicateTitle" placeholder="New sheet title" />
        <button @click="duplicateSheetAction" class="dup-btn">Duplicate</button>
        <button @click="duplicating = false" class="dup-btn">Cancel</button>
      </div>
    </div>

    <div v-if="loading" class="loading-modal">
      <div class="loading-box">
        <div class="spinner"></div>
        <p>Loading sheet data...</p>
      </div>
    </div>

    <div v-if="sheetData" class="sheet-preview">
      <table>
        <tbody>
          <tr v-for="(row, rIndex) in rows" :key="rIndex">
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

const currentUser = computed(() => store.getters['auth/user'])
const sheet = computed(() => sheetData.value?.spreadsheet?.sheets?.[0])

const merges = computed(() => sheet.value?.merges || [])
const isOwner = computed(() => {
  return sheetData.value?.owner === currentUser.value?.email
})

const rows = computed(() => {
  const rawRows = sheet.value?.data?.[0]?.row_data || []
  if (merges.value.length > 0) return rawRows
  return rawRows.filter(row => row.values && row.values.some(cell => cell.formatted_value))
})

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

  } catch (err) {
    console.error(err);
    return window.$toast.error(`Cannot Delete Sheet!`);

  } finally {
    loading.value = false;
  }
}

function renameBox() {
  renaming.value = true
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

  } catch (err) {
    console.error(err)
    window.$toast.error('Failed to rename sheet.')
  } finally {
    loading.value = false
    newTtl.value = null
  }
}

function duplicateBox() {
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
    await store.dispatch('sheets/fetchSpreadsheet', spreadsheetId)
    window.$toast.success(`Sheet duplicated as "${duplicateTitle.value}"`)
    router.push({ path: `/sheets` })
  } catch (err) {
    console.error(err)
    window.$toast.error('Failed to duplicate sheet.')
  } finally {
    loading.value = false
    duplicateTitle.value = ''
  }
}

onMounted(async () => {
  try {
    const sheetName = route.params.sheetName
    loading.value = true
    error.value = null
    await store.dispatch('sheets/fetchSheetPreview', { spreadsheetId, sheetName })
    sheetData.value = store.getters['sheets/selectedSheetData']

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

.sheet-name {
  margin-bottom: 0.7rem;
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

.back-btn {
  position: absolute;
  top: 32%;
  left: 9%;
}

.edit-btn {
  position: absolute;
  top: 30%;
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
</style>
