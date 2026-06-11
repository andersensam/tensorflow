load(
    ":BUILD.generated.bzl",
    "crypto_headers",
    "crypto_internal_headers",
    "crypto_sources",
    "crypto_sources_apple_aarch64",
    "crypto_sources_apple_x86_64",
    "crypto_sources_linux_aarch64",
    "crypto_sources_linux_x86_64",
    "fips_fragments",
    "ssl_headers",
    "ssl_internal_headers",
    "ssl_sources",
)

config_setting(
    name = "macos_x86_64",
    constraint_values = [
        "@platforms//os:macos",
        "@platforms//cpu:x86_64",
    ],
)

config_setting(
    name = "macos_aarch64",
    constraint_values = [
        "@platforms//os:macos",
        "@platforms//cpu:aarch64",
    ],
)

config_setting(
    name = "linux_x86_64",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
)

config_setting(
    name = "linux_aarch64",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:aarch64",
    ],
)

cc_library(
    name = "crypto",
    srcs = crypto_sources + crypto_internal_headers + select({
        ":macos_x86_64": crypto_sources_apple_x86_64,
        ":macos_aarch64": crypto_sources_apple_aarch64,
        ":linux_x86_64": crypto_sources_linux_x86_64,
        ":linux_aarch64": crypto_sources_linux_aarch64,
        "//conditions:default": [],
    }),
    hdrs = crypto_headers + fips_fragments,
    includes = ["src/include"],
    visibility = ["//visibility:public"],
)

cc_library(
    name = "ssl",
    srcs = ssl_sources + ssl_internal_headers,
    hdrs = ssl_headers,
    includes = ["src/include"],
    visibility = ["//visibility:public"],
    deps = [
        ":crypto",
    ],
)

exports_files(
    crypto_sources + ssl_sources + crypto_headers + ssl_headers + crypto_sources_linux_x86_64 + crypto_sources_linux_aarch64 + crypto_sources_apple_x86_64 + crypto_sources_apple_aarch64 + crypto_internal_headers + ssl_internal_headers + fips_fragments + ["err_data.c"],
    visibility = ["//visibility:public"],
)
