<script setup>
import { ref, onMounted, computed } from "vue";

const props = defineProps({ plane: { type: [String, Number], required: true } });

const planeMeta = ref(null);
const blocksIndex = ref([]);

const planeNumber = computed(() => Number(props.plane));
const blocksForPlane = computed(() =>
  blocksIndex.value.filter((b) => b.plane_number === planeNumber.value)
);

onMounted(async () => {
  const [planeRes, blocksRes] = await Promise.all([
    fetch(`/data/planes/${planeNumber.value}.json`),
    fetch(`/data/blocks/index.json`),
  ]);
  planeMeta.value = await planeRes.json();
  blocksIndex.value = await blocksRes.json();
});
</script>

<template>
  <div class="plane">
    <header v-if="planeMeta">
      <h1>
        <code>U+{{ planeNumber.toString(16).toUpperCase().padStart(2, "0") }}0000</code>
        –
        <code>U+{{ planeNumber.toString(16).toUpperCase().padStart(2, "0") }}FFFF</code>
      </h1>
      <p class="lead">{{ planeMeta.name }} ({{ planeMeta.abbrev }})</p>
    </header>

    <section>
      <h2>Blocks ({{ blocksForPlane.length }})</h2>
      <ul class="block-list">
        <li v-for="b in blocksForPlane" :key="b.id">
          <a :href="`/block/${b.id}`">{{ b.name }}</a>
          <small>
            U+{{ b.first_cp.toString(16).toUpperCase().padStart(4, "0") }}
            –
            U+{{ b.last_cp.toString(16).toUpperCase().padStart(4, "0") }}
          </small>
        </li>
      </ul>
    </section>
  </div>
</template>

<style scoped>
.lead { color: var(--vp-c-text-2); }
.block-list { list-style: none; padding: 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 0.5rem; }
.block-list li { padding: 0.5rem 0.75rem; border: 1px solid var(--vp-c-divider); border-radius: 4px; }
.block-list small { display: block; color: var(--vp-c-text-3); font-family: monospace; }
</style>
