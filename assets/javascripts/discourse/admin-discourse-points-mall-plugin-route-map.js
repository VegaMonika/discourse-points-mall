export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("discourse-points-mall-manage", { path: "manage" });
  },
};
