<script setup lang="ts">
import { RouterLink, RouterView } from "vue-router";
</script>

<template>
  <div id="app">
    <main class="content">
      <div>Hello World</div>
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
