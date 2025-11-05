<template>
  <div class="dashboard">
    <h1>▣ Dashboard</h1>

    <section class="todos-preview" v-if="upcomingTodos.length">
      <h2>Upcoming Todos</h2>
      <ul>
        <li v-for="todo in upcomingTodos" :key="todo.title + todo.date">
          📌 {{ todo.title }} – {{ todo.task }} (Due: {{ todo.date }})
        </li>
      </ul>
      <router-link to="/todos" class="see-all">See All →</router-link>
    </section>

    <section class="cards">
      <router-link to="/blog" class="card">Blog</router-link>
      <router-link to="/todos" class="card">Todo List</router-link>
      <router-link to="/weather" class="card">Weather</router-link>
      <router-link to="/shop" class="card">Shop</router-link>
      <router-link to="/rating" class="card">Rating</router-link>
      <router-link to="/calculator" class="card">Calculator</router-link>
      <router-link to="/counter" class="card">Counter</router-link>
      <router-link v-if="user.role == 'admin'" to="/announcements" class="card">Announcements</router-link>
      <router-link v-if="user.provider == 'google_oauth2'  && user.google_refresh_token" to="/calendar" class="card">Calendar</router-link>
      <router-link v-if="user.provider == 'google_oauth2'  && user.google_refresh_token" to="/sheets" class="card">Sheets</router-link>
    </section>
  </div>
</template>

<script setup>
import { computed, onMounted } from "vue"
import { useStore } from 'vuex'

const store = useStore()
const user = computed(() => store.getters["auth/user"]);
const minDate = new Date().toISOString().split("T")[0]

const todos = computed(() => store.getters['todo/todos'])

const upcomingTodos = computed(() =>
  todos.value.filter(todo => todo.date >= minDate)
)

</script>

<style scoped>
.dashboard {
  padding: 2rem;
  text-align: center;
}

.todos-preview {
  margin-bottom: 2rem;
  display: flex;
  flex-direction: column;
}

.todos-preview ul {
  list-style: none;
  padding: 0;
}

.todos-preview li {
  padding: 0.5rem 0;
  font-size: 1.1rem;
}

.todos-preview .done {
  text-decoration: line-through;
  color: gray;
}

.see-all {
  display: inline-block;
  margin-top: 0.5rem;
  font-size: 0.9rem;
  color: #43e192;
}

.cards {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
  margin-top: 2rem;
}

.card {
  background: #1e1e1e;
  color: #fff;
  padding: 1.5rem;
  border-radius: 12px;
  text-decoration: none;
  font-weight: bold;
  transition: transform 0.2s, background 0.3s;
}

.card:hover {
  background: #43e192;
  color: #f1ebeb !important;
  transform: translateY(-5px);
}
</style>
