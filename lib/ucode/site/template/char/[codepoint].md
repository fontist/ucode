---
layout: doc
---

<script setup>
import { useRoute } from "vitepress";
import CharView from "../components/CharView.vue";

const route = useRoute();
const codepoint = route.params.codepoint;
</script>

<CharView :codepoint="codepoint" />
