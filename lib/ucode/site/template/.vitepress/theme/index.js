import DefaultTheme from "vitepress/theme";
import { defineComponent, h } from "vue";
import PlaneView from "../components/PlaneView.vue";
import BlockView from "../components/BlockView.vue";
import CharView from "../components/CharView.vue";

export default {
  ...DefaultTheme,
  Layout: defineComponent({
    name: "UcodeLayout",
    setup() {
      return () => h(DefaultTheme.Layout, null, {});
    },
  }),
  enhanceApp({ app }) {
    app.component("PlaneView", PlaneView);
    app.component("BlockView", BlockView);
    app.component("CharView", CharView);
  },
};
