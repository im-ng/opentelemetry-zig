const std = @import("std");
const helpers = @import("../helpers.zig");

const BuildError = helpers.BuildError;
const BuildModules = helpers.BuildModules;
const CompilationInfo = helpers.CompilationInfo;

const semconv_root = "opentelemetry-semconv";

pub fn Setup(
    b: *std.Build,
    info: CompilationInfo,
    dependencies: *BuildModules,
) !void {
    const semconv_mod = b.addModule("opentelemetry-semconv", .{
        .root_source_file = b.path(semconv_root ++ "/src/lib.zig"),
        .target = info.target,
        .optimize = info.optimize,
    });
    try dependencies.put("opentelemetry-semconv", semconv_mod);

    _ = try addTestStep(b, semconv_mod);
    try addExamplesStep(b, semconv_mod, info);
    _ = try addDocsStep(b, info);
    addGenerateStep(b);
}

fn addTestStep(b: *std.Build, semconv_mod: *std.Build.Module) !*std.Build.Step {
    const step = b.step("semconv-test", "Run opentelemetry-semconv unit tests");

    const semconv_tests = b.addTest(.{
        .root_module = semconv_mod,
        .filters = &[0][]const u8{},
    });
    const run_semconv_tests = b.addRunArtifact(semconv_tests);
    step.dependOn(&run_semconv_tests.step);

    return step;
}

// Registers the "semconv-examples" step (build and install every example to
// zig-out/bin/semconv/, without running them) and the "semconv-run-examples"
// step (run the installed binaries).
fn addExamplesStep(_: *std.Build, _: *std.Build.Module, _: CompilationInfo) !void {

    // NOTE: 0.17 removed LazyPath.getPath3; example iteration stubbed for the
    // opentelemetry build (examples are not needed by zero). Revisit if
    // opentelemetry examples must run.
    _ = semconv_root;

}

fn addDocsStep(b: *std.Build, info: CompilationInfo) !*std.Build.Step {
    const step = b.step("semconv-docs", "Copy opentelemetry-semconv documentation artifacts to prefix path");

    const semconv_docs = b.addObject(.{
        .name = "semconv",
        .root_module = b.createModule(.{
            .root_source_file = b.path(semconv_root ++ "/src/lib.zig"),
            .target = info.target,
            // Doc emission is independent of optimize mode; pin to Debug
            // for the fastest doc builds.
            .optimize = .debug,
        }),
    });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = semconv_docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/semconv",
    });

    step.dependOn(&install_docs.step);

    return step;
}

fn addGenerateStep(b: *std.Build) void {
    const generate = b.addSystemCommand(&.{"bash"});
    generate.addFileArg(b.path(semconv_root ++ "/scripts/generate-consts-from-spec.sh"));
    generate.setCwd(b.path(semconv_root));
    generate.has_side_effects = true;

    const step = b.step("semconv-generate", "Regenerate semantic conventions from the spec (requires Docker)");
    step.dependOn(&generate.step);
}
