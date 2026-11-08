export default function () {
  this.route("pyrite-new", { path: "/pyrite/new" });
  this.route("pyrite-install", { path: "/pyrite/install/*ext_id" });
  this.route("pyrite-manage", { path: "/pyrite/manage/*ext_id" });
  this.route("pyrite-admin", { path: "/pyrite/admin" });
}
