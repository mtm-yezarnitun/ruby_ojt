<template>
  <div class="edit-container">
    <h1>Edit {{ sheetName }}</h1>
    <button @click="addRow" class="btn-add">+ Add Row</button>
    <button @click="addColumn" class="btn-add">+ Add Column</button>

    <div class="action-buttons">
      <button @click="saveChanges" class="btn-save">Save</button>
      <router-link :to="`/preview/${spreadsheetId}/${sheetName}`" class="btn-cancel">Cancel</router-link>
    </div>
    
    <div class="table-wrapper">
      <table class="editable-table">
        <thead>
          <tr>
            <th>
              -
            </th>
            <th>
              -
            </th>
            <th v-for="(col, cIndex) in editableRows[0]" :key="'header-' + cIndex">
              <button @click="removeColumn(cIndex)" class="btn-remove">🗑️</button>
            </th>
            <th class="actions"></th> 
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, rIndex) in editableRows" :key="rIndex">
]
            <td class="actions">
              <button @click="removeRow(rIndex)" class="btn-remove">🗑️</button> 
            </td>

            <template v-for="(cell, cIndex) in row" :key="cIndex">

              <td v-if="!isMergedCellHidden(rIndex, cIndex)" :rowspan="getMergeSpan(rIndex, cIndex).rowspan"
                :colspan="getMergeSpan(rIndex, cIndex).colspan">
                <input v-model="editableRows[rIndex][cIndex]" :style="{
                  width: '100%',
                  border: 'none',
                  background: 'transparent',
                  color: 'black',
                  fontSize: '10px',
                }" />
              </td>
            </template>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="loading" class="loading-modal">
      <div class="loading-box">
        <div class="spinner"></div>
        <p>Loading sheet data...</p>
      </div>
    </div>

    <div v-if="error">{{ error }}
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useStore } from 'vuex'
import { useRoute, useRouter } from 'vue-router'

const store = useStore()
const route = useRoute()
const router = useRouter()

const spreadsheetId = route.params.spreadsheetId
const sheetName = route.params.sheetName

const sheetData = ref(null)
const editableRows = ref([])
const loading = ref(true)
const error = ref(null)

const sheet = computed(() => sheetData.value?.spreadsheet?.sheets?.[0])
const merges = computed(() => sheet.value?.merges || [])
const rows = computed(() => sheet.value?.data?.[0]?.row_data || [])

function getMergeSpan(r, c) {
  for (const merge of merges.value) {
    const rowStart = merge.start_row_index ?? 0
    const rowEnd = merge.end_row_index ?? 0
    const colStart = merge.start_column_index ?? 0
    const colEnd = merge.end_column_index ?? 0
    if (r === rowStart && c === colStart) return { rowspan: rowEnd - rowStart || 1, colspan: colEnd - colStart || 1 }
  }
  return { rowspan: 1, colspan: 1 }
}

function isMergedCellHidden(r, c) {
  for (const merge of merges.value) {
    const rowStart = merge.start_row_index ?? 0
    const rowEnd = merge.end_row_index ?? 0
    const colStart = merge.start_column_index ?? 0
    const colEnd = merge.end_column_index ?? 0
    if (r >= rowStart && r < rowEnd && c >= colStart && c < colEnd && !(r === rowStart && c === colStart)) return true
  }
  return false
}

function addRow() {
  const columns = editableRows.value[0]?.length || 1
  editableRows.value.push(Array(columns).fill(''))
  rows.value.push({ values: Array(columns).fill({}) })
}

function addColumn() {
  editableRows.value.forEach(row => {
    row.push('')
  })
  rows.value.forEach(r => {
    if (!r.values) r.values = []
    r.values.push({})
  })
}

function removeRow(index) {
  editableRows.value.splice(index, 1)
  rows.value.splice(index, 1)
}

function removeColumn(index) {
  editableRows.value.forEach(row => {
    if (row.length > index) {
      row.splice(index, 1)
    }
  })
  rows.value.forEach(r => {
    if (r.values && r.values.length > index) {
      r.values.splice(index, 1)
    }
  })
}

async function saveChanges() {
  const updates = editableRows.value.map((row, rIndex) => ({
    range: `${sheetName}!A${rIndex + 1}`,
    values: [row]
  }))

  try {
    await store.dispatch('sheets/updateSheet', { spreadsheetId, sheetName, updates })
    window.$toast.success("Sheet Updated Successfully!")
    router.push({ path: `/preview/${spreadsheetId}/${sheetName}` })
  } catch (err) {
    window.$toast.error("Can't Update Sheet!")
    console.error(err)
  }
}

onMounted(async () => {
  loading.value = true
  try {
    await store.dispatch('sheets/fetchSheetPreview', { spreadsheetId, sheetName })
    sheetData.value = store.getters['sheets/selectedSheetData']
    editableRows.value = rows.value.map(r =>
      (r.values || []).map(c => c.formatted_value ?? '')
    )
    if (editableRows.value.length === 0) editableRows.value = [['']]
    if (editableRows.value[0].length === 0) editableRows.value[0] = ['']

  } catch (err) {
    console.error(err)
    error.value = "Failed to load sheet."
  } finally {
    loading.value = false
  }
})

</script>

<style scoped>
.edit-container {
  padding: 20px;
  max-width: 1440px;
  overflow-x: auto;
}

.table-wrapper {
  overflow-x: auto;
  max-width: 100%;
  margin: 20px 0;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
}

.editable-table {
  min-width: 1400px;
  border-collapse: collapse;
  background: white;
}

.editable-table td {
  border: 1px solid #e0e0e0;
  padding: 8px;
  min-width: 120px;
  max-width: 200px;
}

.cell-input {
  color: #555;
  width: 100%;
  border: none;
  outline: none;
  padding: 6px;
  font-size: 14px;
  background: transparent;
}

.actions {
  width: 60px;
  min-width: 60px;
}

.btn-add {
  background: #1976d2;
  color: white;
  border: none;
  padding: 10px 16px;
  border-radius: 4px;
  cursor: pointer;
  margin-bottom: 16px;
}

.btn-remove {
  background: transparent;
  color: white;
  border: none;
  padding: 6px;
  border-radius: 4px;
  cursor: pointer;
  width: 32px;
  height: 32px;
}

.btn-save {
  background: #4caf50;
  color: white;
  border: none;
  padding: 12px 24px;
  border-radius: 4px;
  cursor: pointer;
  margin-right: 12px;
}

.btn-cancel {
  background: #9e9e9e;
  color: white;
  padding: 12px 24px;
  border-radius: 4px;
  text-decoration: none;
  display: inline-block;
}

.action-buttons {
  margin-top: 20px;
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

.back-btn {
  position: absolute;
  top: 51%;
  left: 9%;
}


.btn-add:hover {
  background: #1565c0;
}

.btn-remove:hover {
  background: #d32f2f;
}

.btn-save:hover {
  background: #45a049;
}

.btn-cancel:hover {
  background: #757575;
}
</style>

