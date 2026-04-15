#!/bin/bash
# Shared project download + build-config library.
# Source this (don't execute). Defines:
#   download_project <name>   — clones/unpacks into $WORKDIR/<name>
#   get_project_config <name> — prints "src_files|include_dirs|extra_cflags|extra_ldflags"
#
# Kept in sync with expanded_sanitizer_overhead.sh; any new project added there
# must be added here too. Used by overhead_matrix.sh and any future matrix runs.

download_project() {
    local proj="$1"
    local dest="$WORKDIR/$proj"
    case "$proj" in
        sqlite)
            curl -sL "https://www.sqlite.org/2024/sqlite-amalgamation-3470200.zip" -o "$WORKDIR/sqlite.zip"
            cd "$WORKDIR" && python3 -m zipfile -e sqlite.zip . && mv sqlite-amalgamation-3470200 "$dest" && cd - >/dev/null ;;
        lz4)            git clone --depth 1 -q https://github.com/lz4/lz4.git "$dest" 2>/dev/null ;;
        zlib)           git clone --depth 1 -q https://github.com/madler/zlib.git "$dest" 2>/dev/null ;;
        cjson)          git clone --depth 1 -q https://github.com/DaveGamble/cJSON.git "$dest" 2>/dev/null ;;
        lua)            curl -sL "https://www.lua.org/ftp/lua-5.4.6.tar.gz" | tar xz -C "$WORKDIR"; mv "$WORKDIR/lua-5.4.6" "$dest" ;;
        xxhash)         git clone --depth 1 -q https://github.com/Cyan4973/xxHash.git "$dest" 2>/dev/null ;;
        utf8proc)       git clone --depth 1 -q https://github.com/JuliaStrings/utf8proc.git "$dest" 2>/dev/null ;;
        brotli)         git clone --depth 1 -q https://github.com/google/brotli.git "$dest" 2>/dev/null ;;
        zstd)           git clone --depth 1 -q https://github.com/facebook/zstd.git "$dest" 2>/dev/null ;;
        mbedtls)        git clone --depth 1 -q --recurse-submodules --shallow-submodules https://github.com/Mbed-TLS/mbedtls.git "$dest" 2>/dev/null ;;
        yyjson)         git clone --depth 1 -q https://github.com/ibireme/yyjson.git "$dest" 2>/dev/null ;;
        http-parser)    git clone --depth 1 -q https://github.com/nodejs/http-parser.git "$dest" 2>/dev/null ;;
        picohttpparser) git clone --depth 1 -q https://github.com/h2o/picohttpparser.git "$dest" 2>/dev/null ;;
        qsort)          mkdir -p "$dest" ;;
        miniz)          git clone --depth 1 -q https://github.com/richgel999/miniz.git "$dest" 2>/dev/null
                        printf '#define MINIZ_EXPORT\n' > "$dest/miniz_export.h" ;;
        stb)            git clone --depth 1 -q https://github.com/nothings/stb.git "$dest" 2>/dev/null ;;
        tinyexpr)       git clone --depth 1 -q https://github.com/codeplea/tinyexpr.git "$dest" 2>/dev/null ;;
        monocypher)     git clone --depth 1 -q https://github.com/LoupVaillant/Monocypher.git "$dest" 2>/dev/null ;;
        dr_libs)        git clone --depth 1 -q https://github.com/mackron/dr_libs.git "$dest" 2>/dev/null ;;
        lodepng)        git clone --depth 1 -q https://github.com/lvandeve/lodepng.git "$dest" 2>/dev/null ;;
        giflib)         curl -sL "https://sourceforge.net/projects/giflib/files/giflib-5.2.1.tar.gz" -o "$WORKDIR/giflib.tar.gz"
                        cd "$WORKDIR" && tar xzf giflib.tar.gz && mv giflib-5.2.1 "$dest" && cd - >/dev/null ;;
        libdeflate)     git clone --depth 1 -q https://github.com/ebiggers/libdeflate.git "$dest" 2>/dev/null ;;
        libsodium)      curl -sL "https://github.com/jedisct1/libsodium/releases/download/1.0.20-RELEASE/libsodium-1.0.20.tar.gz" -o "$WORKDIR/libsodium.tar.gz"
                        cd "$WORKDIR" && tar xzf libsodium.tar.gz && mv libsodium-* "$dest" && cd - >/dev/null ;;
        duktape)        curl -sL "https://duktape.org/duktape-2.7.0.tar.xz" -o "$WORKDIR/duktape.tar.xz"
                        cd "$WORKDIR" && tar xJf duktape.tar.xz && mv duktape-2.7.0 "$dest" && cd - >/dev/null ;;
        quickjs)        curl -sL "https://bellard.org/quickjs/quickjs-2024-01-13.tar.xz" -o "$WORKDIR/quickjs.tar.xz"
                        cd "$WORKDIR" && tar xJf quickjs.tar.xz && mv quickjs-2024-01-13 "$dest" && cd - >/dev/null ;;
        pcre2)          git clone --depth 1 -q https://github.com/PCRE2Project/pcre2.git "$dest" 2>/dev/null ;;
        cmark)          git clone --depth 1 -q https://github.com/commonmark/cmark.git "$dest" 2>/dev/null ;;
        jemalloc)       git clone --depth 1 -q https://github.com/jemalloc/jemalloc.git "$dest" 2>/dev/null ;;
        leveldb)        git clone --depth 1 -q --recurse-submodules --shallow-submodules https://github.com/google/leveldb.git "$dest" 2>/dev/null ;;
        jsmn)           git clone --depth 1 -q https://github.com/zserge/jsmn.git "$dest" 2>/dev/null ;;
        stb_image|stb_sprintf)
                        git clone --depth 1 -q https://github.com/nothings/stb.git "$dest" 2>/dev/null ;;
        miniaudio)      git clone --depth 1 -q https://github.com/mackron/miniaudio.git "$dest" 2>/dev/null ;;
        http_parser)    git clone --depth 1 -q https://github.com/nodejs/http-parser.git "$dest" 2>/dev/null ;;
        snappy)         git clone --depth 1 -q https://github.com/andikleen/snappy-c.git "$dest" 2>/dev/null ;;
        libyaml)        git clone --depth 1 -q https://github.com/yaml/libyaml.git "$dest" 2>/dev/null
                        cat > "$dest/src/config.h" <<'CFGEOF'
#ifndef YAML_CONFIG_H
#define YAML_CONFIG_H
#define YAML_VERSION_MAJOR 0
#define YAML_VERSION_MINOR 2
#define YAML_VERSION_PATCH 5
#define YAML_VERSION_STRING "0.2.5"
#endif
CFGEOF
                        ;;
        libexpat)       git clone --depth 1 -q https://github.com/libexpat/libexpat.git "$dest/_top" 2>/dev/null
                        mv "$dest/_top/expat" "$dest/expat" 2>/dev/null || true ;;
        libcbor)        git clone --depth 1 -q https://github.com/PJK/libcbor.git "$dest" 2>/dev/null
                        mkdir -p "$dest/src/cbor"
                        cat > "$dest/src/cbor/configuration.h" <<'CFGEOF'
#ifndef LIBCBOR_CONFIGURATION_H
#define LIBCBOR_CONFIGURATION_H
#define CBOR_MAJOR_VERSION 0
#define CBOR_MINOR_VERSION 11
#define CBOR_PATCH_VERSION 0
#define CBOR_BUFFER_GROWTH 2
#define CBOR_MAX_STACK_SIZE 2048
#define CBOR_PRETTY_PRINTER 0
#define CBOR_RESTRICT_SPECIFIER restrict
#define CBOR_INLINE_SPECIFIER
#define CBOR_CUSTOM_ALLOC 0
#endif
CFGEOF
                        cat > "$dest/src/cbor/cbor_export.h" <<'EXPEOF'
#ifndef CBOR_EXPORT_H
#define CBOR_EXPORT_H
#define CBOR_EXPORT
#define CBOR_NO_EXPORT
#define CBOR_DEPRECATED
#define CBOR_DEPRECATED_EXPORT
#define CBOR_DEPRECATED_NO_EXPORT
#endif
EXPEOF
                        ;;
        mongoose)       git clone --depth 1 -q https://github.com/cesanta/mongoose.git "$dest" 2>/dev/null ;;
        tomlc99)        git clone --depth 1 -q https://github.com/cktan/tomlc99.git "$dest" 2>/dev/null ;;
        inih)           git clone --depth 1 -q https://github.com/benhoyt/inih.git "$dest" 2>/dev/null ;;
        uthash)         git clone --depth 1 -q https://github.com/troydhanson/uthash.git "$dest" 2>/dev/null ;;
        md4c)           git clone --depth 1 -q https://github.com/mity/md4c.git "$dest" 2>/dev/null ;;
        sds)            git clone --depth 1 -q https://github.com/antirez/sds.git "$dest" 2>/dev/null ;;
        pdjson)         git clone --depth 1 -q https://github.com/skeeto/pdjson.git "$dest" 2>/dev/null ;;
        *) return 1 ;;
    esac
}

get_project_config() {
    local proj="$1"
    local d="$WORKDIR/$proj"
    case "$proj" in
        sqlite)         echo "$d/sqlite3.c|$d|-DSQLITE_THREADSAFE=0|" ;;
        lz4)            echo "$d/lib/lz4.c|$d/lib||" ;;
        zlib)           echo "$d/adler32.c $d/compress.c $d/crc32.c $d/deflate.c $d/infback.c $d/inffast.c $d/inflate.c $d/inftrees.c $d/trees.c $d/uncompr.c $d/zutil.c|$d||" ;;
        cjson)          echo "$d/cJSON.c|$d||" ;;
        lua)            echo "$(ls $d/src/*.c | grep -v lua.c | grep -v luac.c | tr '\n' ' ')|$d/src|-DLUA_USE_POSIX|-lm" ;;
        xxhash)         echo "|$d||" ;;
        utf8proc)       echo "$d/utf8proc.c|$d||" ;;
        brotli)         echo "$(ls $d/c/common/*.c $d/c/dec/*.c $d/c/enc/*.c 2>/dev/null | tr '\n' ' ')|$d/c/include||" ;;
        zstd)           echo "$(ls $d/lib/common/*.c $d/lib/compress/*.c $d/lib/decompress/*.c 2>/dev/null | tr '\n' ' ')|$d/lib $d/lib/common|-DZSTD_DISABLE_ASM=1|" ;;
        mbedtls)        echo "$(ls $d/library/aes.c $d/library/platform_util.c $d/library/constant_time.c 2>/dev/null | tr '\n' ' ')|$d/include||" ;;
        yyjson)         echo "$d/src/yyjson.c|$d/src||" ;;
        http-parser)    echo "$d/http_parser.c|$d||" ;;
        picohttpparser) echo "$d/picohttpparser.c|$d||" ;;
        qsort)          echo "|||-lm" ;;
        miniz)          echo "$d/miniz.c $d/miniz_tdef.c $d/miniz_tinfl.c|$d||" ;;
        stb)            echo "|$d||" ;;
        tinyexpr)       echo "$d/tinyexpr.c|$d||-lm" ;;
        monocypher)     echo "$d/src/monocypher.c|$d/src||" ;;
        dr_libs)        echo "|$d||-lm" ;;
        lodepng)        echo "$d/lodepng.cpp|$d||" ;;
        giflib)         echo "$d/dgif_lib.c $d/egif_lib.c $d/gif_err.c $d/gif_font.c $d/gif_hash.c $d/gifalloc.c $d/quantize.c|$d||" ;;
        libdeflate)     echo "$(ls $d/lib/*.c $d/lib/*/*.c 2>/dev/null | head -30 | tr '\n' ' ')|$d||" ;;
        libsodium)      echo "$(ls $d/src/libsodium/crypto_generichash/blake2b/ref/*.c $d/src/libsodium/randombytes/*.c $d/src/libsodium/sodium/*.c 2>/dev/null | tr '\n' ' ')|$d/src/libsodium/include||" ;;
        duktape)        echo "$d/src/duktape.c|$d/src||-lm" ;;
        quickjs)        echo "$d/quickjs.c $d/cutils.c $d/libbf.c $d/libregexp.c $d/libunicode.c|$d|-D_GNU_SOURCE -DCONFIG_VERSION=\\\"2024\\\"|-lm -lpthread" ;;
        pcre2)          echo "$(ls $d/src/pcre2_*.c 2>/dev/null | grep -v test | grep -v demo | head -20 | tr '\n' ' ')|$d/src -I$d/build|-DHAVE_CONFIG_H -DPCRE2_CODE_UNIT_WIDTH=8|" ;;
        cmark)          echo "$(ls $d/src/*.c 2>/dev/null | grep -v main.c | tr '\n' ' ')|$d/src -I$d/build/src||" ;;
        jemalloc)       echo "$(ls $d/src/*.c 2>/dev/null | head -10 | tr '\n' ' ')|$d/include||" ;;
        leveldb)        echo "$(ls $d/db/*.cc $d/table/*.cc $d/util/*.cc 2>/dev/null | head -20 | tr '\n' ' ')|$d/include -I$d||" ;;
        jsmn)           echo "|$d||" ;;
        stb_image)      echo "|$d||-lm" ;;
        stb_sprintf)    echo "|$d||" ;;
        miniaudio)      echo "|$d|-DMA_NO_DEVICE_IO -DMA_NO_THREADING -DMA_NO_GENERATION -DMA_NO_DECODING -DMA_NO_ENCODING|-lm -lpthread -ldl" ;;
        http_parser)    echo "$d/http_parser.c|$d||" ;;
        snappy)         echo "$d/snappy.c $d/util.c|$d||" ;;
        libyaml)        echo "$(ls $d/src/*.c 2>/dev/null | tr '\n' ' ')|$d/include -I$d/src|-DHAVE_CONFIG_H|" ;;
        libexpat)       echo "$d/expat/lib/xmlparse.c $d/expat/lib/xmltok.c $d/expat/lib/xmlrole.c|$d/expat/lib|-DHAVE_EXPAT_CONFIG_H=0 -DXML_GE=1 -DXML_DTD -DXML_NS -DXML_CONTEXT_BYTES=1024 -DHAVE_MEMMOVE -DHAVE_GETRANDOM|" ;;
        libcbor)        echo "$(ls $d/src/cbor.c $d/src/allocators.c $d/src/cbor/*.c $d/src/cbor/internal/*.c 2>/dev/null | tr '\n' ' ')|$d/src -I$d|-DCBOR_CUSTOM_ALLOC=0|" ;;
        mongoose)       echo "$d/mongoose.c|$d||" ;;
        tomlc99)        echo "$d/toml.c|$d||" ;;
        inih)           echo "$d/ini.c|$d||" ;;
        uthash)         echo "|$d/src||" ;;
        md4c)           echo "$d/src/md4c.c|$d/src||" ;;
        sds)            echo "$d/sds.c|$d||" ;;
        pdjson)         echo "$d/pdjson.c|$d||" ;;
        *) echo "" ;;
    esac
}

# All projects with benchmark harnesses (42 total; 7 new as of Apr 2026 final).
ALL_PROJECTS="sqlite lz4 zlib cjson lua xxhash utf8proc brotli zstd mbedtls yyjson http-parser picohttpparser qsort miniz stb tinyexpr monocypher dr_libs lodepng giflib libdeflate libsodium duktape quickjs pcre2 cmark jemalloc leveldb jsmn stb_image stb_sprintf miniaudio snappy libyaml libexpat libcbor http_parser mongoose tomlc99 inih uthash md4c sds pdjson"
