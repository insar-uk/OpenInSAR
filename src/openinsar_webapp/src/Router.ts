import { createRouter, createWebHistory } from 'vue-router'
import Todo from './components/Todo.vue'
import NotFound from './components/NotFound.vue'
import Home from './components/HomePage.vue'
import HtmlLoader from './components/HtmlLoader.vue'

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
    path: '/html/:htmlFile',
    component: HtmlLoader
  },
  {
    path: '/*',
    name: 'NotFoundB',
    component: NotFound
  },
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
