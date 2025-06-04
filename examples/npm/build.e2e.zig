const std = @import("std");

const base = @import("base");

pub const E2e = struct {
    client_clean: *std.Build.Step,
    client_install: *std.Build.Step,
    client_run: *std.Build.Step,
    registry_clean: *std.Build.Step,
    registry_login: *std.Build.Step,
    registry_start: *std.Build.Step,
};

pub fn create(b: *std.Build, publish: *std.Build.Step) E2e {
    const e2e = E2e{
        .client_clean = b.step(
            "client:clean",
            "Clean the example client node modules",
        ),
        .client_install = b.step(
            "client:install",
            "Install the example client for the current target",
        ),
        .client_run = b.step(
            "client:run",
            "Run the example client for the current target",
        ),
        .registry_clean = b.step(
            "registry:clean",
            "Clear the local NPM registry",
        ),
        .registry_login = b.step(
            "registry:login",
            "Log in to the local NPM registry server",
        ),
        .registry_start = b.step(
            "registry:start",
            "Start local NPM registry server",
        ),
    };

    const registry_clean = b.addRemoveDirTree(b.path("registry/packages"));
    e2e.registry_clean.dependOn(&registry_clean.step);

    const registry_start = b.addSystemCommand(&.{ "pnpm", "start" });
    registry_start.setCwd(b.path("registry"));
    e2e.registry_start.dependOn(&registry_start.step);

    const registry_login_exe = b.addExecutable(.{
        .name = "registry-login",
        .root_module = b.createModule(.{
            .root_source_file = b.path("registry_login.zig"),
            .target = b.resolveTargetQuery(.{}),
        }),
    });
    const registry_login = b.addRunArtifact(registry_login_exe);
    e2e.registry_login.dependOn(&registry_login.step);

    {
        const client_clean_build = b.addRemoveDirTree(b.path("client/build"));
        e2e.client_clean.dependOn(&client_clean_build.step);

        const client_clean_deps = b.addRemoveDirTree(
            b.path("client/node_modules"),
        );
        e2e.client_clean.dependOn(&client_clean_deps.step);

        const client_clean_pnpm = b.addSystemCommand(&.{
            "pnpm", "store", "prune",
        });
        client_clean_pnpm.setCwd(b.path("client"));
        e2e.client_clean.dependOn(&client_clean_pnpm.step);

        const client_clean_lockfile = base.addFileRemove(
            b,
            b.path("client/pnpm-lock.yaml"),
        );
        e2e.client_clean.dependOn(&client_clean_lockfile.step);
    }

    const client_install = b.addSystemCommand(&.{ "pnpm", "i" });
    client_install.setCwd(b.path("client"));
    client_install.step.dependOn(publish);
    client_install.step.dependOn(e2e.client_clean);
    e2e.client_install.dependOn(&client_install.step);

    const client_run = b.addSystemCommand(&.{ "pnpm", "start" });
    client_run.setCwd(b.path("client"));
    client_run.has_side_effects = true;
    client_run.step.dependOn(e2e.client_install);
    e2e.client_run.dependOn(&client_run.step);

    return e2e;
}
