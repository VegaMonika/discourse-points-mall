import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

export default apiInitializer("1.8.0", (api) => {
  api.addNavigationBarItem({
    name: "points-mall",
    displayName: i18n("points_mall.title"),
    href: "/points-mall",
    classNames: ["points-mall-nav"],
  });
});
