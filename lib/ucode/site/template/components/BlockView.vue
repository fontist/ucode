<script setup>
import { ref, onMounted, computed } from "vue";

const props = defineProps({ block: { type: String, required: true } });

const blockMeta = ref(null);
const cpToBlock = ref({});
const labels = ref({});

const cells = computed(() => {
  if (!blockMeta.value) return [];
  return blockMeta.value.codepoint_ids.map((cpId) => ({
    id: cpId,
    label: labels.value[cpId]?.name,
    glyphUrl: `/data/blocks/${props.block}/${cpId}/glyph.svg`,
    detailUrl: `/char/${cpId.slice(2)}`,
  }));
});

onMounted(async () => {
  const [blockRes, labelsRes] = await Promise.all([
    fetch(`/data/blocks/${props.block}.json`),
    fetch(`/data/index/labels.json`),
  ]);
  blockMeta.value = await blockRes.json();
  labels.value = await labelsRes.json();
});
</script>

<template>
  <div class="block">
    <header v-if="blockMeta">
      <h1>{{ blockMeta.name }}</h1>
      <p class="lead">
        <code>{{ blockMeta.id }}</code>
        — U+{{ blockMeta.range_first.toString(16).toUpperCase().padStart(4, "0") }}
        – U+{{ blockMeta.range_last.toString(16).toUpperCase().padStart(4, "0") }}
        ({{ cells.length }} codepoints)
      </p>
    </header>

    <section class="grid">
      <a v-for="cell in cells" :key="cell.id" :href="cell.detailUrl" class="cell">
        <img :src="cell.glyphUrl" :alt="cell.label" loading="lazy" />
        <span class="cp-id">{{ cell.id }}</span>
      </a>
    </section>
  </div>
</template>

<style scoped>
.lead { color: var(--vp-c-text-2); font-family: monospace; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(96px, 1fr)); gap: 1px; background: var(--vp-c-divider); border: 1px solid var(--vp-c-divider); }
.cell { display: flex; flex-direction: column; align-items: center; padding: 0.5rem; background: var(--vp-c-bg); text-decoration: none; }
.cell img { width: 64px; height: 64px; object-fit: contain; }
.cp-id { font-family: monospace; font-size: 0.7rem; color: var(--vp-c-text-3); margin-top: 0.25rem; }
</style>
