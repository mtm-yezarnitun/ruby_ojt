import { createRouter, createWebHistory } from 'vue-router'
import store from '../stores/store'
import Counter from '../views/CounterPage.vue'
import TodoList from '../views/TodoListPage.vue'
import Calculator from '../views/CalculatorPage.vue'
import Shop from '../views/ShopPage.vue'
import Rating from '../views/RatingPage.vue'
import Weather from '../views/WeatherPage.vue'
import Dashboard from '../views/Dashboard.vue'
import Blog from '../views/BlogPage.vue'
import Post from '../views/PostDetails.vue'
import Login from '../views/LoginPage.vue'
import Register from '../views/RegisterPage.vue'
import User from '../views/Users.vue'
import Profile from '../views/ProfilePage.vue'
import AuthSuccess from "../views/AuthSuccess.vue";
import Calendar from "../views/CalendarPage.vue";
import Sheets from "../views/SheetsPage.vue";
import SheetPreview from "../views/SheetPreviewPage.vue";
import SheetEditPage from "../views/SheetEditPage.vue";
import AdminAnnouncements from "../views/AdminAnnouncements.vue";

const routes = [
  { path: '/', redirect: '/login' },
  
  { path: '/counter', component: Counter },
  { path: '/todos', component: TodoList },
  { path: '/calculator', component: Calculator },

  { path: '/shop', component: Shop },
  { path: '/rating', component: Rating },

  { path: '/weather', component: Weather },

  { path: '/dashboard', component: Dashboard },

  { path: "/blog", component: Blog },
  { path: "/blog/:id", component: Post },

  { path: "/login", component: Login },
  { path: "/register", component: Register },
  
  { path: "/admin/users", component: User },
  { path: "/profile", component: Profile },
  { path: "/auth/success", component: AuthSuccess },

  { path: "/calendar", component: Calendar },

  { path: "/sheets", component: Sheets },
  { path: "/preview/:spreadsheetId/:sheetName", component: SheetPreview , props: true },
  { path: "/sheets/:spreadsheetId/sheet/:sheetName/edit", component: SheetEditPage, props: true },

  { path: "/announcements", component: AdminAnnouncements }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to, from,next) => {
  const publicPages = ['/login', '/register', '/auth/success']
  const authRequired = !publicPages.includes(to.path)

  const loggedIn = store.getters['auth/isAuthenticated'] || localStorage.getItem('token')
  const userExists = store.getters['auth/user'] || localStorage.getItem('user')

  if ((to.path === '/' || to.path === '/login' || to.path === '/register') && loggedIn && userExists) {
    return next('/dashboard')
  }

  if (authRequired && !loggedIn) {
    return next('/login')
  }

  next()
})

export default router
