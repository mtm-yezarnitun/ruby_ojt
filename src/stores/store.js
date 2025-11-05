import { createStore } from 'vuex';
import todo from './modules/todo'
import weather from './modules/weather'
import blog from './modules/blog'
import auth from './modules/auth'
import users from './modules/users'
import profile from './modules/profile'
import calendar from './modules/calendar'
import sheets from './modules/sheets'
import announcements from './modules/announcements'

const store = createStore({
  modules: {
    todo,
    weather,
    blog,
    auth,
    users,
    profile,
    calendar,
    sheets,
    announcements
    },

});

export default store;
