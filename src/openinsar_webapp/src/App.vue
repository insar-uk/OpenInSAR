<script setup lang="ts">
import { RouterLink, RouterView } from "vue-router";
import NavBar from "./components/NavBar.vue";
</script>

<template>
  <div id="app">
    <header class="banner">
      <nav-bar />
    </header>
    <main class="content">
      <router-view />
    </main>
   
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
