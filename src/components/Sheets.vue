<template>
  <div>
    <div class="spreadsheet-btn">
      <button v-if="!selectedSpreadsheet" @click="openCreateDialog" class="btn-create">+ Create New Spreadsheet</button>

      <button v-if="selectedSpreadsheet" @click="clearSelection" class="btn-clear"> Clear Selection</button>

      <button v-if="selectedSpreadsheet" @click="openAddDialog" class="btn-create">+ Add New Sheet</button>
    </div>
    
    <div v-if="creating" class="modal-overlay">
      <div class="modal-box">
        <h3>Create New Spreadsheet</h3>

        <input
          v-model="newTitle"
          type="text"
          placeholder="Enter spreadsheet name"
          class="modal-input"
          @keyup.enter="createSpreadsheet"
        />
        <div class="modal-actions">
          <button @click="createSpreadsheet" class="btn-primary">Create</button>
          <button @click="cancelCreate" class="btn-secondary">Cancel</button>
        </div>
      </div>
    </div>

    <div v-if="adding" class="modal-overlay">
      <div class="modal-box">
        <h3>Create New Sheet</h3>
        <input
          v-model="newSheet"
          type="text"
          placeholder="Enter Sheet name"
          class="modal-input"
          @keyup.enter="addNewSheet"
        />
        <div class="modal-actions">
          <button @click="addNewSheet" class="btn-primary">Add</button>
          <button @click="cancelAdd" class="btn-secondary">Cancel</button>
        </div>
      </div>
    </div>

    <div v-if="selectedSpreadsheet" class="selected-sheet">
      <h2 class="spreadsheet-title">{{ selectedSpreadsheet.spreadsheet_title }}</h2>
      <p v-if="selectedSpreadsheet.link" class="sheet-link">
        <a :href="selectedSpreadsheet.link" target="_blank" rel="noopener noreferrer">
            Open in Google Sheets
        </a>
      </p>
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
        <button
          v-if="sheet.email === currentUser.email"
          class="btn-delete"
          @click.stop="confirmDelete(sheet)"
        >
        🗑️ Delete
      </button>
      </div>
    </div>

    <div v-if="deleting" class="modal-overlay">
      <div class="modal-box">
        <h3>Confirm Delete</h3>
        <p>Are you sure you want to delete "{{ deleting.name }}"?</p>
        <div class="modal-actions">
          <button @click="deleteSpreadsheet(deleting)" class="btn-primary">Delete</button>
          <button @click="cancelDelete" class="btn-secondary">Cancel</button>
        </div>
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
import { ref,computed, onMounted } from 'vue'
import { useStore } from 'vuex'
import { useRouter } from 'vue-router'

const store = useStore()
const router = useRouter()

const spreadsheets = computed(() => store.getters['sheets/spreadsheets'])
const selectedSpreadsheet = computed(() => store.getters['sheets/selectedSpreadsheet'])
const loading = computed(() => store.getters['sheets/loading'])
const error = computed(() => store.getters['sheets/error'])
const creating = ref(false)
const newTitle = ref('')
const adding = ref(false)
const newSheet = ref('')
const deleting = ref(null)

const currentUser = computed(() => store.getters['auth/user'])

const selectSpreadsheet = (id) => {
  store.dispatch('sheets/clearSelectedSpreadsheet');
  store.dispatch('sheets/clearSelectedSheetData');
  store.dispatch('sheets/fetchSpreadsheet', id)
}

const selectSheet = (sheetName) => {
  const spreadsheetId = selectedSpreadsheet.value.id
  router.push({ path: `/preview/${spreadsheetId}/${sheetName}` })
}

function openCreateDialog() {
  creating.value = true
}

function openAddDialog() {
  adding.value = true
}

function cancelAdd() {
  adding.value = false
  newSheet.value = ''
}

function cancelCreate() {
  creating.value = false
  newTitle.value = ''
}

function clearSelection() {
  store.dispatch('sheets/clearSelectedSpreadsheet');
  store.dispatch('sheets/fetchSpreadsheets')
}

async function createSpreadsheet() {
  if (!newTitle.value.trim()) {
    window.$toast.error("Please enter a spreadsheet name!")
    return
  }

  try {
    const res = await store.dispatch('sheets/createNewSpreadsheet', newTitle.value)
    window.$toast.success(`Spreadsheet "${res.spreadsheet.properties.title}" created!`)
    creating.value = false
    newTitle.value = ''
    store.dispatch('sheets/fetchSpreadsheets')
  } catch (err) {
    console.error(err)
    window.$toast.error("Failed to create spreadsheet.")
  }
}

function confirmDelete(sheet) {
  deleting.value = sheet
}

function cancelDelete() {
  deleting.value = null
}

async function deleteSpreadsheet(sheet) {
  try {
    await store.dispatch('sheets/deleteSpreadsheet', sheet.id)
    window.$toast.success("Spreadsheet deleted successfully!")
    deleting.value = null;
    clearSelection();
    store.dispatch('sheets/fetchSpreadsheets')
  } catch (err) {
    console.error(err)
    window.$toast.error("Failed to delete spreadsheet.")
  }
}

async function addNewSheet() {
  if (!newSheet.value.trim()) {
    window.$toast.error("Please enter a sheet name!")
    return
  }
  try {
    await store.dispatch('sheets/addNewSheet', { spreadsheetId: selectedSpreadsheet.value.id, title: newSheet.value });
    window.$toast.success(`Sheet added successfully!`)
    adding.value = false
    newSheet.value = ''
    store.dispatch('sheets/fetchSpreadsheets');
    selectSpreadsheet(selectedSpreadsheet.value.id);
  } catch (err) {
    console.error(err)
    window.$toast.error("Failed to add sheet.")
  }
}

onMounted(() => {
  store.dispatch('sheets/fetchSpreadsheets') 
  store.dispatch('sheets/clearSelectedSpreadsheet');
  store.dispatch('sheets/clearSelectedSheetData');
})
</script>

<style scoped>
.title {
  font-size: 1.8rem;
  margin-bottom: 1rem;
  font-weight: bold;
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

.sheet-link a{
  padding: 0;
  margin: 0 auto;
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

.btn-create {
  background: #0b8043;
  color: white;
  border: none;
  padding: 8px 12px;
  border-radius: 6px;
  cursor: pointer;
  margin-bottom: 10px;
}

.spreadsheets-grid {
  display: flex;
  min-width: 1216px;
  flex-wrap: wrap;
  gap: 1rem;
}

.selected-sheet {
  padding: 1rem;
  border: 3px solid #555;
  border-radius: 5px;
  margin-bottom: 10px;
}

.spreadsheet-title {
  font-size: 2rem;
  font-weight: bold;
  margin: 0 auto;
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

.spreadsheet-btn {
  position: relative;
}

.btn-create {
  position: absolute;
  left: 0%;
  top: -70px;
}

.btn-clear {
  position: absolute;
  right: 0%;
  top: -70px;
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
