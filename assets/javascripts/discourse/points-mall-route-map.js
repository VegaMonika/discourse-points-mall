export default function () {
  this.route("points-mall", { path: "/loja" }, function () {
    this.route("shop", { path: "/produtos" });
    this.route("orders", { path: "/pedidos" });
    this.route("checkin", { path: "/checkin" });
    this.route("inventory", { path: "/inventario" });
    this.route("addresses", { path: "/enderecos" });
  });
}
