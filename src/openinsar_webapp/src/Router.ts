import { createRouter, createWebHistory, RouteRecordRaw } from 'vue-router';

// Import your Vue components

// Get the base URL from the environment variable
const BASE_URL = 'app';

// Define your routes
const routes: Array<RouteRecordRaw> = [



];

// Create the router instance
const router = createRouter({
  history: createWebHistory(),
  routes,
});

export default router;
