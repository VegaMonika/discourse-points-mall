import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", () => {
  // 签到摘要数据可以通过直接调用 ajax 获取
  // 不再需要注册 store adapter
});
