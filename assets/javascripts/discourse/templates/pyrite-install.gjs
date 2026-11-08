import PyriteInstallPage from "../components/pyrite-install-page";

export default <template>
  <PyriteInstallPage
    @extension={{@model.extension}}
    @release={{@model.release}}
  />
</template>
