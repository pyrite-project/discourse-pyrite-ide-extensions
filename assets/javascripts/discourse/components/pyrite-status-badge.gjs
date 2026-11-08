import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";

export default <template>
  <span class="pyrite-status --{{@level}}">
    {{i18n (concat "pyrite_extensions.status." @level)}}
  </span>
</template>
