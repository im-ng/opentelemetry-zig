const std = @import("std");
const zon = @import("build.zig.zon");

const helpers = @import("build/helpers.zig");
const proto_build = @import("build/proto/build.zig");
const semconv_build = @import("build/semconv/build.zig");
const sdk_build = @import("build/sdk/build.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .safe });

    const benchmarks_mod = b.dependency("zbench", .{}).module("zbench");
    // Reuse the root graph's protobuf registration. A second
    // b.dependency with different options re-runs the protobuf build
    // script in the same graph, which re-roots src/protobuf.zig under a
    // fresh module name ("protobuf0") — a 0.17 compile error.
    const protobuf_mod = b.dependency("protobuf", .{}).module("protobuf");

    var build_mods = helpers.BuildModules.init(b.allocator);
    defer build_mods.deinit();

    try build_mods.put("protobuf", protobuf_mod);
    try build_mods.put("benchmark", benchmarks_mod);

    const compilation_info = helpers.CompilationInfo{
        .target = target,
        .optimize = optimize,
        .pkg_name = @tagName(zon.name),
        .version = zon.version,
    };

    // proto and semconv expose modules the SDK can import so they need to be built first.
    try proto_build.Setup(b, compilation_info, &build_mods);
    try semconv_build.Setup(b, compilation_info, &build_mods);
    try sdk_build.Setup(b, compilation_info, &build_mods);
}
