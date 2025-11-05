<template>
  <h1>🖔 Login</h1>
  <form @submit.prevent="login" class="login-form">
    <input v-model="email" placeholder="Email" />
    <input type="password" v-model="password" placeholder="Password" />
    <button type="submit">Login</button>
  </form>

  <button class="redirectBtn" @click="loginGoogle">Sign in with Google ( API )</button>

  <button class="redirectBtn" @click="loginWithGoogle">Pop with Google ( Access Token Only )</button>


  <router-link to="/register">Register</router-link>
</template>

<script setup>
import { ref } from "vue";
import { useStore } from "vuex";
import { useRouter } from "vue-router";
import axios from "axios";

const router = useRouter();
const store = useStore();
const email = ref("");
const password = ref("");

let tokenClient;

function loginWithGoogle() {
  if (!tokenClient) {
    tokenClient = google.accounts.oauth2.initTokenClient({
      client_id: import.meta.env.VITE_GOOGLE_CLIENT_ID,
      scope: "openid email profile https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/spreadsheets.readonly https://www.googleapis.com/auth/drive.metadata.readonly",
      prompt: "consent",
      callback: async (tokenResponse) => {
        if (!tokenResponse.access_token) {
          console.error("No access token received");
          return;
        }

        try {
          const res = await axios.post("http://localhost:3000/api/v1/google_login", {
            access_token: tokenResponse.access_token
          });

          store.commit("auth/setToken", res.data.token);

          const profile = await axios.get("http://localhost:3000/api/v1/profile", {
            headers: { Authorization: `Bearer ${res.data.token}` }
          });
          store.commit("auth/setUser", profile.data);

          window.$toast.success("Google Account Logged in successfully!");
          router.push("/dashboard");
        } catch (err) {
          console.error("Google login failed", err.response?.data || err);
        }
      },
    });
  }

  tokenClient.requestAccessToken();
}

function loginGoogle() {
  window.location.href = `http://localhost:3000/api/v1/google_login`
}

function login() {
  store.dispatch("auth/login", { email: email.value, password: password.value, router });
  email.value = "";
  password.value = "";
}

</script>

<style scoped>
.login-form {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 15px;
  border-radius: 8px;
  margin-bottom: 20px;
  align-items: center;
}

.login-form input {
  width: 100%;
  padding: 8px;
  border: 1px solid #43e192;
  border-radius: 4px;
  font-size: 14px;
  font-family: monospace;
}

.login-form button {
  width: 100px;
  padding: 8px;
  background-color: #43e192;
  border: 1px solid black;
  color: white;
  border-radius: 4px;
  cursor: pointer;
}

.login-form button:hover {
  background-color: #1e1e1e;
  border: 1px solid #43e192;
}

.redirectBtn ,
#googleBtn {
  margin-bottom: 20px;
}
</style>
