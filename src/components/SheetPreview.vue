<template>
  <div>
    <div class="title">
      <h1 v-if="sheetData" class="spreadsheet-title">{{ sheetData.spreadsheet_title.properties.title }} / </h1>
      <h2 class="sheet-name">{{ sheetName }}</h2>
    </div>

    <span class="back-btn">
      <router-link :to="`/sheets`">Back</router-link>
    </span>


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
              <td
                v-if="!isMergedCellHidden(rIndex, cIndex)"
                :rowspan="getMergeSpan(rIndex, cIndex).rowspan"
                :colspan="getMergeSpan(rIndex, cIndex).colspan"
                :style="getCellStyle(cell.effective_format)"
              >
                {{ getCellText(cell.user_entered_value) }}
              </td>
            </template>
          </tr>
        </tbody>
      </table>
    </div>

    

    <div v-if="error">{{ error }}</div>
  </div>
</template>

<script setup>
import { onMounted, ref, computed } from 'vue'
import { useStore } from 'vuex'
import { useRoute } from 'vue-router'

const store = useStore()
const route = useRoute()

const spreadsheetId = route.params.spreadsheetId
const sheetName = route.params.sheetName

const sheetData = ref(null)
const loading = ref(true)
const error = ref(null)

// got both rows(data) and merges 
const sheet = computed(() => sheetData.value?.spreadsheet?.sheets?.[0])

const merges = computed(() => sheet.value?.merges || [])

const rows = computed(() => {
  const rawRows = sheet.value?.data?.[0]?.row_data || []
  if (merges.value.length > 0) return rawRows
  return rawRows.filter(row => row.values && row.values.some(cell => cell.user_entered_value))
})

function getMergeSpan(r, c) {
  for (const merge of merges.value) {
    const rowStart = merge.start_row_index  ?? 0
    const rowEnd = merge.end_row_index  ?? 0
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

function getCellText(userEnteredValue) {
  if (!userEnteredValue) return ''
  return (
    userEnteredValue.string_value ??
    userEnteredValue.number_value ??
    userEnteredValue.bool_value ??
    ''
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
    color: text.foreground_color ? `rgb(${bgColor(text.foreground_color)})`: '#000',
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

onMounted(async () => {
  try {
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
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
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
</style>
