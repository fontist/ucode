<script setup>
import { ref, onMounted, computed } from "vue";
import MiniSearch from "minisearch";

const query = ref("");
const results = ref([]);
const status = ref("loading");
let index = null;

onMounted(async () => {
  try {
    const res = await fetch("/data/index/search.json");
    const docs = await res.json();
    index = new MiniSearch({
      fields: ["name", "id"],
      storeFields: ["name", "gc", "sc"],
      idField: "id",
    });
    await index.addAllAsync(docs);
    status.value = "ready";
  } catch (e) {
    status.value = "error";
  }
});

const run = () => {
  if (!index || query.value.trim().length < 2) {
    results.value = [];
    return;
  }
  results.value = index.search(query.value, { prefix: true, fuzzy: 0.2, limit: 50 });
};
</script>

<template>
  <div class="search">
    <h1>Search</h1>
    <p v-if="status === 'loading'">Loading index…</p>
    <p v-else-if="status === 'error'">Failed to load search index.</p>
    <div v-else>
      <input
        v-model="query"
        @input="run"
        placeholder="Search by name (e.g. LATIN CAPITAL LETTER A) or U+0041"
        autofocus
      />
      <p class="meta">{{ results.length }} result(s)</p>
      <ul class="results">
        <li v-for="r in results" :key="r.id">
          <a :href="`/char/${r.id.slice(2)}`">
            <code>{{ r.id }}</code> — {{ r.name }}
          </a>
          <small v-if="r.gc || r.sc">({{ [r.gc, r.sc].filter(Boolean).join(", ") }})</small>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
input { width: 100%; padding: 0.5rem 0.75rem; font-size: 1rem; border: 1px solid var(--vp-c-divider); border-radius: 4px; background: var(--vp-c-bg); color: var(--vp-c-text-1); }
.meta { color: var(--vp-c-text-3); font-size: 0.85rem; }
.results { list-style: none; padding: 0; }
.results li { padding: 0.5rem 0; border-bottom: 1px solid var(--vp-c-divider); }
.results small { color: var(--vp-c-text-3); margin-left: 0.5rem; }
</style>
