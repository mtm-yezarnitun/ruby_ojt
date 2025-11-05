<template>
  <div class="navbar">
    <nav v-if="$route.path !== '/dashboard' && $route.path !== '/login' && $route.path !== '/register'">
      <ul>
        <li>
          <router-link to="/dashboard">▣</router-link>
        </li>
        <li>
          <router-link to="/blog">Blog</router-link>
        </li>
        <li>
          <router-link to="/todos">Todo</router-link>
        </li>
        <li>
          <router-link to="/weather">Weather</router-link>
        </li>
        <li>
          <router-link to="/shop">Shop</router-link>
        </li>
        <li>
          <router-link to="/rating">Rating</router-link>
        </li>
        <li>
          <router-link to="/calculator">Calculator</router-link>
        </li>
        <li>
          <router-link to="/counter">Counter</router-link>
        </li>
        <li v-if="user && user.provider === 'google_oauth2'  && user.google_refresh_token">
          <router-link to="/calendar">Calendar</router-link>
        </li>
        <li v-if="user && user.provider === 'google_oauth2'  && user.google_refresh_token">
          <router-link to="/sheets">Sheets</router-link>
        </li>
        <li v-if="user && user.role =='admin'">
          <router-link to="/announcements">Announcements</router-link>
        </li>
      </ul>

      <div class="user-info">
        <template v-if="isAuthenticated">
          <div v-if="user">
            <div class="profile-action">
              <router-link v-if="user.role == 'admin'" to="/admin/users"> Manage </router-link>
              <router-link to="/profile">{{ user.email }}</router-link>
              <button @click="logout">Logout</button>
            </div>
          </div>
        </template>
        <template v-else>
          <span>
            <router-link to="/login">Login/Register</router-link>
          </span>
        </template>
      </div>
    </nav>

      <AnnouncementTicker  v-if="$route.path !== '/login' && $route.path !== '/register'"/>

    <router-view />
  </div>
</template>

<script setup>
import { useStore } from "vuex";
import { useToast } from 'vue-toastification'
import { computed, onMounted } from "vue";
import { useRouter } from "vue-router";
import { watch } from "vue";
import consumer from "./consumer"
import AnnouncementTicker from "./components/AnnouncementTicker.vue";

const router = useRouter();
const store = useStore();
const toast = useToast();

const user = computed(() => store.getters["auth/user"]);
const isAuthenticated = computed(() => store.getters["auth/isAuthenticated"]);

onMounted(() => {
  window.$toast = toast
})

watch(user, (newUser) => {
  if (newUser?.id) {
    consumer.subscriptions.create(
      { channel: "EventNotificationsChannel", user_id: newUser.id }, 
      {
        connected() { console.log("Connected to EventNotificationsChannel") },
        received(data) {
          console.log("Received AC message:", data);
          toast.info(data.message); 
        }
      }
    )
  }
}, { immediate: true });

function logout() {
  store.dispatch("auth/logout", {router});
}

</script>

<style>

h1 {
  color: #43e192;
}

h3 {
  color: #43e192;
  margin-right: 20px;
}
a {
  text-decoration: none;
  color: #555 !important;
  padding: 20px;
  word-wrap: break-word;
}

a:hover {
  color: grey;
}

.navbar {
  padding-top: 20px;
}

nav {
  position: absolute;
  background-color: black;
  padding: 10px;
  top: 0;
  right: 0;
  width: 100%;  
  display: flex;
  justify-content: space-between;
  align-items: center;


}
ul {
  display: flex;
  justify-content: center;
  align-items: center;
  width: 70%;
}
ul li {
  font-size: 14px;

  list-style: none;
}
router-link {
  text-decoration: none;
  font-weight: bold;
  color: #ebf1ee;
  border: 1px solid transparent;
}
.router-link-active {
  font-weight: bold;
  color: #43e192 !important;
}

.user-info {
  display: flex;
  flex-direction: column;
  width: 40%;
}

.profilee-action {
  display: flex;
  flex-direction: column;
}

</style>
