<script setup lang="ts">
import { RouterView } from 'vue-router'
import NavBar from './components/NavBar.vue'
</script>

<template>
  <div id="app">
    <header class="banner">
      <nav-bar />
    </header>
    <main class="content">
      <router-view />
    </main>
    <RouterLink to="/about">About</RouterLink>
    <RouterLink to="/todo">Todo</RouterLink>
    <RouterLink to="/todo/user1">Todo User 1</RouterLink>
  </div>
</template>

<style>
.content {
  width: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
  flex-direction: column;
  margin: 0 auto;
  max-width: 1440px;
}
</style>
