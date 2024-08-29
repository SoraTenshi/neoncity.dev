const std = @import("std");
const zine = @import("zine");

pub fn build(b: *std.Build) !void {
    zine.website(b, .{
        .title = "Blog by SoraNoTenshi",
        .host_url = "https://neoncity.dev/",
        .layouts_dir_path = "layouts",
        .content_dir_path = "content",
        .assets_dir_path = "assets",
    });
}
