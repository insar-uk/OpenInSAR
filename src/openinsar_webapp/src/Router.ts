import { createRouter, createWebHistory } from 'vue-router'
import Todo from './components/Todo.vue'
import NotFound from './components/NotFound.vue'
import Home from './components/HomePage.vue'

// Define your routes
const routes = [
  {
    path: '/',
    name: 'Home1',
    component: Home
  },
  // Add route for todo list
  {
    path: `/todo`,
    name: 'Todo',
    component: Todo
  },
  {
    path: '/todo/:id',
    name: 'Todo2',
    component: Todo
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFoundA',
    component: NotFound
  },
  {
    path: '/*',
    name: 'NotFoundB',
    component: NotFound
  },
  // matches /o/3549
  { path: '/o/:orderId', component: Todo },
  // matches /p/books
  { path: '/p/:productName', component: Todo },
  // Add catch-all route
  {
    path: '/:catchAll(.*)',
    component: NotFound
  }
]

// Create the router instance
const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router
