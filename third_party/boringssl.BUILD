load(":BUILD.generated.bzl", "crypto_sources", "ssl_sources", "crypto_headers", "ssl_headers", "crypto_sources_linux_x86_64", "crypto_internal_headers", "ssl_internal_headers", "fips_fragments")

cc_library(
    name = "crypto",
    srcs = crypto_sources + crypto_sources_linux_x86_64 + crypto_internal_headers,
    hdrs = crypto_headers + fips_fragments,
    includes = ["src/include"],
    copts = ["-fvisibility=hidden"],
    visibility = ["//visibility:public"],
)

cc_library(
    name = "ssl",
    srcs = ssl_sources + ssl_internal_headers,
    hdrs = ssl_headers,
    includes = ["src/include"],
    copts = ["-fvisibility=hidden"],
    visibility = ["//visibility:public"],
    deps = [
        ":crypto",
    ],
)
