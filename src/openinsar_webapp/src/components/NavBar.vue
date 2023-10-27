<script setup lang="ts">
import { RouterLink } from 'vue-router'
</script>
<template>
  <div class="nav">
    <RouterLink to="/">Home</RouterLink>
    <RouterLink to="/about">About</RouterLink>
    <RouterLink to="/sites">Project Sites</RouterLink>
    <!-- <RouterLink to="/app/map">Map</RouterLink> -->
    <RouterLink to="/define">Editor</RouterLink>
    <RouterLink to="/workers">Workers</RouterLink>
    <RouterLink to="/queue">Processing Queue</RouterLink>
    <a href="/doc/">Documentation</a>
  </div>
</template>

<style scoped>
.nav {
  font-size: 20px;
  padding: 0 0 0 50px;
}

.nav a {
  text-decoration: none;
  color: #0f0;
  padding: 5px 10px;
  transition:
    background-color 0.5s,
    color 0.5s;
  /* border: #0F0; */
  /* border-style: solid; */
  box-shadow: 0 0 5px rgba(0, 255, 0, 0.72);
}

.nav a:hover {
  background-color: #0f0;
  color: aliceblue;
}
</style>
