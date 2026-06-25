<script setup>
import { ref, onMounted, computed } from "vue";

const props = defineProps({ codepoint: { type: [String, Number], required: true } });

const cpData = ref(null);
const cpToBlock = ref({});
const error = ref(null);

const cpId = computed(() => {
  const n = Number(props.codepoint);
  return `U+${n.toString(16).toUpperCase().padStart(4, "0")}`;
});

const blockId = computed(() => cpToBlock.value[cpId.value]);
const glyphUrl = computed(() =>
  blockId.value ? `/data/blocks/${blockId.value}/${cpId.value}/glyph.svg` : null
);

onMounted(async () => {
  try {
    const [mappingRes] = await Promise.all([
      fetch(`/data/index/codepoint_to_block.json`),
    ]);
    cpToBlock.value = await mappingRes.json();
    if (!blockId.value) {
      error.value = `No block found for ${cpId.value}`;
      return;
    }
    const dataRes = await fetch(`/data/blocks/${blockId.value}/${cpId.value}/index.json`);
    if (!dataRes.ok) {
      error.value = `No data file for ${cpId.value} (HTTP ${dataRes.status})`;
      return;
    }
    cpData.value = await dataRes.json();
  } catch (e) {
    error.value = e.message;
  }
});

const propertyRows = computed(() => {
  if (!cpData.value) return [];
  return Object.entries(cpData.value)
    .filter(([_, v]) => v !== null && v !== undefined && v !== "")
    .map(([k, v]) => ({ key: k, value: JSON.stringify(v) }));
});
</script>

<template>
  <div class="char">
    <header>
      <h1><code>{{ cpId }}</code></h1>
      <p v-if="cpData" class="name">{{ cpData.name }}</p>
      <p v-if="error" class="error">{{ error }}</p>
    </header>

    <div v-if="cpData" class="body">
      <aside v-if="glyphUrl" class="glyph">
        <img :src="glyphUrl" :alt="cpData.name" />
      </aside>

      <section class="props">
        <h2>Properties</h2>
        <table>
          <tbody>
            <tr v-for="row in propertyRows" :key="row.key">
              <th>{{ row.key }}</th>
              <td><code>{{ row.value }}</code></td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  </div>
</template>

<style scoped>
.name { font-family: monospace; color: var(--vp-c-text-2); }
.error { color: var(--vp-c-danger-1); }
.body { display: grid; grid-template-columns: 200px 1fr; gap: 2rem; }
.glyph img { width: 100%; height: auto; border: 1px solid var(--vp-c-divider); background: var(--vp-c-bg-alt); }
.props table { border-collapse: collapse; }
.props th, .props td { text-align: left; padding: 0.25rem 0.75rem; border-bottom: 1px solid var(--vp-c-divider); vertical-align: top; }
.props th { font-weight: 500; color: var(--vp-c-text-2); white-space: nowrap; }
</style>
