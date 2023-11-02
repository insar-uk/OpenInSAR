<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const dynaHtml = ref('');

onMounted(() => {
  loadHtml();
});

const loadHtml = () => {
  const htmlPath = '/' + route.params.htmlFile + '.html';
  fetch(htmlPath)
    .then(response => response.text())
    .then(data => {
      dynaHtml.value = data;
    })
    .catch(error => {
      console.error('Error:', error);
    });
};
</script>

<template>
  <div v-html="dynaHtml" id="dyna_html"></div>
</template>
