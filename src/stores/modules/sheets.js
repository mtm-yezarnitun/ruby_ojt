import axios from "axios";

const API_URL = "http://localhost:3000";

const sheets = {
  namespaced: true,
  state() {
    return {
      spreadsheets: [],
      selectedSpreadsheet: null,
      selectedSheetData: null,
      loading: false,
      error: null
    };
  },
  mutations: {
    setSpreadsheets(state, spreadsheets) {
      state.spreadsheets = spreadsheets;
    },
    setSelectedSpreadsheet(state, spreadsheet) {
      state.selectedSpreadsheet = spreadsheet;
    },
    setLoading(state, loading) {
      state.loading = loading;
    },
    setError(state, error) {
      state.error = error;
    },
    clearError(state) {
      state.error = null;
    },
    setSelectedSheetData(state, data) {
      state.selectedSheetData = data;
    },
    clearSelectedSheetData(state) {
      state.selectedSheetData = null;
    }

  },
  actions: {
    async fetchSpreadsheets({ commit, rootGetters }) {
      commit('setLoading', true);
      commit('clearError');

      try {
        const token = rootGetters['auth/token'] || localStorage.getItem('token');
        if (!token) throw new Error("No authentication token found");

        const response = await axios.get(`${API_URL}/api/v1/sheets`, {
          headers: { 'Authorization': `Bearer ${token}` }
        });

        commit('setSpreadsheets', response.data.spreadsheets || []);
      } catch (err) {
        console.error("Failed to fetch spreadsheets: Try Login Again.", err);
        commit('setError', "Failed to fetch spreadsheets");
      } finally {
        commit('setLoading', false);
      }
    },
    async fetchSpreadsheet({ commit, rootGetters }, spreadsheetId) {
      commit('setLoading', true);
      commit('clearError');

      try {
        const token = rootGetters['auth/token'] || localStorage.getItem('token');
        if (!token) throw new Error("No authentication token found");
        const response = await axios.get(`${API_URL}/api/v1/sheets/${spreadsheetId}`, {
          headers: { 'Authorization': `Bearer ${token}` }
        });

        commit('setSelectedSpreadsheet', response.data);
      } catch (err) {
        console.error("Failed to fetch spreadsheet details:", err);
        commit('setError', "Failed to fetch spreadsheet details");
      } finally {
        commit('setLoading', false);
      }
    },
    async fetchSheetPreview({ commit, rootGetters }, { spreadsheetId, sheetName }) {
      commit('setLoading', true);
      commit('clearError');

      try {
        const token = rootGetters['auth/token'] || localStorage.getItem('token');
        if (!token) throw new Error("No authentication token found");
        const response = await axios.get(
          `${API_URL}/api/v1/sheets/${spreadsheetId}/sheet/${sheetName}/preview`,
          { headers: { Authorization: `Bearer ${token}` } }
        );
        commit('setSelectedSheetData', response.data);
      } catch (err) {
        console.error("Failed to fetch sheet preview:", err);
        commit('setError', "Failed to fetch sheet preview");
      } finally {
        commit('setLoading', false);
      }
    },
    async updateSheet({ rootGetters }, { spreadsheetId, sheetName, updates }) {
      const token = rootGetters['auth/token'] || localStorage.getItem('token');
      if (!token) throw new Error("No authentication token found");
      try {
        const response = await axios.put(
          `${API_URL}/api/v1/sheets/${spreadsheetId}/sheet/${sheetName}/update`,
          { updates },
          { headers: { Authorization: `Bearer ${token}` } }
        );
        return response.data;
      } catch (err) {
        console.error("Failed to update sheet:", err);
        throw err;
      }
    },
    async renameSheet({ rootGetters }, { spreadsheetId, sheetId, newTitle }) {
      const token = rootGetters['auth/token'] || localStorage.getItem('token');
      if (!token) throw new Error("No authentication token found");

      try {
        const response = await axios.put(
          `${API_URL}/api/v1/sheets/${spreadsheetId}/rename_sheet`,
          { sheet_id: sheetId, new_title: newTitle },
          { headers: { Authorization: `Bearer ${token}` } }
        );
        return response.data;
      } catch (err) {
        console.error("Failed to rename sheet:", err);
        throw err;
      }
    },
    async addNewSheet({ rootGetters }, { spreadsheetId, title }) {
      const token = rootGetters['auth/token'] || localStorage.getItem('token');
      if (!token) throw new Error("No authentication token found");
      try {
        const response = await axios.post(
          `${API_URL}/api/v1/sheets/${spreadsheetId}/add_sheet`,
          { title },
          { headers: { Authorization: `Bearer ${token}` } }
        );
        return response.data;
      } catch (err) {
        console.error("Failed to add new sheet:", err);
        throw err;
      }
    },
    async deleteSheet({rootGetters},[spreadsheetId,sheetId]) {
      const token = rootGetters['auth/token'] || localStorage.getItem('token')
      if (!token) throw new Error("No authentication token found");
      
      try {
        const response =  await axios.delete(`${API_URL}/api/v1/sheets/${spreadsheetId}/delete_sheet`, {
        headers: { Authorization: `Bearer ${token}` },
        params: { sheet_id: sheetId }
      })
        return response.data
      } catch (err) {
        console.error("Failed to delete Sheet:", err)
        throw err
      }
    },
    async createNewSpreadsheet({ rootGetters }, title) {
      const token = rootGetters['auth/token'] || localStorage.getItem('token');
      if (!token) throw new Error("No authentication token found");
      try {
        const response = await axios.post(
          `${API_URL}/api/v1/sheets/create_spreadsheet`,
          { title },
          { headers: { Authorization: `Bearer ${token}` } }
        );
        return response.data;
      } catch (err) {
        console.error("Failed to create spreadsheet:", err);
        throw err;
      }
    },
    async duplicateSheet({ rootGetters }, { spreadsheetId, sheetId, newTitle }) {
      const token = rootGetters['auth/token'] || localStorage.getItem('token');
      if (!token) throw new Error("No authentication token found");

      try {
        const response = await axios.post(
          `${API_URL}/api/v1/sheets/${spreadsheetId}/duplicate_sheet`,
          { sheet_id: sheetId, new_title: newTitle },
          { headers: { Authorization: `Bearer ${token}` } }
        );
        return response.data;
      } catch (err) {
        console.error("Failed to duplicate sheet:", err);
        throw err;
      }
    },
    async copySheetToSpreadsheet({ rootGetters }, { sourceSpreadsheetId, sheetId, destinationSpreadsheetId }) {
      const token = rootGetters['auth/token'] || localStorage.getItem('token')
      if (!token) throw new Error("No authentication token found")

      try {
        const response = await axios.post(
          `${API_URL}/api/v1/sheets//${sourceSpreadsheetId}/sheets/copy_sheet_to_spreadsheet`,
          { source_spreadsheet_id: sourceSpreadsheetId, sheet_id: sheetId, destination_spreadsheet_id: destinationSpreadsheetId },
          { headers: { Authorization: `Bearer ${token}` } }
        )
        return response.data
      } catch (err) {
        console.error("Failed to copy sheet across spreadsheets:", err)
        throw err
      }
    },
    async deleteSpreadsheet({ rootGetters }, spreadsheetId) {
      const token = rootGetters['auth/token'] || localStorage.getItem('token')
      if (!token) throw new Error("No authentication token found");
      try {
        const response = await axios.delete(`${API_URL}/api/v1/sheets/${spreadsheetId}`, {
          headers: { Authorization: `Bearer ${token}` }
        })
        return response.data
      } catch (err) {
        console.error("Failed to delete spreadsheet:", err)
        throw err
      }
    },  
    async appendRows({ rootGetters }, { spreadsheetId, sheet_name, startRow, rows }) {
      const token = rootGetters['auth/token'] || localStorage.getItem('token');
      if (!token) throw new Error("No authentication token found");

      try {
        const response = await axios.put(
          `${API_URL}/api/v1/sheets/${spreadsheetId}/sheet/${sheet_name}/append_rows`,
          { sheet_name, start_row: startRow, rows },
          { headers: { Authorization: `Bearer ${token}` } }
        );
        return response.data;
      } catch (err) {
        console.error("Failed to append rows:", err);
        throw err;
      }
    },
    clearSelectedSheetData({ commit }) {
      commit('clearSelectedSheetData');
    },
    clearSelectedSpreadsheet({ commit }) {
      commit('setSelectedSpreadsheet', null);
    }
  },
  getters: {
    spreadsheets: (state) => state.spreadsheets,
    selectedSpreadsheet: (state) => state.selectedSpreadsheet,
    selectedSheetData: (state) => state.selectedSheetData,
    loading: (state) => state.loading,
    hasSpreadsheets: (state) => state.spreadsheets.length > 0,
    error: (state) => state.error
  }
};

export default sheets;
