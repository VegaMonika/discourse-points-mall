import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-points-mall-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser || !currentUser.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon("discourse-points-mall", "gift");
      api.addAdminPluginConfigurationNav("discourse-points-mall", [
        {
          label: "points_mall.admin.manage",
          route: "adminPlugins.show.discourse-points-mall-manage",
        },
      ]);
    });
  },
};
