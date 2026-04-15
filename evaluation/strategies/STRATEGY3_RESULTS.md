# Strategy 3 Results: Aggressive Compiler Flags on Real Projects

## Methodology

For each (project, flag) combination:
1. Build project at `-O0`, run test suite → record baseline exit code + output hash
2. Build project with aggressive flags, run test suite → record exit code + output hash
3. If baseline passes but aggressive fails (exit code or output differs) → **CANDIDATE**
4. For candidates, rebuild with Trace2Pass instrumentation to detect anomalies

## Flag Combinations Tested

| Label | Flags | Rationale |
|-------|-------|-----------|
| `O3_fastmath` | `-O3 -ffast-math` | Relaxed IEEE semantics, most likely to cause failures |
| `O3_strict_aliasing` | `-O3 -fstrict-aliasing` | Strict type-based aliasing |
| `Os` | `-Os` | Size optimization, different pass ordering |
| `O3_lto` | `-O3 -flto` | Link-Time Optimization, aggressive interprocedural opts |
| `O3_fastmath_fma` | `-O3 -ffast-math -ffp-contract=fast` | Maximum float aggression with FMA contraction |

## Results Matrix


```
project,flag_label,baseline_exit,aggressive_exit,baseline_hash,aggressive_hash,status
mbedtls,O3_fastmath,0,0,19d63681edd2,19d63681edd2,ok
mbedtls,O3_strict_aliasing,0,0,19d63681edd2,19d63681edd2,ok
mbedtls,Os,0,0,19d63681edd2,19d63681edd2,ok
mbedtls,O3_lto,0,0,19d63681edd2,19d63681edd2,ok
mbedtls,O3_fastmath_fma,0,0,19d63681edd2,19d63681edd2,ok
lua,O3_fastmath,0,0,a2455c1b3821,a2455c1b3821,ok
lua,O3_strict_aliasing,0,0,a2455c1b3821,a2455c1b3821,ok
lua,Os,0,0,a2455c1b3821,a2455c1b3821,ok
lua,O3_lto,0,0,a2455c1b3821,d41d8cd98f00,build_fail
lua,O3_fastmath_fma,0,0,a2455c1b3821,a2455c1b3821,ok
sqlite,O3_fastmath,0,0,3c9c6555c562,3c9c6555c562,ok
sqlite,O3_strict_aliasing,0,0,3c9c6555c562,3c9c6555c562,ok
sqlite,Os,0,0,3c9c6555c562,3c9c6555c562,ok
sqlite,O3_lto,0,0,3c9c6555c562,d41d8cd98f00,build_fail
sqlite,O3_fastmath_fma,0,0,3c9c6555c562,3c9c6555c562,ok
tcc,O3_fastmath,0,0,d41d8cd98f00,d41d8cd98f00,build_fail
tcc,O3_strict_aliasing,0,0,d41d8cd98f00,d41d8cd98f00,build_fail
tcc,Os,0,0,d41d8cd98f00,d41d8cd98f00,build_fail
tcc,O3_lto,0,0,d41d8cd98f00,d41d8cd98f00,build_fail
tcc,O3_fastmath_fma,0,0,d41d8cd98f00,d41d8cd98f00,build_fail
zlib,O3_fastmath,0,0,765e3908c5f5,765e3908c5f5,ok
zlib,O3_strict_aliasing,0,0,765e3908c5f5,765e3908c5f5,ok
zlib,Os,0,0,765e3908c5f5,765e3908c5f5,ok
zlib,O3_lto,0,0,765e3908c5f5,765e3908c5f5,ok
zlib,O3_fastmath_fma,0,0,765e3908c5f5,765e3908c5f5,ok
lz4,O3_fastmath,0,0,5469cae6a948,5469cae6a948,ok
lz4,O3_strict_aliasing,0,0,5469cae6a948,5469cae6a948,ok
lz4,Os,0,0,5469cae6a948,5469cae6a948,ok
lz4,O3_lto,0,0,5469cae6a948,5469cae6a948,ok
lz4,O3_fastmath_fma,0,0,5469cae6a948,5469cae6a948,ok
cjson,O3_fastmath,0,0,aef741a39bdb,746b185bad8e,CANDIDATE_output
cjson,O3_strict_aliasing,0,0,aef741a39bdb,aef741a39bdb,ok
cjson,Os,0,0,aef741a39bdb,aef741a39bdb,ok
cjson,O3_lto,0,0,aef741a39bdb,d41d8cd98f00,build_fail
cjson,O3_fastmath_fma,0,0,aef741a39bdb,746b185bad8e,CANDIDATE_output
brotli,O3_fastmath,0,0,e52cad746109,e52cad746109,ok
brotli,O3_strict_aliasing,0,0,e52cad746109,e52cad746109,ok
brotli,Os,0,0,e52cad746109,e52cad746109,ok
brotli,O3_lto,0,0,e52cad746109,e52cad746109,ok
brotli,O3_fastmath_fma,0,0,e52cad746109,e52cad746109,ok
zstd,O3_fastmath,0,0,e52cad746109,e52cad746109,ok
zstd,O3_strict_aliasing,0,0,e52cad746109,e52cad746109,ok
zstd,Os,0,0,e52cad746109,e52cad746109,ok
zstd,O3_lto,0,0,e52cad746109,e52cad746109,ok
zstd,O3_fastmath_fma,0,0,e52cad746109,e52cad746109,ok
yyjson,O3_fastmath,0,0,074ec042fcef,074ec042fcef,ok
yyjson,O3_strict_aliasing,0,0,074ec042fcef,074ec042fcef,ok
yyjson,Os,0,0,074ec042fcef,074ec042fcef,ok
yyjson,O3_lto,0,0,074ec042fcef,074ec042fcef,ok
yyjson,O3_fastmath_fma,0,0,074ec042fcef,074ec042fcef,ok
xxhash,O3_fastmath,0,0,bc39031e41cc,bc39031e41cc,ok
xxhash,O3_strict_aliasing,0,0,bc39031e41cc,bc39031e41cc,ok
xxhash,Os,0,0,bc39031e41cc,bc39031e41cc,ok
xxhash,O3_lto,0,0,bc39031e41cc,bc39031e41cc,ok
xxhash,O3_fastmath_fma,0,0,bc39031e41cc,bc39031e41cc,ok
dr_libs,O3_fastmath,0,0,d75a3b019c7b,d75a3b019c7b,ok
dr_libs,O3_strict_aliasing,0,0,d75a3b019c7b,d75a3b019c7b,ok
dr_libs,Os,0,0,d75a3b019c7b,d75a3b019c7b,ok
dr_libs,O3_lto,0,0,d75a3b019c7b,d75a3b019c7b,ok
dr_libs,O3_fastmath_fma,0,0,d75a3b019c7b,d75a3b019c7b,ok
miniaudio,O3_fastmath,0,0,634d6b7040a2,634d6b7040a2,ok
miniaudio,O3_strict_aliasing,0,0,634d6b7040a2,634d6b7040a2,ok
miniaudio,Os,0,0,634d6b7040a2,634d6b7040a2,ok
miniaudio,O3_lto,0,0,634d6b7040a2,634d6b7040a2,ok
miniaudio,O3_fastmath_fma,0,0,634d6b7040a2,634d6b7040a2,ok
lodepng,O3_fastmath,0,0,04760a60a8d4,04760a60a8d4,ok
lodepng,O3_strict_aliasing,0,0,04760a60a8d4,04760a60a8d4,ok
lodepng,Os,0,0,04760a60a8d4,04760a60a8d4,ok
lodepng,O3_lto,0,0,04760a60a8d4,04760a60a8d4,ok
lodepng,O3_fastmath_fma,0,0,04760a60a8d4,04760a60a8d4,ok
giflib,O3_fastmath,0,0,d41d8cd98f00,d41d8cd98f00,build_fail
giflib,O3_strict_aliasing,0,0,d41d8cd98f00,d41d8cd98f00,build_fail
giflib,Os,0,0,d41d8cd98f00,d41d8cd98f00,build_fail
giflib,O3_lto,0,0,d41d8cd98f00,d41d8cd98f00,build_fail
giflib,O3_fastmath_fma,0,0,d41d8cd98f00,d41d8cd98f00,build_fail
tinyexpr,O3_fastmath,0,1,c1286f34241b,0e9368d16e84,CANDIDATE_exit
tinyexpr,O3_strict_aliasing,0,0,c1286f34241b,c1286f34241b,ok
tinyexpr,Os,0,0,c1286f34241b,c1286f34241b,ok
tinyexpr,O3_lto,0,0,c1286f34241b,c1286f34241b,ok
tinyexpr,O3_fastmath_fma,0,1,c1286f34241b,0e9368d16e84,CANDIDATE_exit
libdeflate,O3_fastmath,0,0,c8185d5c4da8,c8185d5c4da8,ok
libdeflate,O3_strict_aliasing,0,0,c8185d5c4da8,c8185d5c4da8,ok
libdeflate,Os,0,0,c8185d5c4da8,c8185d5c4da8,ok
libdeflate,O3_lto,0,0,c8185d5c4da8,c8185d5c4da8,ok
libdeflate,O3_fastmath_fma,0,0,c8185d5c4da8,c8185d5c4da8,ok
duktape,O3_fastmath,0,0,60778b1475f2,d41d8cd98f00,build_fail
duktape,O3_strict_aliasing,0,0,60778b1475f2,60778b1475f2,ok
duktape,Os,0,0,60778b1475f2,60778b1475f2,ok
duktape,O3_lto,0,0,60778b1475f2,60778b1475f2,ok
duktape,O3_fastmath_fma,0,0,60778b1475f2,d41d8cd98f00,build_fail
mruby,O3_fastmath,0,0,e8c2857e3064,e8c2857e3064,ok
mruby,O3_strict_aliasing,0,0,e8c2857e3064,e8c2857e3064,ok
mruby,Os,0,0,e8c2857e3064,e8c2857e3064,ok
mruby,O3_lto,0,0,e8c2857e3064,d41d8cd98f00,build_fail
mruby,O3_fastmath_fma,0,0,e8c2857e3064,e8c2857e3064,ok
monocypher,O3_fastmath,0,0,8ccf90fd7447,8ccf90fd7447,ok
monocypher,O3_strict_aliasing,0,0,8ccf90fd7447,8ccf90fd7447,ok
monocypher,Os,0,0,8ccf90fd7447,8ccf90fd7447,ok
monocypher,O3_lto,0,0,8ccf90fd7447,8ccf90fd7447,ok
monocypher,O3_fastmath_fma,0,0,8ccf90fd7447,8ccf90fd7447,ok
libsodium,O3_fastmath,0,0,288b94e0fd4e,288b94e0fd4e,ok
libsodium,O3_strict_aliasing,0,0,288b94e0fd4e,288b94e0fd4e,ok
libsodium,Os,0,0,288b94e0fd4e,288b94e0fd4e,ok
libsodium,O3_lto,0,0,288b94e0fd4e,288b94e0fd4e,ok
libsodium,O3_fastmath_fma,0,0,288b94e0fd4e,288b94e0fd4e,ok
simdjson,O3_fastmath,0,0,8518683682f7,8518683682f7,ok
simdjson,O3_strict_aliasing,0,0,8518683682f7,8518683682f7,ok
simdjson,Os,0,0,8518683682f7,8518683682f7,ok
simdjson,O3_lto,0,0,8518683682f7,8518683682f7,ok
simdjson,O3_fastmath_fma,0,0,8518683682f7,8518683682f7,ok
fmt,O3_fastmath,0,1,d9c9c7739ee4,568e362d845c,CANDIDATE_exit
fmt,O3_strict_aliasing,0,0,d9c9c7739ee4,d9c9c7739ee4,ok
fmt,Os,0,0,d9c9c7739ee4,d9c9c7739ee4,ok
fmt,O3_lto,0,0,d9c9c7739ee4,d9c9c7739ee4,ok
fmt,O3_fastmath_fma,0,1,d9c9c7739ee4,568e362d845c,CANDIDATE_exit
glm,O3_fastmath,0,0,1ae5836243d1,1ae5836243d1,ok
glm,O3_strict_aliasing,0,0,1ae5836243d1,1ae5836243d1,ok
glm,Os,0,0,1ae5836243d1,1ae5836243d1,ok
glm,O3_lto,0,0,1ae5836243d1,1ae5836243d1,ok
glm,O3_fastmath_fma,0,0,1ae5836243d1,1ae5836243d1,ok
```

## Candidates Found

### cjson with O3_fastmath
- Baseline exit: 0, Aggressive exit: 0
- Status: CANDIDATE_output
- Trace2Pass anomalies:
```
Trace2Pass: Injected build metadata: opt_level=unknown, flags=(none)
Trace2Pass: Instrumenting function: cJSON_GetErrorPtr
Trace2Pass: Instrumenting function: cJSON_GetStringValue
Trace2Pass: Instrumenting function: cJSON_IsString
Trace2Pass: Instrumenting function: cJSON_GetNumberValue
Trace2Pass: Instrumenting function: cJSON_IsNumber
Trace2Pass: Instrumenting function: cJSON_Version
Trace2Pass: Instrumenting function: cJSON_InitHooks
Trace2Pass: Instrumenting function: cJSON_Delete
Trace2Pass: Instrumenting function: cJSON_SetNumberHelper
Trace2Pass: Instrumenting function: cJSON_SetValuestring
Trace2Pass: Instrumenting function: cJSON_strdup
Trace2Pass: Instrumenting function: cJSON_free
Trace2Pass: Instrumenting function: cJSON_ParseWithOpts
Trace2Pass: Instrumenting function: cJSON_ParseWithLengthOpts
Trace2Pass: Instrumenting function: cJSON_New_Item
Trace2Pass: Instrumenting function: parse_value
Trace2Pass: Instrumenting function: buffer_skip_whitespace
Trace2Pass: Instrumenting function: skip_utf8_bom
Trace2Pass: Instrumenting function: cJSON_Parse
Trace2Pass: Instrumenting function: cJSON_ParseWithLength
Trace2Pass: Instrumenting function: cJSON_Print
Trace2Pass: Instrumenting function: print
Trace2Pass: Instrumenting function: cJSON_PrintUnformatted
Trace2Pass: Instrumenting function: cJSON_PrintBuffered
Trace2Pass: Instrumenting function: print_value
Trace2Pass: Instrumenting function: cJSON_PrintPreallocated
Trace2Pass: Instrumenting function: cJSON_GetArraySize
Trace2Pass: Instrumenting function: cJSON_GetArrayItem
Trace2Pass: Instrumenting function: get_array_item
Trace2Pass: Instrumenting function: cJSON_GetObjectItem
Trace2Pass: Instrumenting function: get_object_item
Trace2Pass: Instrumenting function: cJSON_GetObjectItemCaseSensitive
Trace2Pass: Instrumenting function: cJSON_HasObjectItem
Trace2Pass: Instrumenting function: cJSON_AddItemToArray
Trace2Pass: Instrumenting function: add_item_to_array
Trace2Pass: Instrumenting function: cJSON_AddItemToObject
Trace2Pass: Instrumenting function: add_item_to_object
Trace2Pass: Instrumenting function: cJSON_AddItemToObjectCS
Trace2Pass: Instrumenting function: cJSON_AddItemReferenceToArray
Trace2Pass: Instrumenting function: create_reference
Trace2Pass: Instrumenting function: cJSON_AddItemReferenceToObject
Trace2Pass: Instrumenting function: cJSON_AddNullToObject
Trace2Pass: Instrumenting function: cJSON_CreateNull
Trace2Pass: Instrumenting function: cJSON_AddTrueToObject
Trace2Pass: Instrumenting function: cJSON_CreateTrue
Trace2Pass: Instrumenting function: cJSON_AddFalseToObject
Trace2Pass: Instrumenting function: cJSON_CreateFalse
Trace2Pass: Instrumenting function: cJSON_AddBoolToObject
Trace2Pass: Instrumenting function: cJSON_CreateBool
Trace2Pass: Instrumenting function: cJSON_AddNumberToObject
Trace2Pass: Instrumenting function: cJSON_CreateNumber
Trace2Pass: Instrumenting function: cJSON_AddStringToObject
Trace2Pass: Instrumenting function: cJSON_CreateString
Trace2Pass: Instrumenting function: cJSON_AddRawToObject
Trace2Pass: Instrumenting function: cJSON_CreateRaw
Trace2Pass: Instrumenting function: cJSON_AddObjectToObject
Trace2Pass: Instrumenting function: cJSON_CreateObject
Trace2Pass: Instrumenting function: cJSON_AddArrayToObject
Trace2Pass: Instrumenting function: cJSON_CreateArray
Trace2Pass: Instrumenting function: cJSON_DetachItemViaPointer
Trace2Pass: Instrumenting function: cJSON_DetachItemFromArray
Trace2Pass: Instrumenting function: cJSON_DeleteItemFromArray
Trace2Pass: Instrumenting function: cJSON_DetachItemFromObject
Trace2Pass: Instrumenting function: cJSON_DetachItemFromObjectCaseSensitive
Trace2Pass: Instrumenting function: cJSON_DeleteItemFromObject
Trace2Pass: Instrumenting function: cJSON_DeleteItemFromObjectCaseSensitive
Trace2Pass: Instrumenting function: cJSON_InsertItemInArray
Trace2Pass: Instrumenting function: cJSON_ReplaceItemViaPointer
Trace2Pass: Instrumenting function: cJSON_ReplaceItemInArray
Trace2Pass: Instrumenting function: cJSON_ReplaceItemInObject
Trace2Pass: Instrumenting function: replace_item_in_object
Trace2Pass: Instrumenting function: cJSON_ReplaceItemInObjectCaseSensitive
Trace2Pass: Instrumenting function: cJSON_CreateStringReference
Trace2Pass: Instrumenting function: cast_away_const
Trace2Pass: Instrumenting function: cJSON_CreateObjectReference
Trace2Pass: Instrumenting function: cJSON_CreateArrayReference
Trace2Pass: Instrumenting function: cJSON_CreateIntArray
Trace2Pass: Instrumenting function: suffix_object
Trace2Pass: Instrumenting function: cJSON_CreateFloatArray
Trace2Pass: Instrumenting function: cJSON_CreateDoubleArray
Trace2Pass: Instrumenting function: cJSON_CreateStringArray
Trace2Pass: Instrumenting function: cJSON_Duplicate
Trace2Pass: Instrumenting function: cJSON_Duplicate_rec
Trace2Pass: Instrumenting function: cJSON_Minify
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in cJSON_Minify
Trace2Pass: Instrumenting function: skip_oneline_comment
Trace2Pass: Instrumenting function: skip_multiline_comment
Trace2Pass: Instrumenting function: minify_string
Trace2Pass: Instrumenting function: cJSON_IsInvalid
Trace2Pass: Instrumenting function: cJSON_IsFalse
Trace2Pass: Instrumenting function: cJSON_IsTrue
Trace2Pass: Instrumenting function: cJSON_IsBool
Trace2Pass: Instrumenting function: cJSON_IsNull
Trace2Pass: Instrumenting function: cJSON_IsArray
Trace2Pass: Instrumenting function: cJSON_IsObject
Trace2Pass: Instrumenting function: cJSON_IsRaw
Trace2Pass: Instrumenting function: cJSON_Compare
Trace2Pass: Instrumenting function: compare_double
Trace2Pass: Instrumenting function: cJSON_malloc
Trace2Pass: Instrumenting function: update_offset
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in update_offset
Trace2Pass: Instrumenting function: parse_string
Trace2Pass: Instrumenting function: parse_number
Trace2Pass: Instrumenting function: parse_array
Trace2Pass: Instrumenting function: parse_object
Trace2Pass: Instrumenting function: utf16_literal_to_utf8
Trace2Pass: Instrumented 3 arithmetic operations in utf16_literal_to_utf8
Trace2Pass: Instrumenting function: parse_hex4
Trace2Pass: Instrumented 1 arithmetic operations in parse_hex4
Trace2Pass: Instrumenting function: get_decimal_point
Trace2Pass: Instrumenting function: ensure
Trace2Pass: Instrumenting function: print_number
Trace2Pass: Instrumenting function: print_string
Trace2Pass: Instrumenting function: print_array
Trace2Pass: Instrumenting function: print_object
Trace2Pass: Instrumenting function: print_string_ptr
Trace2Pass: Instrumenting function: case_insensitive_strcmp
Trace2Pass: Instrumented 1 arithmetic operations in case_insensitive_strcmp
4 warnings generated.
Trace2Pass: Injected build metadata: opt_level=unknown, flags=(none)
Trace2Pass: Instrumenting function: main
Trace2Pass: Instrumenting function: create_objects
Trace2Pass: Instrumented 2 arithmetic operations, 6 unreachable blocks in create_objects
Trace2Pass: Instrumenting function: print_preallocated
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in print_preallocated
=== TEST OUTPUT START ===
Trace2Pass: Runtime initialized (sample_rate=0.010, opt_level=unknown)
Trace2Pass: Runtime shutting down
Version: 1.7.19
{
	"name":	"Jack (\"Bee\") Nimble",
	"format":	{
		"type":	"rect",
```

### cjson with O3_fastmath_fma
- Baseline exit: 0, Aggressive exit: 0
- Status: CANDIDATE_output
- Trace2Pass anomalies:
```
Trace2Pass: Injected build metadata: opt_level=unknown, flags=(none)
Trace2Pass: Instrumenting function: cJSON_GetErrorPtr
Trace2Pass: Instrumenting function: cJSON_GetStringValue
Trace2Pass: Instrumenting function: cJSON_IsString
Trace2Pass: Instrumenting function: cJSON_GetNumberValue
Trace2Pass: Instrumenting function: cJSON_IsNumber
Trace2Pass: Instrumenting function: cJSON_Version
Trace2Pass: Instrumenting function: cJSON_InitHooks
Trace2Pass: Instrumenting function: cJSON_Delete
Trace2Pass: Instrumenting function: cJSON_SetNumberHelper
Trace2Pass: Instrumenting function: cJSON_SetValuestring
Trace2Pass: Instrumenting function: cJSON_strdup
Trace2Pass: Instrumenting function: cJSON_free
Trace2Pass: Instrumenting function: cJSON_ParseWithOpts
Trace2Pass: Instrumenting function: cJSON_ParseWithLengthOpts
Trace2Pass: Instrumenting function: cJSON_New_Item
Trace2Pass: Instrumenting function: parse_value
Trace2Pass: Instrumenting function: buffer_skip_whitespace
Trace2Pass: Instrumenting function: skip_utf8_bom
Trace2Pass: Instrumenting function: cJSON_Parse
Trace2Pass: Instrumenting function: cJSON_ParseWithLength
Trace2Pass: Instrumenting function: cJSON_Print
Trace2Pass: Instrumenting function: print
Trace2Pass: Instrumenting function: cJSON_PrintUnformatted
Trace2Pass: Instrumenting function: cJSON_PrintBuffered
Trace2Pass: Instrumenting function: print_value
Trace2Pass: Instrumenting function: cJSON_PrintPreallocated
Trace2Pass: Instrumenting function: cJSON_GetArraySize
Trace2Pass: Instrumenting function: cJSON_GetArrayItem
Trace2Pass: Instrumenting function: get_array_item
Trace2Pass: Instrumenting function: cJSON_GetObjectItem
Trace2Pass: Instrumenting function: get_object_item
Trace2Pass: Instrumenting function: cJSON_GetObjectItemCaseSensitive
Trace2Pass: Instrumenting function: cJSON_HasObjectItem
Trace2Pass: Instrumenting function: cJSON_AddItemToArray
Trace2Pass: Instrumenting function: add_item_to_array
Trace2Pass: Instrumenting function: cJSON_AddItemToObject
Trace2Pass: Instrumenting function: add_item_to_object
Trace2Pass: Instrumenting function: cJSON_AddItemToObjectCS
Trace2Pass: Instrumenting function: cJSON_AddItemReferenceToArray
Trace2Pass: Instrumenting function: create_reference
Trace2Pass: Instrumenting function: cJSON_AddItemReferenceToObject
Trace2Pass: Instrumenting function: cJSON_AddNullToObject
Trace2Pass: Instrumenting function: cJSON_CreateNull
Trace2Pass: Instrumenting function: cJSON_AddTrueToObject
Trace2Pass: Instrumenting function: cJSON_CreateTrue
Trace2Pass: Instrumenting function: cJSON_AddFalseToObject
Trace2Pass: Instrumenting function: cJSON_CreateFalse
Trace2Pass: Instrumenting function: cJSON_AddBoolToObject
Trace2Pass: Instrumenting function: cJSON_CreateBool
Trace2Pass: Instrumenting function: cJSON_AddNumberToObject
Trace2Pass: Instrumenting function: cJSON_CreateNumber
Trace2Pass: Instrumenting function: cJSON_AddStringToObject
Trace2Pass: Instrumenting function: cJSON_CreateString
Trace2Pass: Instrumenting function: cJSON_AddRawToObject
Trace2Pass: Instrumenting function: cJSON_CreateRaw
Trace2Pass: Instrumenting function: cJSON_AddObjectToObject
Trace2Pass: Instrumenting function: cJSON_CreateObject
Trace2Pass: Instrumenting function: cJSON_AddArrayToObject
Trace2Pass: Instrumenting function: cJSON_CreateArray
Trace2Pass: Instrumenting function: cJSON_DetachItemViaPointer
Trace2Pass: Instrumenting function: cJSON_DetachItemFromArray
Trace2Pass: Instrumenting function: cJSON_DeleteItemFromArray
Trace2Pass: Instrumenting function: cJSON_DetachItemFromObject
Trace2Pass: Instrumenting function: cJSON_DetachItemFromObjectCaseSensitive
Trace2Pass: Instrumenting function: cJSON_DeleteItemFromObject
Trace2Pass: Instrumenting function: cJSON_DeleteItemFromObjectCaseSensitive
Trace2Pass: Instrumenting function: cJSON_InsertItemInArray
Trace2Pass: Instrumenting function: cJSON_ReplaceItemViaPointer
Trace2Pass: Instrumenting function: cJSON_ReplaceItemInArray
Trace2Pass: Instrumenting function: cJSON_ReplaceItemInObject
Trace2Pass: Instrumenting function: replace_item_in_object
Trace2Pass: Instrumenting function: cJSON_ReplaceItemInObjectCaseSensitive
Trace2Pass: Instrumenting function: cJSON_CreateStringReference
Trace2Pass: Instrumenting function: cast_away_const
Trace2Pass: Instrumenting function: cJSON_CreateObjectReference
Trace2Pass: Instrumenting function: cJSON_CreateArrayReference
Trace2Pass: Instrumenting function: cJSON_CreateIntArray
Trace2Pass: Instrumenting function: suffix_object
Trace2Pass: Instrumenting function: cJSON_CreateFloatArray
Trace2Pass: Instrumenting function: cJSON_CreateDoubleArray
Trace2Pass: Instrumenting function: cJSON_CreateStringArray
Trace2Pass: Instrumenting function: cJSON_Duplicate
Trace2Pass: Instrumenting function: cJSON_Duplicate_rec
Trace2Pass: Instrumenting function: cJSON_Minify
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in cJSON_Minify
Trace2Pass: Instrumenting function: skip_oneline_comment
Trace2Pass: Instrumenting function: skip_multiline_comment
Trace2Pass: Instrumenting function: minify_string
Trace2Pass: Instrumenting function: cJSON_IsInvalid
Trace2Pass: Instrumenting function: cJSON_IsFalse
Trace2Pass: Instrumenting function: cJSON_IsTrue
Trace2Pass: Instrumenting function: cJSON_IsBool
Trace2Pass: Instrumenting function: cJSON_IsNull
Trace2Pass: Instrumenting function: cJSON_IsArray
Trace2Pass: Instrumenting function: cJSON_IsObject
Trace2Pass: Instrumenting function: cJSON_IsRaw
Trace2Pass: Instrumenting function: cJSON_Compare
Trace2Pass: Instrumenting function: compare_double
Trace2Pass: Instrumenting function: cJSON_malloc
Trace2Pass: Instrumenting function: update_offset
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in update_offset
Trace2Pass: Instrumenting function: parse_string
Trace2Pass: Instrumenting function: parse_number
Trace2Pass: Instrumenting function: parse_array
Trace2Pass: Instrumenting function: parse_object
Trace2Pass: Instrumenting function: utf16_literal_to_utf8
Trace2Pass: Instrumented 3 arithmetic operations in utf16_literal_to_utf8
Trace2Pass: Instrumenting function: parse_hex4
Trace2Pass: Instrumented 1 arithmetic operations in parse_hex4
Trace2Pass: Instrumenting function: get_decimal_point
Trace2Pass: Instrumenting function: ensure
Trace2Pass: Instrumenting function: print_number
Trace2Pass: Instrumenting function: print_string
Trace2Pass: Instrumenting function: print_array
Trace2Pass: Instrumenting function: print_object
Trace2Pass: Instrumenting function: print_string_ptr
Trace2Pass: Instrumenting function: case_insensitive_strcmp
Trace2Pass: Instrumented 1 arithmetic operations in case_insensitive_strcmp
4 warnings generated.
Trace2Pass: Injected build metadata: opt_level=unknown, flags=(none)
Trace2Pass: Instrumenting function: main
Trace2Pass: Instrumenting function: create_objects
Trace2Pass: Instrumented 2 arithmetic operations, 6 unreachable blocks in create_objects
Trace2Pass: Instrumenting function: print_preallocated
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in print_preallocated
=== TEST OUTPUT START ===
Trace2Pass: Runtime initialized (sample_rate=0.010, opt_level=unknown)
Trace2Pass: Runtime shutting down
Version: 1.7.19
{
	"name":	"Jack (\"Bee\") Nimble",
	"format":	{
		"type":	"rect",
```

### tinyexpr with O3_fastmath
- Baseline exit: 0, Aggressive exit: 1
- Status: CANDIDATE_exit
- Trace2Pass anomalies:
```
Trace2Pass: Injected build metadata: opt_level=unknown, flags=(none)
Trace2Pass: Instrumenting function: te_free_parameters
Trace2Pass: Instrumenting function: te_free
Trace2Pass: Instrumenting function: next_token
Trace2Pass: Instrumenting function: find_lookup
Trace2Pass: Instrumented 1 arithmetic operations in find_lookup
Trace2Pass: Instrumenting function: find_builtin
Trace2Pass: Instrumented 5 arithmetic operations, 1 division checks in find_builtin
Trace2Pass: Instrumenting function: add
Trace2Pass: Instrumenting function: sub
Trace2Pass: Instrumenting function: mul
Trace2Pass: Instrumenting function: divide
Trace2Pass: Instrumenting function: te_eval
Trace2Pass: Instrumenting function: te_compile
Trace2Pass: Instrumenting function: list
Trace2Pass: Instrumenting function: optimize
Trace2Pass: Instrumented 1 arithmetic operations in optimize
Trace2Pass: Instrumenting function: te_interp
Trace2Pass: Instrumenting function: te_print
Trace2Pass: Instrumenting function: pn
Trace2Pass: Instrumented 3 arithmetic operations in pn
Trace2Pass: Instrumenting function: e
Trace2Pass: Instrumenting function: fac
Trace2Pass: Instrumented 0 arithmetic operations, 1 division checks in fac
Trace2Pass: Instrumenting function: ncr
Trace2Pass: Instrumented 0 arithmetic operations, 3 division checks in ncr
Trace2Pass: Instrumenting function: npr
Trace2Pass: Instrumenting function: pi
Trace2Pass: Instrumenting function: expr
Trace2Pass: Instrumenting function: new_expr
Trace2Pass: Instrumenting function: comma
Trace2Pass: Instrumenting function: term
Trace2Pass: Instrumenting function: factor
Trace2Pass: Instrumenting function: power
Trace2Pass: Instrumented 1 arithmetic operations in power
Trace2Pass: Instrumenting function: base
Trace2Pass: Instrumented 2 arithmetic operations in base
Trace2Pass: Instrumenting function: negate
20 warnings generated.
/tmp/tinyexpr_test.c:18:10: warning: use of infinity is undefined behavior due to the currently enabled floating-point options [-Wnan-infinity-disabled]
   18 |     if (!isinf(r)) { printf("FAIL: 1/0=%f (expected inf)\n", r); return 1; }
      |          ^~~~~~~~
/usr/include/math.h:1029:20: note: expanded from macro 'isinf'
--
Trace2Pass: Injected build metadata: opt_level=unknown, flags=(none)
Trace2Pass: Instrumenting function: main
2 warnings generated.
=== TEST OUTPUT START ===
Trace2Pass: Runtime initialized (sample_rate=0.010, opt_level=unknown)
Trace2Pass: Runtime shutting down
FAIL: 1/0=inf (expected inf)
TEST_EXIT_CODE=1
=== TEST OUTPUT END ===
```

### tinyexpr with O3_fastmath_fma
- Baseline exit: 0, Aggressive exit: 1
- Status: CANDIDATE_exit
- Trace2Pass anomalies:
```
Trace2Pass: Injected build metadata: opt_level=unknown, flags=(none)
Trace2Pass: Instrumenting function: te_free_parameters
Trace2Pass: Instrumenting function: te_free
Trace2Pass: Instrumenting function: next_token
Trace2Pass: Instrumenting function: find_lookup
Trace2Pass: Instrumented 1 arithmetic operations in find_lookup
Trace2Pass: Instrumenting function: find_builtin
Trace2Pass: Instrumented 5 arithmetic operations, 1 division checks in find_builtin
Trace2Pass: Instrumenting function: add
Trace2Pass: Instrumenting function: sub
Trace2Pass: Instrumenting function: mul
Trace2Pass: Instrumenting function: divide
Trace2Pass: Instrumenting function: te_eval
Trace2Pass: Instrumenting function: te_compile
Trace2Pass: Instrumenting function: list
Trace2Pass: Instrumenting function: optimize
Trace2Pass: Instrumented 1 arithmetic operations in optimize
Trace2Pass: Instrumenting function: te_interp
Trace2Pass: Instrumenting function: te_print
Trace2Pass: Instrumenting function: pn
Trace2Pass: Instrumented 3 arithmetic operations in pn
Trace2Pass: Instrumenting function: e
Trace2Pass: Instrumenting function: fac
Trace2Pass: Instrumented 0 arithmetic operations, 1 division checks in fac
Trace2Pass: Instrumenting function: ncr
Trace2Pass: Instrumented 0 arithmetic operations, 3 division checks in ncr
Trace2Pass: Instrumenting function: npr
Trace2Pass: Instrumenting function: pi
Trace2Pass: Instrumenting function: expr
Trace2Pass: Instrumenting function: new_expr
Trace2Pass: Instrumenting function: comma
Trace2Pass: Instrumenting function: term
Trace2Pass: Instrumenting function: factor
Trace2Pass: Instrumenting function: power
Trace2Pass: Instrumented 1 arithmetic operations in power
Trace2Pass: Instrumenting function: base
Trace2Pass: Instrumented 2 arithmetic operations in base
Trace2Pass: Instrumenting function: negate
20 warnings generated.
/tmp/tinyexpr_test.c:18:10: warning: use of infinity is undefined behavior due to the currently enabled floating-point options [-Wnan-infinity-disabled]
   18 |     if (!isinf(r)) { printf("FAIL: 1/0=%f (expected inf)\n", r); return 1; }
      |          ^~~~~~~~
/usr/include/math.h:1029:20: note: expanded from macro 'isinf'
--
Trace2Pass: Injected build metadata: opt_level=unknown, flags=(none)
Trace2Pass: Instrumenting function: main
2 warnings generated.
=== TEST OUTPUT START ===
Trace2Pass: Runtime initialized (sample_rate=0.010, opt_level=unknown)
Trace2Pass: Runtime shutting down
FAIL: 1/0=inf (expected inf)
TEST_EXIT_CODE=1
=== TEST OUTPUT END ===
```

### fmt with O3_fastmath
- Baseline exit: 0, Aggressive exit: 1
- Status: CANDIDATE_exit
- Trace2Pass anomalies:
```
Trace2Pass: Injected build metadata: opt_level=unknown, flags=(none)
Trace2Pass: Instrumenting function: __cxx_global_var_init
Trace2Pass: Instrumenting function: main
Trace2Pass: Instrumenting function: _ZN3fmt3v126formatIJRA6_KcEEENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEENS0_7fstringIJDpT_EE1tEDpOSC_
Trace2Pass: Instrumenting function: _ZN3fmt3v127fstringIJRA6_KcEEC2ILm11EEERAT__S2_
Trace2Pass: Instrumenting function: _ZStneIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EEPKS5_
Trace2Pass: Instrumenting function: _ZStlsIcSt11char_traitsIcESaIcEERSt13basic_ostreamIT_T0_ES7_RKNSt7__cxx1112basic_stringIS4_S5_T1_EE
Trace2Pass: Instrumenting function: _ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc
Trace2Pass: Instrumenting function: _ZNSolsEPFRSoS_E
Trace2Pass: Instrumenting function: _ZSt4endlIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126formatIJiEEENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEENS0_7fstringIJDpT_EE1tEDpOS9_
Trace2Pass: Instrumenting function: _ZN3fmt3v127fstringIJiEEC2ILm7EEERAT__Kc
Trace2Pass: Instrumenting function: _ZN3fmt3v126formatIJdEEENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEENS0_7fstringIJDpT_EE1tEDpOS9_
Trace2Pass: Instrumenting function: _ZN3fmt3v127fstringIJdEEC2ILm7EEERAT__Kc
Trace2Pass: Instrumenting function: _ZN3fmt3v126formatIJRdEEENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEENS0_7fstringIJDpT_EE1tEDpOSA_
Trace2Pass: Instrumenting function: _ZN3fmt3v127fstringIJRdEEC2ILm3EEERAT__Kc
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev
Trace2Pass: Instrumenting function: __cxx_global_var_init.15
Trace2Pass: Instrumenting function: _ZNSt6locale2idC2Ev
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
Trace2Pass: Instrumenting function: __clang_call_terminate
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in __clang_call_terminate
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE11_M_is_localEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_destroyEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_destroyEm
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7_M_dataEv
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_M_local_dataEv
Trace2Pass: Instrumenting function: _ZNSt19__ptr_traits_ptr_toIPKcS0_Lb0EE10pointer_toERS0_
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsISaIcEE10deallocateERS0_Pcm
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE16_M_get_allocatorEv
Trace2Pass: Instrumenting function: _ZNSt15__new_allocatorIcE10deallocateEPcm
Trace2Pass: Instrumenting function: _ZN3fmt3v127vformatB5cxx11ENS0_17basic_string_viewIcEENS0_17basic_format_argsINS0_7contextEEE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2EPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_format_argsINS0_7contextEEC2ILi1ELi0ELy12ETnNSt9enable_ifIXleT_LNS0_6detail3$_0E15EEiE4typeELi0EEERKNS6_16format_arg_storeIS2_XT_EXT0_EXT1_EEE
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEEC2ERKS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10vformat_toERNS1_6bufferIcEENS0_17basic_string_viewIcEENS0_17basic_format_argsINS0_7contextEEENS0_10locale_refE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail10vformat_toERNS1_6bufferIcEENS0_17basic_string_viewIcEENS0_17basic_format_argsINS0_7contextEEENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v1210locale_refC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v129to_stringILm500EEENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEERKNS0_19basic_memory_bufferIcXT_ENS0_6detail9allocatorIcEEEE
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEED2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEED2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEE4growERNS2_6bufferIcEEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 division checks in _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEE4growERNS2_6bufferIcEEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcEC2EPFvRS3_mEPcmm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE3setEPcm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16abort_fuzzing_ifEb
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIcEEE8max_sizeERKS4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIcEEE8max_sizeERKS4_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIcE8capacityEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126max_ofImEET_S2_S2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE4dataEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIcE8allocateEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks, 1 division checks in _ZN3fmt3v126detail9allocatorIcE8allocateEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6assumeEb
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIcE4sizeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIcE10deallocateEPcm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13ignore_unusedIJbEEEvDpRKT_
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIcEEE11_S_max_sizeIKS4_EEmRT_z
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9max_valueImEET_v
Trace2Pass: Instrumenting function: _ZN3fmt3v1211assert_failEPKciS2_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1211assert_failEPKciS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8allocateEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail8allocateEm
Trace2Pass: Instrumenting function: _ZNSt14numeric_limitsImE3maxEv
Trace2Pass: Instrumenting function: _ZNSt9bad_allocC2Ev
Trace2Pass: Instrumenting function: _ZNSt9exceptionC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1214basic_appenderIcEC2ERNS0_6detail6bufferIcEE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcE4sizeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6equal2EPKcS3_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcE4dataEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE3getEi
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE5visitINS0_6detail21default_arg_formatterIcEEEEDTclfp_Li0EEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19parse_format_stringIcNS1_14format_handlerIcEEEEvNS0_17basic_string_viewIT_EEOT0_
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail19parse_format_stringIcNS1_14format_handlerIcEEEEvNS0_17basic_string_viewIT_EEOT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcEC2ENS0_17basic_string_viewIcEEi
Trace2Pass: Instrumenting function: _ZN3fmt3v127contextC2ENS0_14basic_appenderIcEENS0_17basic_format_argsIS1_EENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE9is_packedEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE8max_sizeEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE4typeEi
Trace2Pass: Instrumented 2 arithmetic operations in _ZNK3fmt3v1217basic_format_argsINS0_7contextEE4typeEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v129monostateC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIiTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIjTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIxTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIyTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclInTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail3mapEn
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIoTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail3mapEo
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIbTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIcTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIfTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIdTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIeTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIPKcTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclINS0_17basic_string_viewIcEETnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail12string_valueIcE3strEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIPKvTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclENS0_16basic_format_argINS0_7contextEE6handleE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEE6handleC2ENS0_6detail12custom_valueIS2_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclENS0_9monostateE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail21default_arg_formatterIcEclENS0_9monostateE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEiTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIiTnNSt9enable_ifIXsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10to_pointerIcEEPT_NS0_14basic_appenderIS3_EEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcjEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v1214basic_appenderIcEppEi
Trace2Pass: Instrumenting function: _ZN3fmt3v1214basic_appenderIcEdeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1214basic_appenderIcEaSEc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcjNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_decimalIcjNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15do_count_digitsEj
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail15do_count_digitsEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13get_containerINS0_14basic_appenderIcEEEERNT_14container_typeES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE11try_reserveEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE10try_resizeEm
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail13get_containerINS0_14basic_appenderIcEEEERNT_14container_typeES5_EN8accessorC2ES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126min_ofImEET_S2_S2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17do_format_decimalIcjEEPT_S4_T0_i
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail17do_format_decimalIcjEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11to_unsignedIiEENSt13make_unsignedIT_E4typeES4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail11to_unsignedIiEENSt13make_unsignedIT_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14write2digits_iIcEEvPT_m
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write2digitsIcEEvPT_m
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9digits2_iEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7digits2Em
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE9push_backERKc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13copy_noinlineIcPcNS0_14basic_appenderIcEEEET1_T0_S7_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIcPcNS0_14basic_appenderIcEETnNSt9enable_ifIXaasr23is_back_insert_iteratorIT1_EE5valuesr41has_back_insert_iterator_container_appendIS7_T0_EE5valueEiE4typeELi0EEES7_S8_S8_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE6appendIcEEvPKT_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11to_unsignedIlEENSt13make_unsignedIT_E4typeES4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail11to_unsignedIlEENSt13make_unsignedIT_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEjTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIjTnNSt9enable_ifIXntsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEExTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIxTnNSt9enable_ifIXsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcmEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcmNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_decimalIcmNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15do_count_digitsEm
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail15do_count_digitsEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17do_format_decimalIcmEEPT_S4_T0_i
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks, 2 division checks in _ZN3fmt3v126detail17do_format_decimalIcmEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEyTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIyTnNSt9enable_ifIXntsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEnTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeInTnNSt9enable_ifIXsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsEo
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcoEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcoNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_decimalIcoNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21count_digits_fallbackIoEEiT_
Trace2Pass: Instrumented 4 arithmetic operations, 1 division checks in _ZN3fmt3v126detail21count_digits_fallbackIoEEiT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17do_format_decimalIcoEEPT_S4_T0_i
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks, 2 division checks in _ZN3fmt3v126detail17do_format_decimalIcoEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEoTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIoTnNSt9enable_ifIXntsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEbTnNSt9enable_ifIXsr3std7is_sameIT1_bEE5valueEiE4typeELi0EEET0_S9_S6_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_specsC2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs4typeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIciTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_bytesIcLNS0_5alignE1ENS0_14basic_appenderIcEEEET1_S6_NS0_17basic_string_viewIcEERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_string_viewIcEC2EPKc
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs9localizedEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_locENS0_14basic_appenderIcEENS0_9loc_valueERKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IiTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18write_int_noinlineIcNS0_14basic_appenderIcEEjEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIiEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs4signEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v1211basic_specs4signEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1210locale_ref3getISt6localeEET_v
Trace2Pass: Instrumenting function: _ZSt9has_facetIN3fmt3v1212format_facetISt6localeEEEbRKS3_
Trace2Pass: Instrumenting function: _ZSt9use_facetIN3fmt3v1212format_facetISt6localeEEERKT_RKS3_
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in _ZSt9use_facetIN3fmt3v1212format_facetISt6localeEEERKT_RKS3_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1212format_facetISt6localeE3putENS0_14basic_appenderIcEENS0_9loc_valueERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_facetISt6localeEC2ERS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_facetISt6localeED2Ev
Trace2Pass: Instrumenting function: _ZNSt6locale5facetC2Em
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2Ev
Trace2Pass: Instrumenting function: _ZNKSt7__cxx118numpunctIcE8groupingEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEaSEOS4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEaSEOS4_
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5emptyEv
Trace2Pass: Instrumenting function: _ZNKSt7__cxx118numpunctIcE13thousands_sepEv
Trace2Pass: Instrumenting function: _ZNSaIcEC2Ev
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2IS3_EEmcRKS3_
Trace2Pass: Instrumenting function: _ZNSt15__new_allocatorIcED2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_facetISt6localeED0Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1212format_facetISt6localeE6do_putENS0_14basic_appenderIcEENS0_9loc_valueERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_M_local_dataEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_Alloc_hiderC2EPcOS3_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE17_M_use_local_dataEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_M_set_lengthEm
Trace2Pass: Instrumenting function: _ZNSt19__ptr_traits_ptr_toIPccLb0EE10pointer_toERc
Trace2Pass: Instrumenting function: _ZNSt15__new_allocatorIcEC2ERKS0_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_lengthEm
Trace2Pass: Instrumenting function: _ZNSt11char_traitsIcE6assignERcRKc
Trace2Pass: Instrumenting function: _ZN9__gnu_cxx14__alloc_traitsISaIcEcE15_S_always_equalEv
Trace2Pass: Instrumenting function: _ZStneRKSaIcES1_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7_M_dataEPc
Trace2Pass: Instrumenting function: _ZSt15__alloc_on_moveISaIcEEvRT_S2_
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4sizeEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7_S_copyEPcPKcm
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6lengthEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE11_M_capacityEm
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5clearEv
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5clearEv
Trace2Pass: Instrumenting function: _ZNSt11char_traitsIcE4copyEPcPKcm
Trace2Pass: Instrumenting function: _ZNSt15__new_allocatorIcEC2Ev
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_Alloc_hiderC2EPcRKS3_
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_value5visitINS0_6detail10loc_writerIcEEEEDTclfp_Li0EEEOT_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2ERKS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcED2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE5visitIRNS0_6detail10loc_writerIcEEEEDTclfp_Li0EEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIiTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIjTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIxTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIyTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclInTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIoTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIbTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIfTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIdTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIeTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIPKcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclINS0_17basic_string_viewIcEETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIPKvTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclINS0_16basic_format_argINS0_7contextEE6handleETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbSA_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclINS0_9monostateETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEmcEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EE
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEmcEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14digit_groupingIcEC2ENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEES9_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14digit_groupingIcED2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs3altEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13prefix_appendERjj
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail13prefix_appendERjj
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs5upperEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi4EmEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_base2eIcNS0_14basic_appenderIcEEmTnNSt9enable_ifIXsr23is_back_insert_iteratorIT0_EE5valueEiE4typeELi0EEES6_iS6_T1_ib
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail13format_base2eIcNS0_14basic_appenderIcEEmTnNSt9enable_ifIXsr23is_back_insert_iteratorIT0_EE5valueEiE4typeELi0EEES6_iS6_T1_ib
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi3EmEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi1EmEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10write_charIcNS0_14basic_appenderIcEEEET0_S5_T_RKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail14digit_groupingIcE16count_separatorsEi
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v126detail14digit_groupingIcE16count_separatorsEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIS5_mcEET_S7_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEEUlS5_E_EESD_SD_SB_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIS5_mcEET_S7_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEEUlS5_E_EESD_SD_SB_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi4EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi4EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_base2eIcmEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16do_format_base2eIcmEEPT_iS4_T0_ib
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail16do_format_base2eIcmEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi3EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi3EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi1EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi1EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEEZNS1_10write_charIcS5_EET0_S7_T_RKNS0_12format_specsEEUlS5_E_EET1_SD_SB_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_10write_charIcS5_EET0_S7_T_RKNS0_12format_specsEEUlS5_E_EET1_SE_SB_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_10write_charIcS5_EET0_S7_T_RKNS0_12format_specsEEUlS5_E_EET1_SE_SB_mmOT2_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs5alignEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v1211basic_specs5alignEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7reserveIcEENS0_14basic_appenderIT_EES5_m
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs9fill_sizeEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v1211basic_specs9fill_sizeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4fillIcNS0_14basic_appenderIcEEEET0_S5_mRKNS0_11basic_specsE
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail10write_charIcNS0_14basic_appenderIcEEEET0_S5_T_RKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13base_iteratorINS0_14basic_appenderIcEEEET_S5_S5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nINS0_14basic_appenderIcEEmcEET_S5_T0_RKT1_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs9fill_unitIcEET_v
Trace2Pass: Instrumented 2 arithmetic operations in _ZNK3fmt3v1211basic_specs9fill_unitIcEET_v
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs4fillIcTnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEEPKS4_v
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIcPKcNS0_14basic_appenderIcEETnNSt9enable_ifIXaasr23is_back_insert_iteratorIT1_EE5valuesr41has_back_insert_iterator_container_appendIS8_T0_EE5valueEiE4typeELi0EEES8_S9_S9_S8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18write_escaped_charIcNS0_14basic_appenderIcEEEET0_S5_T_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12needs_escapeEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16write_escaped_cpINS0_14basic_appenderIcEEcEET_S5_RKNS1_18find_escape_resultIT0_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12is_printableEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12is_printableEtPKNS1_9singletonEmPKhS6_m
Trace2Pass: Instrumented 5 arithmetic operations in _ZN3fmt3v126detail12is_printableEtPKNS1_9singletonEmPKhS6_m
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm2EcNS0_14basic_appenderIcEEEET1_S5_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm4EcNS0_14basic_appenderIcEEEET1_S5_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm8EcNS0_14basic_appenderIcEEEET1_S5_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_string_viewIcEC2EPKcm
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcE5beginEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcE3endEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nIcmEEPT_S4_T0_c
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_base2eIcjEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11to_unsignedImEENSt13make_unsignedIT_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16do_format_base2eIcjEEPT_iS4_T0_ib
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail16do_format_base2eIcjEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail14digit_groupingIcE13initial_stateEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail14digit_groupingIcE4nextERNS3_10next_stateE
Trace2Pass: Instrumented 2 arithmetic operations in _ZNK3fmt3v126detail14digit_groupingIcE4nextERNS3_10next_stateE
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5beginEv
Trace2Pass: Instrumenting function: _ZN9__gnu_cxx17__normal_iteratorIPKcNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEEC2ERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9max_valueIiEET_v
Trace2Pass: Instrumenting function: _ZN9__gnu_cxxeqIPKcNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEEEbRKNS_17__normal_iteratorIT_T0_EESE_
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE3endEv
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4backEv
Trace2Pass: Instrumenting function: _ZNK9__gnu_cxx17__normal_iteratorIPKcNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEEdeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9max_valueIcEET_v
Trace2Pass: Instrumenting function: _ZN9__gnu_cxx17__normal_iteratorIPKcNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEEppEi
Trace2Pass: Instrumenting function: _ZNSt14numeric_limitsIiE3maxEv
Trace2Pass: Instrumenting function: _ZNK9__gnu_cxx17__normal_iteratorIPKcNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEE4baseEv
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEixEm
Trace2Pass: Instrumenting function: _ZNSt14numeric_limitsIcE3maxEv
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEmcEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEENKUlS4_E_clES4_
Trace2Pass: Instrumented 1 arithmetic operations in _ZZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEmcEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail14digit_groupingIcE5applyINS0_14basic_appenderIcEEcEET_S7_NS0_17basic_string_viewIT0_EE
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZNK3fmt3v126detail14digit_groupingIcE5applyINS0_14basic_appenderIcEEcEET_S7_NS0_17basic_string_viewIT0_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEEC2ERKS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiE9push_backERKi
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIiE4sizeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiEixIiEERiT_
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4dataEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcEixEm
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEED2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEED2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEE4growERNS2_6bufferIiEEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 division checks in _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEE4growERNS2_6bufferIiEEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiEC2EPFvRS3_mEPimm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiE3setEPim
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIiEEE8max_sizeERKS4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIiEEE8max_sizeERKS4_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIiE8capacityEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiE4dataEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIiE8allocateEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks, 1 division checks in _ZN3fmt3v126detail9allocatorIiE8allocateEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIiE10deallocateEPim
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIiEEE11_S_max_sizeIKS4_EEmRT_z
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiE11try_reserveEm
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEE10deallocateEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EOS4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EOS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIjEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIxEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIyEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argInEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEocEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EE
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEocEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi4EoEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_base2eIcNS0_14basic_appenderIcEEoTnNSt9enable_ifIXsr23is_back_insert_iteratorIT0_EE5valueEiE4typeELi0EEES6_iS6_T1_ib
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail13format_base2eIcNS0_14basic_appenderIcEEoTnNSt9enable_ifIXsr23is_back_insert_iteratorIT0_EE5valueEiE4typeELi0EEES6_iS6_T1_ib
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi3EoEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi1EoEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIS5_ocEET_S7_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEEUlS5_E_EESD_SD_SB_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIS5_ocEET_S7_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEEUlS5_E_EESD_SD_SB_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi4EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi4EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_base2eIcoEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16do_format_base2eIcoEEPT_iS4_T0_ib
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail16do_format_base2eIcoEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi3EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi3EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi1EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi1EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEocEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEENKUlS4_E_clES4_
Trace2Pass: Instrumented 1 arithmetic operations in _ZZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEocEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIoEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN9__gnu_cxx14__alloc_traitsISaIcEcE17_S_select_on_copyERKS1_
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE16_M_get_allocatorEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsISaIcEE37select_on_container_copy_constructionERKS0_
Trace2Pass: Instrumenting function: _ZNSaIcEC2ERKS_
Trace2Pass: Instrumenting function: _ZSt8distanceIPcENSt15iterator_traitsIT_E15difference_typeES2_S2_
Trace2Pass: Instrumenting function: _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tagEN6_GuardC2EPS4_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcS5_S5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcS5_S5_
Trace2Pass: Instrumenting function: _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tagEN6_GuardD2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tagEN6_GuardD2Ev
Trace2Pass: Instrumenting function: _ZSt10__distanceIPcENSt15iterator_traitsIT_E15difference_typeES2_S2_St26random_access_iterator_tag
Trace2Pass: Instrumenting function: _ZSt19__iterator_categoryIPcENSt15iterator_traitsIT_E17iterator_categoryERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRiEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEjEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumented 5 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEjEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12size_paddingC2EijRKNS0_12format_specsE
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail12size_paddingC2EijRKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIcS5_jEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_jEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_jEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEjEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumented 1 arithmetic operations in _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEjEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nINS0_14basic_appenderIcEEjcEET_S5_T0_RKT1_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEEZNS1_11write_bytesIcLS3_1ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_11write_bytesIcLS3_1ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_11write_bytesIcLS3_1ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_bytesIcLNS0_5alignE1ENS0_14basic_appenderIcEEEET1_S6_NS0_17basic_string_viewIcEERKNS0_12format_specsEENKUlS5_E_clES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6narrowEPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specsC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_T_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEfTnNSt9enable_ifIXsr13is_fast_floatIT1_EE5valueEiE4typeELi0EEET0_S9_S6_
Trace2Pass: Instrumented 8 arithmetic operations, 2 division checks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEfTnNSt9enable_ifIXsr13is_fast_floatIT1_EE5valueEiE4typeELi0EEET0_S9_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7signbitIfTnNSt9enable_ifIXsr17is_floating_pointIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_maskIfEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail13exponent_maskIfEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8bit_castIjfTnNSt9enable_ifIXeqstT_stT0_EiE4typeELi0EEES4_RKS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_nonfiniteIcNS0_14basic_appenderIcEEEET0_S5_bNS0_12format_specsENS0_4signE
Trace2Pass: Instrumenting function: _ZSt5isnanf
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox10to_decimalIfEENS2_10decimal_fpIT_EES5_
Trace2Pass: Instrumented 16 arithmetic operations, 1 unreachable blocks, 3 division checks in _ZN3fmt3v126detail9dragonbox10to_decimalIfEENS2_10decimal_fpIT_EES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9use_fixedEii
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9exp_upperIfEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6selectILb0EPcNS0_14basic_appenderIcEETnNSt9enable_ifIXntT_EiE4typeELi0EEET1_T0_S9_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEjcTnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_iiT1_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14write_exponentIcNS0_14basic_appenderIcEEEET0_iS5_
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks, 2 division checks in _ZN3fmt3v126detail14write_exponentIcNS0_14basic_appenderIcEEEET0_iS5_
Trace2Pass: Instrumenting function: _ZSt7signbitd
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20num_significand_bitsIfEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs8set_fillEc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEEZNS1_15write_nonfiniteIcS5_EET0_S7_bNS0_12format_specsENS0_4signEEUlS5_E_EET1_SB_RKS8_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs13set_fill_sizeEm
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v1211basic_specs13set_fill_sizeEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_15write_nonfiniteIcS5_EET0_S7_bNS0_12format_specsENS0_4signEEUlS5_E_EET1_SC_RKS8_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_15write_nonfiniteIcS5_EET0_S7_bNS0_12format_specsENS0_4signEEUlS5_E_EET1_SC_RKS8_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail15write_nonfiniteIcNS0_14basic_appenderIcEEEET0_S5_bNS0_12format_specsENS0_4signEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7getsignIcEET_NS0_4signE
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail7getsignIcEET_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_biasIfEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox21shorter_interval_caseIfEENS2_10decimal_fpIT_EEi
Trace2Pass: Instrumented 5 arithmetic operations, 2 division checks in _ZN3fmt3v126detail9dragonbox21shorter_interval_caseIfEENS2_10decimal_fpIT_EEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox16floor_log10_pow2Ei
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox16floor_log10_pow2Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE16get_cached_powerEi
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE16get_cached_powerEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox16floor_log2_pow10Ei
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox16floor_log2_pow10Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE13compute_deltaERKmi
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE13compute_deltaERKmi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE11compute_mulEjRKm
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE11compute_mulEjRKm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox28divide_by_10_to_kappa_plus_1Ej
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail9dragonbox28divide_by_10_to_kappa_plus_1Ej
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE18compute_mul_parityEjRKmi
Trace2Pass: Instrumented 4 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE18compute_mul_parityEjRKmi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox21remove_trailing_zerosERji
Trace2Pass: Instrumented 1 arithmetic operations, 3 unreachable blocks, 2 division checks in _ZN3fmt3v126detail9dragonbox21remove_trailing_zerosERji
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox38check_divisibility_and_divide_by_pow10ILi1EEEbRj
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox38check_divisibility_and_divide_by_pow10ILi1EEEbRj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox37floor_log10_pow2_minus_log10_4_over_3Ei
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox37floor_log10_pow2_minus_log10_4_over_3Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE47compute_left_endpoint_for_shorter_interval_caseERKmi
Trace2Pass: Instrumented 6 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE47compute_left_endpoint_for_shorter_interval_caseERKmi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE48compute_right_endpoint_for_shorter_interval_caseERKmi
Trace2Pass: Instrumented 6 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE48compute_right_endpoint_for_shorter_interval_caseERKmi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox41is_left_endpoint_integer_shorter_intervalIfEEbi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE42compute_round_up_for_shorter_interval_caseERKmi
Trace2Pass: Instrumented 4 arithmetic operations, 1 division checks in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE42compute_round_up_for_shorter_interval_caseERKmi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14umul96_upper64Ejm
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail9dragonbox14umul96_upper64Ejm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox15umul128_upper64Emm
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail9dragonbox15umul128_upper64Emm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14umul96_lower64Ejm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4rotrEjj
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail4rotrEjj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9max_valueIjEET_v
Trace2Pass: Instrumenting function: _ZNSt14numeric_limitsIjE3maxEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126min_ofIiEET_S2_S2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail23fallback_digit_groupingIcEC2ENS0_10locale_refEb
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail23fallback_digit_groupingIcE16count_separatorsEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126max_ofIiEET_S2_S2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEjNS1_23fallback_digit_groupingIcEEEET0_S7_T1_iiRKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nINS0_14basic_appenderIcEEicEET_S5_T0_RKT1_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail6fill_nINS0_14basic_appenderIcEEicEET_S5_T0_RKT1_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail23fallback_digit_groupingIcE13has_separatorEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEjEET0_S5_T1_i
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail23fallback_digit_groupingIcE5applyINS0_14basic_appenderIcEEcEET_S7_NS0_17basic_string_viewIT0_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E0_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcjNS1_23fallback_digit_groupingIcEEEET_S7_T1_iiT0_RKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE3endEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E1_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcjTnNSt9enable_ifIXsr3std11is_integralIT0_EE5valueEiE4typeELi0EEEPT_S8_S4_iiS7_
Trace2Pass: Instrumented 3 arithmetic operations, 6 division checks in _ZN3fmt3v126detail17write_significandIcjTnNSt9enable_ifIXsr3std11is_integralIT0_EE5valueEiE4typeELi0EEEPT_S8_S4_iiS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEdTnNSt9enable_ifIXsr13is_fast_floatIT1_EE5valueEiE4typeELi0EEET0_S9_S6_
Trace2Pass: Instrumented 8 arithmetic operations, 2 division checks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEdTnNSt9enable_ifIXsr13is_fast_floatIT1_EE5valueEiE4typeELi0EEET0_S9_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7signbitIdTnNSt9enable_ifIXsr17is_floating_pointIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_maskIdEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail13exponent_maskIdEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8bit_castImdTnNSt9enable_ifIXeqstT_stT0_EiE4typeELi0EEES4_RKS5_
Trace2Pass: Instrumenting function: _ZSt5isnand
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox10to_decimalIdEENS2_10decimal_fpIT_EES5_
Trace2Pass: Instrumented 16 arithmetic operations, 1 unreachable blocks, 3 division checks in _ZN3fmt3v126detail9dragonbox10to_decimalIdEENS2_10decimal_fpIT_EES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9exp_upperIdEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEmcTnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_iiT1_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20num_significand_bitsIdEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_biasIdEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox21shorter_interval_caseIdEENS2_10decimal_fpIT_EEi
Trace2Pass: Instrumented 5 arithmetic operations, 2 division checks in _ZN3fmt3v126detail9dragonbox21shorter_interval_caseIdEENS2_10decimal_fpIT_EEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE16get_cached_powerEi
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE16get_cached_powerEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE13compute_deltaERKNS1_7uint128Ei
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE13compute_deltaERKNS1_7uint128Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE11compute_mulEmRKNS1_7uint128E
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox28divide_by_10_to_kappa_plus_1Em
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail9dragonbox28divide_by_10_to_kappa_plus_1Em
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE18compute_mul_parityEmRKNS1_7uint128Ei
Trace2Pass: Instrumented 5 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE18compute_mul_parityEmRKNS1_7uint128Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox21remove_trailing_zerosERm
Trace2Pass: Instrumented 1 arithmetic operations, 2 unreachable blocks, 4 division checks in _ZN3fmt3v126detail9dragonbox21remove_trailing_zerosERm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox38check_divisibility_and_divide_by_pow10ILi2EEEbRj
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox38check_divisibility_and_divide_by_pow10ILi2EEEbRj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE47compute_left_endpoint_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumented 6 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE47compute_left_endpoint_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE48compute_right_endpoint_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumented 6 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE48compute_right_endpoint_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox41is_left_endpoint_integer_shorter_intervalIdEEbi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE42compute_round_up_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumented 4 arithmetic operations, 1 division checks in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE42compute_round_up_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail7uint1284highEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox16umul192_upper128EmNS1_7uint128E
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail7uint1283lowEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7umul128Emm
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail7umul128Emm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7uint128pLEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7uint128C2Emm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox16umul192_lower128EmNS1_7uint128E
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox16umul192_lower128EmNS1_7uint128E
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4rotrEmj
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail4rotrEmj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEmNS1_23fallback_digit_groupingIcEEEET0_S7_T1_iiRKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEmEET0_S5_T1_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E0_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcmNS1_23fallback_digit_groupingIcEEEET_S7_T1_iiT0_RKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E1_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcmTnNSt9enable_ifIXsr3std11is_integralIT0_EE5valueEiE4typeELi0EEEPT_S8_S4_iiS7_
Trace2Pass: Instrumented 3 arithmetic operations, 6 division checks in _ZN3fmt3v126detail17write_significandIcmTnNSt9enable_ifIXsr3std11is_integralIT0_EE5valueEiE4typeELi0EEEPT_S8_S4_iiS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEeTnNSt9enable_ifIXaasr17is_floating_pointIT1_EE5valuentsr13is_fast_floatIS6_EE5valueEiE4typeELi0EEET0_S9_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEeTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEeTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IeTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7signbitIeTnNSt9enable_ifIXsr17is_floating_pointIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8isfiniteIeTnNSt9enable_ifIXaasr17is_floating_pointIT_EE5valuesr12has_isfiniteIS4_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5isnanIeEEbT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9exp_upperIeEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15format_hexfloatIeTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEvS4_NS0_12format_specsERNS1_6bufferIcEE
Trace2Pass: Instrumented 18 arithmetic operations in _ZN3fmt3v126detail15format_hexfloatIeTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEvS4_NS0_12format_specsERNS1_6bufferIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13convert_floatIeEENSt11conditionalIXoosr3std7is_sameIT_fEE5valueeqcl8num_bitsIS4_EEclL_ZNS1_8num_bitsIdEEivEEEdS4_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_bytesIcLNS0_5alignE2ENS0_14basic_appenderIcEEEET1_S6_NS0_17basic_string_viewIcEERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v1212report_errorEPKc
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1212report_errorEPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs7set_altEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12format_floatIeEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEE
Trace2Pass: Instrumented 5 arithmetic operations in _ZN3fmt3v126detail12format_floatIeEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEE
Trace2Pass: Instrumenting function: _ZNKSt17integral_constantIbLb0EEcvbEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_floatIcNS0_14basic_appenderIcEENS1_14big_decimal_fpEEET0_S6_RKT1_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IReEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ee
Trace2Pass: Instrumenting function: _ZSt8isfinitee
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpIoEC2IeEET_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11countl_zeroEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpIoE6assignIeTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumented 4 arithmetic operations in _ZN3fmt3v126detail8basic_fpIoE6assignIeTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8bit_castIoeTnNSt9enable_ifIXeqstT_stT0_EiE4typeELi0EEES4_RKS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_maskIeEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail13exponent_maskIeEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_biasIeEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20num_significand_bitsIeEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_bytesIcLS3_2ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_bytesIcLS3_2ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_bytesIcLS3_2ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_bytesIcLNS0_5alignE2ENS0_14basic_appenderIcEEEET1_S6_NS0_17basic_string_viewIcEERKNS0_12format_specsEENKUlS5_E_clES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_errorCI2St13runtime_errorEPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_errorD0Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nIciEEPT_S4_T0_c
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpIoEC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpIoE6assignIfTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail8basic_fpIoE6assignIfTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_dragonENS1_8basic_fpIoEEjiRNS1_6bufferIcEERi
Trace2Pass: Instrumented 29 arithmetic operations, 1 unreachable blocks, 2 division checks in _ZN3fmt3v126detail13format_dragonENS1_8basic_fpIoEEjiRNS1_6bufferIcEERi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcEixImEERcT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintaSIoEEvT_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigintaSIoEEvT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintlSEi
Trace2Pass: Instrumented 4 arithmetic operations, 1 unreachable blocks, 2 division checks in _ZN3fmt3v126detail6bigintlSEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintaSIiEEvT_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigintaSIiEEvT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint12assign_pow10Ei
Trace2Pass: Instrumented 5 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigint12assign_pow10Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint6assignERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintmLIoEERS2_T_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigintmLIoEERS2_T_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintaSIyEEvT_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigintaSIyEEvT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11add_compareERKNS1_6bigintES4_S4_
Trace2Pass: Instrumented 4 arithmetic operations in _ZN3fmt3v126detail11add_compareERKNS1_6bigintES4_S4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintmLIiEERS2_T_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigintmLIiEERS2_T_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16adjust_precisionERii
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail16adjust_precisionERii
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint13divmod_assignERKS2_
Trace2Pass: Instrumented 1 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail6bigint13divmod_assignERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7compareERKNS1_6bigintES4_
Trace2Pass: Instrumented 5 arithmetic operations in _ZN3fmt3v126detail7compareERKNS1_6bigintES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcEixIiEERcT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintD2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEEC2ERKS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE4growERNS2_6bufferIjEEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 division checks in _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE4growERNS2_6bufferIjEEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjEC2EPFvRS3_mEPjmm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE3setEPjm
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIjEEE8max_sizeERKS4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIjEEE8max_sizeERKS4_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIjE8capacityEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE4dataEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIjE8allocateEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks, 1 division checks in _ZN3fmt3v126detail9allocatorIjE8allocateEm
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIjE4sizeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIjE10deallocateEPjm
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIjEEE11_S_max_sizeIKS4_EEmRT_z
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint6assignIoTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail6bigint6assignIoTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjEixImEERjT_
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE6resizeEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE10try_resizeEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE11try_reserveEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE9push_backERKj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint6assignImTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail6bigint6assignImTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8num_bitsIjEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint6squareEv
Trace2Pass: Instrumented 12 arithmetic operations in _ZN3fmt3v126detail6bigint6squareEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEEC2EOS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEEC2EOS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjEixIiEERjT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint20remove_leading_zerosEv
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail6bigint20remove_leading_zerosEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEED2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEED2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE4moveERS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE4moveERS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE10move_allocIS4_TnNSt9enable_ifIXntsr3std16allocator_traitsIT_E38propagate_on_container_move_assignmentE5valueEiE4typeELi0EEEbRS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIjPjS3_TnNSt9enable_ifIXntaasr23is_back_insert_iteratorIT1_EE5valueoosr41has_back_insert_iterator_container_appendIS5_T0_EE5valuesr48has_back_insert_iterator_container_insert_at_endIS5_S6_EE5valueEiE4typeELi0EEES5_S6_S6_S5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE5clearEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detaileqENS1_9allocatorIjEES3_
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE10deallocateEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIjE4dataEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIjPKjPjTnNSt9enable_ifIXntaasr23is_back_insert_iteratorIT1_EE5valueoosr41has_back_insert_iterator_container_appendIS7_T0_EE5valuesr48has_back_insert_iterator_container_insert_at_endIS7_S8_EE5valueEiE4typeELi0EEES7_S8_S8_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint8multiplyIoTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumented 5 arithmetic operations in _ZN3fmt3v126detail6bigint8multiplyIoTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8num_bitsImEEiv
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bigint10num_bigitsEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v126detail6bigint10num_bigitsEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bigint9get_bigitEi
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v126detail6bigint9get_bigitEi
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIjEixIiEERKjT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint8multiplyEj
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail6bigint8multiplyEj
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIjEixImEERKjT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint5alignERKS2_
Trace2Pass: Instrumented 7 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigint5alignERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint16subtract_alignedERKS2_
Trace2Pass: Instrumented 2 arithmetic operations, 3 unreachable blocks in _ZN3fmt3v126detail6bigint16subtract_alignedERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nIPjjjEET_S4_T0_RKT1_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint15subtract_bigitsEijRj
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail6bigint15subtract_bigitsEijRj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumented 7 arithmetic operations in _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13decimal_pointIcEET_NS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20get_significand_sizeERKNS1_14big_decimal_fpE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16compute_exp_sizeEi
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail16compute_exp_sizeEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESA_SA_SG_mOSB_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18decimal_point_implIcEET_NS0_10locale_refE
Trace2Pass: Instrumenting function: _ZNKSt7__cxx118numpunctIcE13decimal_pointEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14digit_groupingIcEC2ENS0_10locale_refEb
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESA_SA_SH_mOSB_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESA_SA_SH_mOSB_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESA_SA_SH_mOSB_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13thousands_sepIcEENS1_20thousands_sep_resultIT_EENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEaSERKS4_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6assignEmc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20thousands_sep_resultIcED2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18thousands_sep_implIcEENS1_20thousands_sep_resultIT_EENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6assignERKS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEPKcNS1_14digit_groupingIcEEEET0_S9_T1_iiRKT2_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail14digit_groupingIcE13has_separatorEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEEET0_S5_PKci
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E0_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcPKcNS1_14digit_groupingIcEEEET_S9_T1_iiT0_RKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcEET_S5_PKciiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13copy_noinlineIcPKcNS0_14basic_appenderIcEEEET1_T0_S8_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E1_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESA_SA_SG_mmOSB_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESA_SA_SG_mmOSB_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_PKT_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_PKT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_NS0_17basic_string_viewIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEvTnNSt9enable_ifIXsr3std7is_sameIT1_vEE5valueEiE4typeELi0EEET0_S9_PKS6_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_ptrIcNS0_14basic_appenderIcEEmEET0_S5_T1_PKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8bit_castImPKvTnNSt9enable_ifIXeqstT_stT0_EiE4typeELi0EEES6_RKS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_ptrIcS5_mEET0_S7_T1_PKNS0_12format_specsEEUlS5_E_EES8_S8_RSA_mOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_ptrIcNS0_14basic_appenderIcEEmEET0_S5_T1_PKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_ptrIcS5_mEET0_S7_T1_PKNS0_12format_specsEEUlS5_E_EES8_S8_RSA_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_ptrIcS5_mEET0_S7_T1_PKNS0_12format_specsEEUlS5_E_EES8_S8_RSA_mmOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_string_viewIcEC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_format_argsINS0_7contextEEC2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE6handle6formatERNS0_13parse_contextIcEERS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE7on_textEPKcS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S8_S8_OT0_
Trace2Pass: Instrumented 0 arithmetic operations, 3 unreachable blocks in _ZN3fmt3v126detail23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S8_S8_OT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE8on_errorEPKc
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_handlerIcE8on_errorEPKc
Trace2Pass: Instrumenting function: _ZNK3fmt3v127context3outEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE20on_replacement_fieldEiPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE9on_arg_idEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12parse_arg_idIcRZNS1_23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S9_S9_OT0_E10id_adapterEES9_S9_S9_SB_
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail12parse_arg_idIcRZNS1_23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S9_S9_OT0_E10id_adapterEES9_S9_S9_SB_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE15on_format_specsEiPKcS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_handlerIcE15on_format_specsEiPKcS5_
Trace2Pass: Instrumenting function: _ZNK3fmt3v127context3argEi
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE11next_arg_idEv
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1213parse_contextIcE11next_arg_idEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE15do_check_arg_idEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21parse_nonnegative_intIcEEiRPKT_S5_i
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail21parse_nonnegative_intIcEEiRPKT_S5_i
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S8_S8_OT0_EN10id_adapter8on_indexEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13is_name_startIcEEbT_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S8_S8_OT0_EN10id_adapter7on_nameENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE9on_arg_idEi
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE12check_arg_idEi
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1213parse_contextIcE12check_arg_idEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE9on_arg_idENS0_17basic_string_viewIcEE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_handlerIcE9on_arg_idENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE12check_arg_idENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZNK3fmt3v127context6arg_idENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE6get_idIcEEiNS0_17basic_string_viewIT_EE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE14has_named_argsEv
Trace2Pass: Instrumenting function: _ZN3fmt3v12eqENS0_17basic_string_viewIcEES2_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcE7compareES2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7compareIcEEiPKT_S5_m
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEEcvbEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEE13format_customEPKcRNS0_13parse_contextIcEERS2_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1213parse_contextIcE5beginEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20dynamic_format_specsIcEC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeE
Trace2Pass: Instrumented 0 arithmetic operations, 4 unreachable blocks in _ZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE4typeEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs7dynamicEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19handle_dynamic_specINS0_7contextEEEvNS0_11arg_id_kindERiRKNS1_7arg_refINT_9char_typeEEERS7_
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail19handle_dynamic_specINS0_7contextEEEvNS0_11arg_id_kindERiRKNS1_7arg_refINT_9char_typeEEERS7_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs13dynamic_widthEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v1211basic_specs13dynamic_widthEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs17dynamic_precisionEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v1211basic_specs17dynamic_precisionEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE5visitINS0_6detail13arg_formatterIcEEEEDTclfp_Li0EEEOT_
Trace2Pass: Instrumenting function: _ZNK3fmt3v127context6localeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE10advance_toEPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_string_viewIcE13remove_prefixEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7arg_refIcEC2Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8to_asciiIcTnNSt9enable_ifIXsr3std11is_integralIT_EE5valueEiE4typeELi0EEEcS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11parse_alignEc
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeEENUt_C2Ev
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeEENUt_clENS1_5stateEb
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeEENUt_clENS1_5stateEb
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs9set_alignENS0_5alignE
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v1211basic_specs9set_alignENS0_5alignE
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs8set_signENS0_4signE
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v1211basic_specs8set_signENS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail2inENS1_4typeEi
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail2inENS1_4typeEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18is_arithmetic_typeENS1_4typeE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11parse_widthIcEEPKT_S5_S5_RNS0_12format_specsERNS1_7arg_refIS3_EERNS0_13parse_contextIS3_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15parse_precisionIcEEPKT_S5_S5_RNS0_12format_specsERNS1_7arg_refIS3_EERNS0_13parse_contextIS3_EE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail15parse_precisionIcEEPKT_S5_S5_RNS0_12format_specsERNS1_7arg_refIS3_EERNS0_13parse_contextIS3_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs13set_localizedEv
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeEENUt0_clENS0_17presentation_typeEi
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeEENUt0_clENS0_17presentation_typeEi
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs9set_upperEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17code_point_lengthIcEEiPKT_
Trace2Pass: Instrumented 4 arithmetic operations in _ZN3fmt3v126detail17code_point_lengthIcEEiPKT_
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs8set_fillIcEEvNS0_17basic_string_viewIT_EE
Trace2Pass: Instrumented 2 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v1211basic_specs8set_fillIcEEvNS0_17basic_string_viewIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18parse_dynamic_specIcEENS1_25parse_dynamic_spec_resultIT_EEPKS4_S7_RiRNS1_7arg_refIS4_EERNS0_13parse_contextIS4_EE
Trace2Pass: Instrumented 0 arithmetic operations, 3 unreachable blocks in _ZN3fmt3v126detail18parse_dynamic_specIcEENS1_25parse_dynamic_spec_resultIT_EEPKS4_S7_RiRNS1_7arg_refIS4_EERNS0_13parse_contextIS4_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs17set_dynamic_widthENS0_11arg_id_kindE
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v1211basic_specs17set_dynamic_widthENS0_11arg_id_kindE
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE18check_dynamic_specEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12parse_arg_idIcNS1_20dynamic_spec_handlerIcEEEEPKT_S7_S7_OT0_
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail12parse_arg_idIcNS1_20dynamic_spec_handlerIcEEEEPKT_S7_S7_OT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20dynamic_spec_handlerIcE8on_indexEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20dynamic_spec_handlerIcE7on_nameENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7arg_refIcEC2ENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs21set_dynamic_precisionENS0_11arg_id_kindE
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v1211basic_specs21set_dynamic_precisionENS0_11arg_id_kindE
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs8set_typeENS0_17presentation_typeE
Trace2Pass: Instrumenting function: _ZNK3fmt3v127context3argENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE5visitINS0_6detail19dynamic_spec_getterEEEDTclfp_Li0EEEOT_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE3getIcEENS0_16basic_format_argIS2_EENS0_17basic_string_viewIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIiTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIjTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIxTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIyTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclInTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIoTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIbTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIbTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIfTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIfTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIdTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIdTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIeTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIeTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIPKcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIPKcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclINS0_17basic_string_viewIcEETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclINS0_17basic_string_viewIcEETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIPKvTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIPKvTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclINS0_16basic_format_argINS0_7contextEE6handleETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS9_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclINS0_16basic_format_argINS0_7contextEE6handleETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS9_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclINS0_9monostateETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS6_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclINS0_9monostateETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIiTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIjTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIxTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIyTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclInTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIoTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIbTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIcTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIfTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIdTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIeTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIPKcTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclINS0_17basic_string_viewIcEETnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIPKvTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclENS0_16basic_format_argINS0_7contextEE6handleE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclINS0_9monostateETnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcjTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IjTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRjEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ej
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcxTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IxTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18write_int_noinlineIcNS0_14basic_appenderIcEEmEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRxEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ex
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEmEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumented 5 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEmEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIcS5_mEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_mEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_mEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEmEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumented 1 arithmetic operations in _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEmEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcyTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IyTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRyEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ey
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcnTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2InTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18write_int_noinlineIcNS0_14basic_appenderIcEEoEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRnEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2En
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEoEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumented 5 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEoEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIcS5_oEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_oEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_oEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEoEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumented 1 arithmetic operations in _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEoEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcoTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IoTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRoEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Eo
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_T_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16check_char_specsERKNS0_12format_specsE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail16check_char_specsERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIchTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IhTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIhEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRhEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Eh
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIhTnNSt9enable_ifIXntsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEfTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEfTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IfTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8isfiniteIfTnNSt9enable_ifIXaasr17is_floating_pointIT_EE5valuesr12has_isfiniteIS4_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5isnanIfEEbT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_floatIcNS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET0_S8_RKT1_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15format_hexfloatIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEvS4_NS0_12format_specsERNS1_6bufferIcEE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail15format_hexfloatIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEvS4_NS0_12format_specsERNS1_6bufferIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13convert_floatIfEENSt11conditionalIXoosr3std7is_sameIT_fEE5valueeqcl8num_bitsIS4_EEclL_ZNS1_8num_bitsIdEEivEEEdS4_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12format_floatIdEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEE
Trace2Pass: Instrumented 36 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail12format_floatIdEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEE
Trace2Pass: Instrumenting function: _ZNKSt17integral_constantIbLb1EEcvbEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRfEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ef
Trace2Pass: Instrumenting function: _ZSt8isfinitef
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumented 7 arithmetic operations in _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20get_significand_sizeIfEEiRKNS1_9dragonbox10decimal_fpIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEjNS1_14digit_groupingIcEEEET0_S7_T1_iiRKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E0_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcjNS1_14digit_groupingIcEEEET_S7_T1_iiT0_RKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E1_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mmOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpImEC2IdEET_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpImE6assignIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail8basic_fpImE6assignIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13convert_floatIdEENSt11conditionalIXoosr3std7is_sameIT_fEE5valueeqcl8num_bitsIS4_EEclL_ZNS1_8num_bitsIdEEivEEEdS4_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11countl_zeroEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox16get_cached_powerEi
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12format_floatIdEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEEENKUljPcE_clEjSA_
Trace2Pass: Instrumented 8 arithmetic operations in _ZZN3fmt3v126detail12format_floatIdEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEEENKUljPcE_clEjSA_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail35fractional_part_rounding_thresholdsEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpIoE6assignIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail8basic_fpIoE6assignIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEdTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEdTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IdTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8isfiniteIdTnNSt9enable_ifIXaasr17is_floating_pointIT_EE5valuesr12has_isfiniteIS4_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5isnanIdEEbT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_floatIcNS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET0_S8_RKT1_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRdEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ed
Trace2Pass: Instrumenting function: _ZSt8isfinited
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumented 7 arithmetic operations in _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20get_significand_sizeIdEEiRKNS1_9dragonbox10decimal_fpIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEmNS1_14digit_groupingIcEEEET0_S7_T1_iiRKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E0_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcmNS1_14digit_groupingIcEEEET_S7_T1_iiT0_RKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E1_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mmOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_PKT_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_PKT_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8bit_castImPKcTnNSt9enable_ifIXeqstT_stT0_EiE4typeELi0EEES6_RKS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_NS0_17basic_string_viewIT_EERKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20write_escaped_stringIcNS0_14basic_appenderIcEEEET0_S5_NS0_17basic_string_viewIT_EE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail20write_escaped_stringIcNS0_14basic_appenderIcEEEET0_S5_NS0_17basic_string_viewIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIccNS0_14basic_appenderIcEEEET1_NS0_17basic_string_viewIT0_EES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18for_each_codepointIZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEEUljNSB_IcEEE_EEvSG_S7_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail18for_each_codepointIZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEEUljNSB_IcEEE_EEvSG_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEEZNS1_5writeIcS5_TnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SB_NS0_17basic_string_viewIS8_EERKNS0_12format_specsEEUlS5_E_EET1_SI_SG_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEEZNS1_5writeIcS5_TnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SB_NS0_17basic_string_viewIS8_EERKNS0_12format_specsEEUlS5_E_EET1_SI_SG_mmOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11find_escapeEPKcS3_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18for_each_codepointIZNS1_11find_escapeEPKcS4_EUljNS0_17basic_string_viewIcEEE_EEvS6_T_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail18for_each_codepointIZNS1_11find_escapeEPKcS4_EUljNS0_17basic_string_viewIcEEE_EEvS6_T_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail18for_each_codepointIZNS1_11find_escapeEPKcS4_EUljNS0_17basic_string_viewIcEEE_EEvS6_T_ENKUlS4_S4_E_clES4_S4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIcPKcPcTnNSt9enable_ifIXntaasr23is_back_insert_iteratorIT1_EE5valueoosr41has_back_insert_iterator_container_appendIS7_T0_EE5valuesr48has_back_insert_iterator_container_insert_at_endIS7_S8_EE5valueEiE4typeELi0EEES7_S8_S8_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11utf8_decodeEPKcPjPi
Trace2Pass: Instrumented 14 arithmetic operations in _ZN3fmt3v126detail11utf8_decodeEPKcPjPi
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11find_escapeEPKcS3_ENKUljNS0_17basic_string_viewIcEEE_clEjS5_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail18for_each_codepointIZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEEUljNSB_IcEEE_EEvSG_S7_ENKUlPKcSJ_E_clESJ_SJ_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsEENKUljNSA_IcEEE_clEjSF_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15counting_bufferIcEC2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail15counting_bufferIcE5countEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16display_width_ofEj
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail16display_width_ofEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15counting_bufferIcE4growERNS1_6bufferIcEEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE5clearEv
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20write_escaped_stringIcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorEESA_SA_SC_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail20write_escaped_stringIcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorEESA_SA_SC_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsEEN23bounded_output_iteratorppEi
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsEEN23bounded_output_iteratordeEv
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsEEN23bounded_output_iteratoraSEc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIcPKcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SC_NS0_17basic_string_viewIS9_EERKNS0_12format_specsEE23bounded_output_iteratorTnNS8_IXntaasr23is_back_insert_iteratorIT1_EE5valueoosr41has_back_insert_iterator_container_appendISJ_SC_EE5valuesr48has_back_insert_iterator_container_insert_at_endISJ_SC_EE5valueEiE4typeELi0EEESJ_SC_SC_SJ_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16write_escaped_cpIZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorcEES7_S7_RKNS1_18find_escape_resultISA_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm2EcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorEET1_SH_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm4EcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorEET1_SH_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm8EcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorEET1_SH_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIcPcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SB_NS0_17basic_string_viewIS8_EERKNS0_12format_specsEE23bounded_output_iteratorTnNS7_IXntaasr23is_back_insert_iteratorIT1_EE5valueoosr41has_back_insert_iterator_container_appendISI_SB_EE5valuesr48has_back_insert_iterator_container_insert_at_endISI_SB_EE5valueEiE4typeELi0EEESI_SB_SB_SI_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_NS0_9monostateENS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_NS0_9monostateENS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE8max_sizeEv
Trace2Pass: Instrumented 0 arithmetic operations, 1 division checks in _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE8max_sizeEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIcE4dataEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EPKcmRKS3_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EPKcmRKS3_
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsISaIcEE8max_sizeERKS0_
Trace2Pass: Instrumenting function: _ZNKSt15__new_allocatorIcE8max_sizeEv
Trace2Pass: Instrumenting function: _ZNKSt15__new_allocatorIcE11_M_max_sizeEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag
Trace2Pass: Instrumenting function: _ZSt8distanceIPKcENSt15iterator_traitsIT_E15difference_typeES3_S3_
Trace2Pass: Instrumenting function: _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tagEN6_GuardC2EPS4_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcPKcS7_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcPKcS7_
Trace2Pass: Instrumenting function: _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tagEN6_GuardD2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tagEN6_GuardD2Ev
Trace2Pass: Instrumenting function: _ZSt10__distanceIPKcENSt15iterator_traitsIT_E15difference_typeES3_S3_St26random_access_iterator_tag
Trace2Pass: Instrumenting function: _ZSt19__iterator_categoryIPKcENSt15iterator_traitsIT_E17iterator_categoryERKS3_
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEE10deallocateEv
Trace2Pass: Instrumenting function: _ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EEPKS5_
Trace2Pass: Instrumenting function: _ZNSt9basic_iosIcSt11char_traitsIcEE8setstateESt12_Ios_Iostate
Trace2Pass: Instrumenting function: _ZNSt11char_traitsIcE6lengthEPKc
Trace2Pass: Instrumenting function: _ZStorSt12_Ios_IostateS_
Trace2Pass: Instrumenting function: _ZNKSt9basic_iosIcSt11char_traitsIcEE7rdstateEv
Trace2Pass: Instrumenting function: _ZSt5flushIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_
Trace2Pass: Instrumenting function: _ZNKSt9basic_iosIcSt11char_traitsIcEE5widenEc
Trace2Pass: Instrumenting function: _ZSt13__check_facetISt5ctypeIcEERKT_PS3_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZSt13__check_facetISt5ctypeIcEERKT_PS3_
Trace2Pass: Instrumenting function: _ZNKSt5ctypeIcE5widenEc
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_format_argsINS0_7contextEEC2ILi1ELi0ELy1ETnNSt9enable_ifIXleT_LNS0_6detail3$_0E15EEiE4typeELi0EEERKNS6_16format_arg_storeIS2_XT_EXT0_EXT1_EEE
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_format_argsINS0_7contextEEC2ILi1ELi0ELy10ETnNSt9enable_ifIXleT_LNS0_6detail3$_0E15EEiE4typeELi0EEERKNS6_16format_arg_storeIS2_XT_EXT0_EXT1_EEE
Trace2Pass: Instrumenting function: _GLOBAL__sub_I_fmt_test.cpp
11 warnings generated.
=== TEST OUTPUT START ===
Trace2Pass: Runtime initialized (sample_rate=0.100, opt_level=unknown)
FAIL: nan=inf
Trace2Pass: Runtime shutting down
TEST_EXIT_CODE=1
=== TEST OUTPUT END ===
```

### fmt with O3_fastmath_fma
- Baseline exit: 0, Aggressive exit: 1
- Status: CANDIDATE_exit
- Trace2Pass anomalies:
```
Trace2Pass: Injected build metadata: opt_level=unknown, flags=(none)
Trace2Pass: Instrumenting function: __cxx_global_var_init
Trace2Pass: Instrumenting function: main
Trace2Pass: Instrumenting function: _ZN3fmt3v126formatIJRA6_KcEEENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEENS0_7fstringIJDpT_EE1tEDpOSC_
Trace2Pass: Instrumenting function: _ZN3fmt3v127fstringIJRA6_KcEEC2ILm11EEERAT__S2_
Trace2Pass: Instrumenting function: _ZStneIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EEPKS5_
Trace2Pass: Instrumenting function: _ZStlsIcSt11char_traitsIcESaIcEERSt13basic_ostreamIT_T0_ES7_RKNSt7__cxx1112basic_stringIS4_S5_T1_EE
Trace2Pass: Instrumenting function: _ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc
Trace2Pass: Instrumenting function: _ZNSolsEPFRSoS_E
Trace2Pass: Instrumenting function: _ZSt4endlIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126formatIJiEEENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEENS0_7fstringIJDpT_EE1tEDpOS9_
Trace2Pass: Instrumenting function: _ZN3fmt3v127fstringIJiEEC2ILm7EEERAT__Kc
Trace2Pass: Instrumenting function: _ZN3fmt3v126formatIJdEEENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEENS0_7fstringIJDpT_EE1tEDpOS9_
Trace2Pass: Instrumenting function: _ZN3fmt3v127fstringIJdEEC2ILm7EEERAT__Kc
Trace2Pass: Instrumenting function: _ZN3fmt3v126formatIJRdEEENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEENS0_7fstringIJDpT_EE1tEDpOSA_
Trace2Pass: Instrumenting function: _ZN3fmt3v127fstringIJRdEEC2ILm3EEERAT__Kc
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev
Trace2Pass: Instrumenting function: __cxx_global_var_init.15
Trace2Pass: Instrumenting function: _ZNSt6locale2idC2Ev
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
Trace2Pass: Instrumenting function: __clang_call_terminate
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in __clang_call_terminate
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE11_M_is_localEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_destroyEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_destroyEm
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7_M_dataEv
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_M_local_dataEv
Trace2Pass: Instrumenting function: _ZNSt19__ptr_traits_ptr_toIPKcS0_Lb0EE10pointer_toERS0_
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsISaIcEE10deallocateERS0_Pcm
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE16_M_get_allocatorEv
Trace2Pass: Instrumenting function: _ZNSt15__new_allocatorIcE10deallocateEPcm
Trace2Pass: Instrumenting function: _ZN3fmt3v127vformatB5cxx11ENS0_17basic_string_viewIcEENS0_17basic_format_argsINS0_7contextEEE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2EPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_format_argsINS0_7contextEEC2ILi1ELi0ELy12ETnNSt9enable_ifIXleT_LNS0_6detail3$_0E15EEiE4typeELi0EEERKNS6_16format_arg_storeIS2_XT_EXT0_EXT1_EEE
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEEC2ERKS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10vformat_toERNS1_6bufferIcEENS0_17basic_string_viewIcEENS0_17basic_format_argsINS0_7contextEEENS0_10locale_refE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail10vformat_toERNS1_6bufferIcEENS0_17basic_string_viewIcEENS0_17basic_format_argsINS0_7contextEEENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v1210locale_refC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v129to_stringILm500EEENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEERKNS0_19basic_memory_bufferIcXT_ENS0_6detail9allocatorIcEEEE
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEED2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEED2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEE4growERNS2_6bufferIcEEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 division checks in _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEE4growERNS2_6bufferIcEEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcEC2EPFvRS3_mEPcmm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE3setEPcm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16abort_fuzzing_ifEb
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIcEEE8max_sizeERKS4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIcEEE8max_sizeERKS4_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIcE8capacityEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126max_ofImEET_S2_S2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE4dataEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIcE8allocateEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks, 1 division checks in _ZN3fmt3v126detail9allocatorIcE8allocateEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6assumeEb
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIcE4sizeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIcE10deallocateEPcm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13ignore_unusedIJbEEEvDpRKT_
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIcEEE11_S_max_sizeIKS4_EEmRT_z
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9max_valueImEET_v
Trace2Pass: Instrumenting function: _ZN3fmt3v1211assert_failEPKciS2_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1211assert_failEPKciS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8allocateEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail8allocateEm
Trace2Pass: Instrumenting function: _ZNSt14numeric_limitsImE3maxEv
Trace2Pass: Instrumenting function: _ZNSt9bad_allocC2Ev
Trace2Pass: Instrumenting function: _ZNSt9exceptionC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1214basic_appenderIcEC2ERNS0_6detail6bufferIcEE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcE4sizeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6equal2EPKcS3_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcE4dataEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE3getEi
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE5visitINS0_6detail21default_arg_formatterIcEEEEDTclfp_Li0EEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19parse_format_stringIcNS1_14format_handlerIcEEEEvNS0_17basic_string_viewIT_EEOT0_
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail19parse_format_stringIcNS1_14format_handlerIcEEEEvNS0_17basic_string_viewIT_EEOT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcEC2ENS0_17basic_string_viewIcEEi
Trace2Pass: Instrumenting function: _ZN3fmt3v127contextC2ENS0_14basic_appenderIcEENS0_17basic_format_argsIS1_EENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE9is_packedEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE8max_sizeEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE4typeEi
Trace2Pass: Instrumented 2 arithmetic operations in _ZNK3fmt3v1217basic_format_argsINS0_7contextEE4typeEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v129monostateC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIiTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIjTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIxTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIyTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclInTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail3mapEn
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIoTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail3mapEo
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIbTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIcTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIfTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIdTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIeTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIPKcTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclINS0_17basic_string_viewIcEETnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail12string_valueIcE3strEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclIPKvTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclENS0_16basic_format_argINS0_7contextEE6handleE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEE6handleC2ENS0_6detail12custom_valueIS2_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21default_arg_formatterIcEclENS0_9monostateE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail21default_arg_formatterIcEclENS0_9monostateE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEiTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIiTnNSt9enable_ifIXsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10to_pointerIcEEPT_NS0_14basic_appenderIS3_EEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcjEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v1214basic_appenderIcEppEi
Trace2Pass: Instrumenting function: _ZN3fmt3v1214basic_appenderIcEdeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1214basic_appenderIcEaSEc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcjNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_decimalIcjNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15do_count_digitsEj
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail15do_count_digitsEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13get_containerINS0_14basic_appenderIcEEEERNT_14container_typeES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE11try_reserveEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE10try_resizeEm
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail13get_containerINS0_14basic_appenderIcEEEERNT_14container_typeES5_EN8accessorC2ES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126min_ofImEET_S2_S2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17do_format_decimalIcjEEPT_S4_T0_i
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail17do_format_decimalIcjEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11to_unsignedIiEENSt13make_unsignedIT_E4typeES4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail11to_unsignedIiEENSt13make_unsignedIT_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14write2digits_iIcEEvPT_m
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write2digitsIcEEvPT_m
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9digits2_iEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7digits2Em
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE9push_backERKc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13copy_noinlineIcPcNS0_14basic_appenderIcEEEET1_T0_S7_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIcPcNS0_14basic_appenderIcEETnNSt9enable_ifIXaasr23is_back_insert_iteratorIT1_EE5valuesr41has_back_insert_iterator_container_appendIS7_T0_EE5valueEiE4typeELi0EEES7_S8_S8_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE6appendIcEEvPKT_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11to_unsignedIlEENSt13make_unsignedIT_E4typeES4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail11to_unsignedIlEENSt13make_unsignedIT_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEjTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIjTnNSt9enable_ifIXntsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEExTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIxTnNSt9enable_ifIXsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcmEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcmNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_decimalIcmNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15do_count_digitsEm
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail15do_count_digitsEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17do_format_decimalIcmEEPT_S4_T0_i
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks, 2 division checks in _ZN3fmt3v126detail17do_format_decimalIcmEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEyTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIyTnNSt9enable_ifIXntsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEnTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeInTnNSt9enable_ifIXsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsEo
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcoEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_decimalIcoNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_decimalIcoNS0_14basic_appenderIcEETnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT1_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21count_digits_fallbackIoEEiT_
Trace2Pass: Instrumented 4 arithmetic operations, 1 division checks in _ZN3fmt3v126detail21count_digits_fallbackIoEEiT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17do_format_decimalIcoEEPT_S4_T0_i
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks, 2 division checks in _ZN3fmt3v126detail17do_format_decimalIcoEEPT_S4_T0_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEoTnNSt9enable_ifIXaaaasr11is_integralIT1_EE5valuentsr3std7is_sameIS6_bEE5valuentsr3std7is_sameIS6_T_EE5valueEiE4typeELi0EEET0_SA_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIoTnNSt9enable_ifIXntsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEbTnNSt9enable_ifIXsr3std7is_sameIT1_bEE5valueEiE4typeELi0EEET0_S9_S6_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_specsC2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs4typeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIciTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_bytesIcLNS0_5alignE1ENS0_14basic_appenderIcEEEET1_S6_NS0_17basic_string_viewIcEERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_string_viewIcEC2EPKc
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs9localizedEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_locENS0_14basic_appenderIcEENS0_9loc_valueERKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IiTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18write_int_noinlineIcNS0_14basic_appenderIcEEjEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIiEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs4signEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v1211basic_specs4signEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1210locale_ref3getISt6localeEET_v
Trace2Pass: Instrumenting function: _ZSt9has_facetIN3fmt3v1212format_facetISt6localeEEEbRKS3_
Trace2Pass: Instrumenting function: _ZSt9use_facetIN3fmt3v1212format_facetISt6localeEEERKT_RKS3_
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in _ZSt9use_facetIN3fmt3v1212format_facetISt6localeEEERKT_RKS3_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1212format_facetISt6localeE3putENS0_14basic_appenderIcEENS0_9loc_valueERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_facetISt6localeEC2ERS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_facetISt6localeED2Ev
Trace2Pass: Instrumenting function: _ZNSt6locale5facetC2Em
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2Ev
Trace2Pass: Instrumenting function: _ZNKSt7__cxx118numpunctIcE8groupingEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEaSEOS4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEaSEOS4_
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5emptyEv
Trace2Pass: Instrumenting function: _ZNKSt7__cxx118numpunctIcE13thousands_sepEv
Trace2Pass: Instrumenting function: _ZNSaIcEC2Ev
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2IS3_EEmcRKS3_
Trace2Pass: Instrumenting function: _ZNSt15__new_allocatorIcED2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_facetISt6localeED0Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1212format_facetISt6localeE6do_putENS0_14basic_appenderIcEENS0_9loc_valueERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_M_local_dataEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_Alloc_hiderC2EPcOS3_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE17_M_use_local_dataEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_M_set_lengthEm
Trace2Pass: Instrumenting function: _ZNSt19__ptr_traits_ptr_toIPccLb0EE10pointer_toERc
Trace2Pass: Instrumenting function: _ZNSt15__new_allocatorIcEC2ERKS0_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_lengthEm
Trace2Pass: Instrumenting function: _ZNSt11char_traitsIcE6assignERcRKc
Trace2Pass: Instrumenting function: _ZN9__gnu_cxx14__alloc_traitsISaIcEcE15_S_always_equalEv
Trace2Pass: Instrumenting function: _ZStneRKSaIcES1_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7_M_dataEPc
Trace2Pass: Instrumenting function: _ZSt15__alloc_on_moveISaIcEEvRT_S2_
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4sizeEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7_S_copyEPcPKcm
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6lengthEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE11_M_capacityEm
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5clearEv
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5clearEv
Trace2Pass: Instrumenting function: _ZNSt11char_traitsIcE4copyEPcPKcm
Trace2Pass: Instrumenting function: _ZNSt15__new_allocatorIcEC2Ev
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_Alloc_hiderC2EPcRKS3_
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_value5visitINS0_6detail10loc_writerIcEEEEDTclfp_Li0EEEOT_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2ERKS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcED2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE5visitIRNS0_6detail10loc_writerIcEEEEDTclfp_Li0EEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIiTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIjTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIxTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIyTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclInTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIoTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIbTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIfTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIdTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIeTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIPKcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclINS0_17basic_string_viewIcEETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclIPKvTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclINS0_16basic_format_argINS0_7contextEE6handleETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbSA_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10loc_writerIcEclINS0_9monostateETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEbS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEmcEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EE
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEmcEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14digit_groupingIcEC2ENSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEES9_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14digit_groupingIcED2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs3altEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13prefix_appendERjj
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail13prefix_appendERjj
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs5upperEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi4EmEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_base2eIcNS0_14basic_appenderIcEEmTnNSt9enable_ifIXsr23is_back_insert_iteratorIT0_EE5valueEiE4typeELi0EEES6_iS6_T1_ib
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail13format_base2eIcNS0_14basic_appenderIcEEmTnNSt9enable_ifIXsr23is_back_insert_iteratorIT0_EE5valueEiE4typeELi0EEES6_iS6_T1_ib
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi3EmEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi1EmEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail10write_charIcNS0_14basic_appenderIcEEEET0_S5_T_RKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail14digit_groupingIcE16count_separatorsEi
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v126detail14digit_groupingIcE16count_separatorsEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIS5_mcEET_S7_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEEUlS5_E_EESD_SD_SB_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIS5_mcEET_S7_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEEUlS5_E_EESD_SD_SB_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi4EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi4EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_base2eIcmEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16do_format_base2eIcmEEPT_iS4_T0_ib
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail16do_format_base2eIcmEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi3EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi3EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi1EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi1EmEEiT0_ENKUlmE_clEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEEZNS1_10write_charIcS5_EET0_S7_T_RKNS0_12format_specsEEUlS5_E_EET1_SD_SB_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_10write_charIcS5_EET0_S7_T_RKNS0_12format_specsEEUlS5_E_EET1_SE_SB_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_10write_charIcS5_EET0_S7_T_RKNS0_12format_specsEEUlS5_E_EET1_SE_SB_mmOT2_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs5alignEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v1211basic_specs5alignEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7reserveIcEENS0_14basic_appenderIT_EES5_m
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs9fill_sizeEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v1211basic_specs9fill_sizeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4fillIcNS0_14basic_appenderIcEEEET0_S5_mRKNS0_11basic_specsE
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail10write_charIcNS0_14basic_appenderIcEEEET0_S5_T_RKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13base_iteratorINS0_14basic_appenderIcEEEET_S5_S5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nINS0_14basic_appenderIcEEmcEET_S5_T0_RKT1_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs9fill_unitIcEET_v
Trace2Pass: Instrumented 2 arithmetic operations in _ZNK3fmt3v1211basic_specs9fill_unitIcEET_v
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs4fillIcTnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEEPKS4_v
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIcPKcNS0_14basic_appenderIcEETnNSt9enable_ifIXaasr23is_back_insert_iteratorIT1_EE5valuesr41has_back_insert_iterator_container_appendIS8_T0_EE5valueEiE4typeELi0EEES8_S9_S9_S8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18write_escaped_charIcNS0_14basic_appenderIcEEEET0_S5_T_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12needs_escapeEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16write_escaped_cpINS0_14basic_appenderIcEEcEET_S5_RKNS1_18find_escape_resultIT0_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12is_printableEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12is_printableEtPKNS1_9singletonEmPKhS6_m
Trace2Pass: Instrumented 5 arithmetic operations in _ZN3fmt3v126detail12is_printableEtPKNS1_9singletonEmPKhS6_m
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm2EcNS0_14basic_appenderIcEEEET1_S5_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm4EcNS0_14basic_appenderIcEEEET1_S5_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm8EcNS0_14basic_appenderIcEEEET1_S5_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_string_viewIcEC2EPKcm
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcE5beginEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcE3endEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nIcmEEPT_S4_T0_c
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_base2eIcjEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11to_unsignedImEENSt13make_unsignedIT_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16do_format_base2eIcjEEPT_iS4_T0_ib
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail16do_format_base2eIcjEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail14digit_groupingIcE13initial_stateEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail14digit_groupingIcE4nextERNS3_10next_stateE
Trace2Pass: Instrumented 2 arithmetic operations in _ZNK3fmt3v126detail14digit_groupingIcE4nextERNS3_10next_stateE
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5beginEv
Trace2Pass: Instrumenting function: _ZN9__gnu_cxx17__normal_iteratorIPKcNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEEC2ERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9max_valueIiEET_v
Trace2Pass: Instrumenting function: _ZN9__gnu_cxxeqIPKcNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEEEbRKNS_17__normal_iteratorIT_T0_EESE_
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE3endEv
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4backEv
Trace2Pass: Instrumenting function: _ZNK9__gnu_cxx17__normal_iteratorIPKcNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEEdeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9max_valueIcEET_v
Trace2Pass: Instrumenting function: _ZN9__gnu_cxx17__normal_iteratorIPKcNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEEppEi
Trace2Pass: Instrumenting function: _ZNSt14numeric_limitsIiE3maxEv
Trace2Pass: Instrumenting function: _ZNK9__gnu_cxx17__normal_iteratorIPKcNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEE4baseEv
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEixEm
Trace2Pass: Instrumenting function: _ZNSt14numeric_limitsIcE3maxEv
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEmcEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEENKUlS4_E_clES4_
Trace2Pass: Instrumented 1 arithmetic operations in _ZZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEmcEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail14digit_groupingIcE5applyINS0_14basic_appenderIcEEcEET_S7_NS0_17basic_string_viewIT0_EE
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZNK3fmt3v126detail14digit_groupingIcE5applyINS0_14basic_appenderIcEEcEET_S7_NS0_17basic_string_viewIT0_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEEC2ERKS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiE9push_backERKi
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIiE4sizeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiEixIiEERiT_
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4dataEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcEixEm
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEED2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEED2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEE4growERNS2_6bufferIiEEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 division checks in _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEE4growERNS2_6bufferIiEEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiEC2EPFvRS3_mEPimm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiE3setEPim
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIiEEE8max_sizeERKS4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIiEEE8max_sizeERKS4_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIiE8capacityEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiE4dataEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIiE8allocateEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks, 1 division checks in _ZN3fmt3v126detail9allocatorIiE8allocateEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIiE10deallocateEPim
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIiEEE11_S_max_sizeIKS4_EEmRT_z
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIiE11try_reserveEm
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIiLm500ENS0_6detail9allocatorIiEEE10deallocateEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EOS4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EOS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIjEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIxEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIyEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argInEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEocEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EE
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEocEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi4EoEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_base2eIcNS0_14basic_appenderIcEEoTnNSt9enable_ifIXsr23is_back_insert_iteratorIT0_EE5valueEiE4typeELi0EEES6_iS6_T1_ib
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail13format_base2eIcNS0_14basic_appenderIcEEoTnNSt9enable_ifIXsr23is_back_insert_iteratorIT0_EE5valueEiE4typeELi0EEES6_iS6_T1_ib
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi3EoEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12count_digitsILi1EoEEiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIS5_ocEET_S7_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEEUlS5_E_EESD_SD_SB_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIS5_ocEET_S7_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEEUlS5_E_EESD_SD_SB_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi4EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi4EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_base2eIcoEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16do_format_base2eIcoEEPT_iS4_T0_ib
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail16do_format_base2eIcoEEPT_iS4_T0_ib
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi3EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi3EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12count_digitsILi1EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumented 2 arithmetic operations in _ZZN3fmt3v126detail12count_digitsILi1EoEEiT0_ENKUloE_clEo
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEocEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEENKUlS4_E_clES4_
Trace2Pass: Instrumented 1 arithmetic operations in _ZZN3fmt3v126detail9write_intINS0_14basic_appenderIcEEocEET_S5_T0_jRKNS0_12format_specsERKNS1_14digit_groupingIT1_EEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIoEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN9__gnu_cxx14__alloc_traitsISaIcEcE17_S_select_on_copyERKS1_
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE16_M_get_allocatorEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tag
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsISaIcEE37select_on_container_copy_constructionERKS0_
Trace2Pass: Instrumenting function: _ZNSaIcEC2ERKS_
Trace2Pass: Instrumenting function: _ZSt8distanceIPcENSt15iterator_traitsIT_E15difference_typeES2_S2_
Trace2Pass: Instrumenting function: _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tagEN6_GuardC2EPS4_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcS5_S5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcS5_S5_
Trace2Pass: Instrumenting function: _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tagEN6_GuardD2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPcEEvT_S7_St20forward_iterator_tagEN6_GuardD2Ev
Trace2Pass: Instrumenting function: _ZSt10__distanceIPcENSt15iterator_traitsIT_E15difference_typeES2_S2_St26random_access_iterator_tag
Trace2Pass: Instrumenting function: _ZSt19__iterator_categoryIPcENSt15iterator_traitsIT_E17iterator_categoryERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRiEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEjEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumented 5 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEjEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12size_paddingC2EijRKNS0_12format_specsE
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail12size_paddingC2EijRKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIcS5_jEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_jEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_jEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEjEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumented 1 arithmetic operations in _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEjEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nINS0_14basic_appenderIcEEjcEET_S5_T0_RKT1_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEEZNS1_11write_bytesIcLS3_1ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_11write_bytesIcLS3_1ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_11write_bytesIcLS3_1ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_bytesIcLNS0_5alignE1ENS0_14basic_appenderIcEEEET1_S6_NS0_17basic_string_viewIcEERKNS0_12format_specsEENKUlS5_E_clES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6narrowEPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specsC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_T_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEfTnNSt9enable_ifIXsr13is_fast_floatIT1_EE5valueEiE4typeELi0EEET0_S9_S6_
Trace2Pass: Instrumented 8 arithmetic operations, 2 division checks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEfTnNSt9enable_ifIXsr13is_fast_floatIT1_EE5valueEiE4typeELi0EEET0_S9_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7signbitIfTnNSt9enable_ifIXsr17is_floating_pointIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_maskIfEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail13exponent_maskIfEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8bit_castIjfTnNSt9enable_ifIXeqstT_stT0_EiE4typeELi0EEES4_RKS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_nonfiniteIcNS0_14basic_appenderIcEEEET0_S5_bNS0_12format_specsENS0_4signE
Trace2Pass: Instrumenting function: _ZSt5isnanf
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox10to_decimalIfEENS2_10decimal_fpIT_EES5_
Trace2Pass: Instrumented 16 arithmetic operations, 1 unreachable blocks, 3 division checks in _ZN3fmt3v126detail9dragonbox10to_decimalIfEENS2_10decimal_fpIT_EES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9use_fixedEii
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9exp_upperIfEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6selectILb0EPcNS0_14basic_appenderIcEETnNSt9enable_ifIXntT_EiE4typeELi0EEET1_T0_S9_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEjcTnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_iiT1_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14write_exponentIcNS0_14basic_appenderIcEEEET0_iS5_
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks, 2 division checks in _ZN3fmt3v126detail14write_exponentIcNS0_14basic_appenderIcEEEET0_iS5_
Trace2Pass: Instrumenting function: _ZSt7signbitd
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20num_significand_bitsIfEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs8set_fillEc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEEZNS1_15write_nonfiniteIcS5_EET0_S7_bNS0_12format_specsENS0_4signEEUlS5_E_EET1_SB_RKS8_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs13set_fill_sizeEm
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v1211basic_specs13set_fill_sizeEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_15write_nonfiniteIcS5_EET0_S7_bNS0_12format_specsENS0_4signEEUlS5_E_EET1_SC_RKS8_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEERZNS1_15write_nonfiniteIcS5_EET0_S7_bNS0_12format_specsENS0_4signEEUlS5_E_EET1_SC_RKS8_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail15write_nonfiniteIcNS0_14basic_appenderIcEEEET0_S5_bNS0_12format_specsENS0_4signEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7getsignIcEET_NS0_4signE
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail7getsignIcEET_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_biasIfEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox21shorter_interval_caseIfEENS2_10decimal_fpIT_EEi
Trace2Pass: Instrumented 5 arithmetic operations, 2 division checks in _ZN3fmt3v126detail9dragonbox21shorter_interval_caseIfEENS2_10decimal_fpIT_EEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox16floor_log10_pow2Ei
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox16floor_log10_pow2Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE16get_cached_powerEi
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE16get_cached_powerEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox16floor_log2_pow10Ei
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox16floor_log2_pow10Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE13compute_deltaERKmi
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE13compute_deltaERKmi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE11compute_mulEjRKm
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE11compute_mulEjRKm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox28divide_by_10_to_kappa_plus_1Ej
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail9dragonbox28divide_by_10_to_kappa_plus_1Ej
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE18compute_mul_parityEjRKmi
Trace2Pass: Instrumented 4 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE18compute_mul_parityEjRKmi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox21remove_trailing_zerosERji
Trace2Pass: Instrumented 1 arithmetic operations, 3 unreachable blocks, 2 division checks in _ZN3fmt3v126detail9dragonbox21remove_trailing_zerosERji
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox38check_divisibility_and_divide_by_pow10ILi1EEEbRj
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox38check_divisibility_and_divide_by_pow10ILi1EEEbRj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox37floor_log10_pow2_minus_log10_4_over_3Ei
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox37floor_log10_pow2_minus_log10_4_over_3Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE47compute_left_endpoint_for_shorter_interval_caseERKmi
Trace2Pass: Instrumented 6 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE47compute_left_endpoint_for_shorter_interval_caseERKmi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE48compute_right_endpoint_for_shorter_interval_caseERKmi
Trace2Pass: Instrumented 6 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE48compute_right_endpoint_for_shorter_interval_caseERKmi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox41is_left_endpoint_integer_shorter_intervalIfEEbi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIfE42compute_round_up_for_shorter_interval_caseERKmi
Trace2Pass: Instrumented 4 arithmetic operations, 1 division checks in _ZN3fmt3v126detail9dragonbox14cache_accessorIfE42compute_round_up_for_shorter_interval_caseERKmi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14umul96_upper64Ejm
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail9dragonbox14umul96_upper64Ejm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox15umul128_upper64Emm
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail9dragonbox15umul128_upper64Emm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14umul96_lower64Ejm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4rotrEjj
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail4rotrEjj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9max_valueIjEET_v
Trace2Pass: Instrumenting function: _ZNSt14numeric_limitsIjE3maxEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126min_ofIiEET_S2_S2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail23fallback_digit_groupingIcEC2ENS0_10locale_refEb
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail23fallback_digit_groupingIcE16count_separatorsEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126max_ofIiEET_S2_S2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEjNS1_23fallback_digit_groupingIcEEEET0_S7_T1_iiRKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nINS0_14basic_appenderIcEEicEET_S5_T0_RKT1_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail6fill_nINS0_14basic_appenderIcEEicEET_S5_T0_RKT1_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail23fallback_digit_groupingIcE13has_separatorEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEjEET0_S5_T1_i
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail23fallback_digit_groupingIcE5applyINS0_14basic_appenderIcEEcEET_S7_NS0_17basic_string_viewIT0_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E0_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcjNS1_23fallback_digit_groupingIcEEEET_S7_T1_iiT0_RKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE3endEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E1_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcjTnNSt9enable_ifIXsr3std11is_integralIT0_EE5valueEiE4typeELi0EEEPT_S8_S4_iiS7_
Trace2Pass: Instrumented 3 arithmetic operations, 6 division checks in _ZN3fmt3v126detail17write_significandIcjTnNSt9enable_ifIXsr3std11is_integralIT0_EE5valueEiE4typeELi0EEEPT_S8_S4_iiS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEdTnNSt9enable_ifIXsr13is_fast_floatIT1_EE5valueEiE4typeELi0EEET0_S9_S6_
Trace2Pass: Instrumented 8 arithmetic operations, 2 division checks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEdTnNSt9enable_ifIXsr13is_fast_floatIT1_EE5valueEiE4typeELi0EEET0_S9_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7signbitIdTnNSt9enable_ifIXsr17is_floating_pointIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_maskIdEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail13exponent_maskIdEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8bit_castImdTnNSt9enable_ifIXeqstT_stT0_EiE4typeELi0EEES4_RKS5_
Trace2Pass: Instrumenting function: _ZSt5isnand
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox10to_decimalIdEENS2_10decimal_fpIT_EES5_
Trace2Pass: Instrumented 16 arithmetic operations, 1 unreachable blocks, 3 division checks in _ZN3fmt3v126detail9dragonbox10to_decimalIdEENS2_10decimal_fpIT_EES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9exp_upperIdEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEmcTnNSt9enable_ifIXntsr3std10is_pointerINSt9remove_cvINSt16remove_referenceIT_E4typeEE4typeEEE5valueEiE4typeELi0EEES8_S8_T0_iiT1_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20num_significand_bitsIdEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_biasIdEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox21shorter_interval_caseIdEENS2_10decimal_fpIT_EEi
Trace2Pass: Instrumented 5 arithmetic operations, 2 division checks in _ZN3fmt3v126detail9dragonbox21shorter_interval_caseIdEENS2_10decimal_fpIT_EEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE16get_cached_powerEi
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE16get_cached_powerEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE13compute_deltaERKNS1_7uint128Ei
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE13compute_deltaERKNS1_7uint128Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE11compute_mulEmRKNS1_7uint128E
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox28divide_by_10_to_kappa_plus_1Em
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail9dragonbox28divide_by_10_to_kappa_plus_1Em
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE18compute_mul_parityEmRKNS1_7uint128Ei
Trace2Pass: Instrumented 5 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE18compute_mul_parityEmRKNS1_7uint128Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox21remove_trailing_zerosERm
Trace2Pass: Instrumented 1 arithmetic operations, 2 unreachable blocks, 4 division checks in _ZN3fmt3v126detail9dragonbox21remove_trailing_zerosERm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox38check_divisibility_and_divide_by_pow10ILi2EEEbRj
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox38check_divisibility_and_divide_by_pow10ILi2EEEbRj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE47compute_left_endpoint_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumented 6 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE47compute_left_endpoint_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE48compute_right_endpoint_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumented 6 arithmetic operations in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE48compute_right_endpoint_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox41is_left_endpoint_integer_shorter_intervalIdEEbi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox14cache_accessorIdE42compute_round_up_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumented 4 arithmetic operations, 1 division checks in _ZN3fmt3v126detail9dragonbox14cache_accessorIdE42compute_round_up_for_shorter_interval_caseERKNS1_7uint128Ei
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail7uint1284highEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox16umul192_upper128EmNS1_7uint128E
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail7uint1283lowEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7umul128Emm
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail7umul128Emm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7uint128pLEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7uint128C2Emm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox16umul192_lower128EmNS1_7uint128E
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9dragonbox16umul192_lower128EmNS1_7uint128E
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4rotrEmj
Trace2Pass: Instrumented 2 arithmetic operations in _ZN3fmt3v126detail4rotrEmj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEmNS1_23fallback_digit_groupingIcEEEET0_S7_T1_iiRKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEmEET0_S5_T1_i
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E0_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcmNS1_23fallback_digit_groupingIcEEEET_S7_T1_iiT0_RKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_23fallback_digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_23fallback_digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E1_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcmTnNSt9enable_ifIXsr3std11is_integralIT0_EE5valueEiE4typeELi0EEEPT_S8_S4_iiS7_
Trace2Pass: Instrumented 3 arithmetic operations, 6 division checks in _ZN3fmt3v126detail17write_significandIcmTnNSt9enable_ifIXsr3std11is_integralIT0_EE5valueEiE4typeELi0EEEPT_S8_S4_iiS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEeTnNSt9enable_ifIXaasr17is_floating_pointIT1_EE5valuentsr13is_fast_floatIS6_EE5valueEiE4typeELi0EEET0_S9_S6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEeTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEeTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IeTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7signbitIeTnNSt9enable_ifIXsr17is_floating_pointIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8isfiniteIeTnNSt9enable_ifIXaasr17is_floating_pointIT_EE5valuesr12has_isfiniteIS4_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5isnanIeEEbT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9exp_upperIeEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15format_hexfloatIeTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEvS4_NS0_12format_specsERNS1_6bufferIcEE
Trace2Pass: Instrumented 18 arithmetic operations in _ZN3fmt3v126detail15format_hexfloatIeTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEvS4_NS0_12format_specsERNS1_6bufferIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13convert_floatIeEENSt11conditionalIXoosr3std7is_sameIT_fEE5valueeqcl8num_bitsIS4_EEclL_ZNS1_8num_bitsIdEEivEEEdS4_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_bytesIcLNS0_5alignE2ENS0_14basic_appenderIcEEEET1_S6_NS0_17basic_string_viewIcEERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v1212report_errorEPKc
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1212report_errorEPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs7set_altEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12format_floatIeEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEE
Trace2Pass: Instrumented 5 arithmetic operations in _ZN3fmt3v126detail12format_floatIeEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEE
Trace2Pass: Instrumenting function: _ZNKSt17integral_constantIbLb0EEcvbEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_floatIcNS0_14basic_appenderIcEENS1_14big_decimal_fpEEET0_S6_RKT1_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IReEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ee
Trace2Pass: Instrumenting function: _ZSt8isfinitee
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpIoEC2IeEET_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11countl_zeroEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpIoE6assignIeTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumented 4 arithmetic operations in _ZN3fmt3v126detail8basic_fpIoE6assignIeTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8bit_castIoeTnNSt9enable_ifIXeqstT_stT0_EiE4typeELi0EEES4_RKS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_maskIeEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail13exponent_maskIeEENS1_9dragonbox10float_infoIT_vE12carrier_uintEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13exponent_biasIeEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20num_significand_bitsIeEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_bytesIcLS3_2ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_bytesIcLS3_2ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_bytesIcLS3_2ES5_EET1_S7_NS0_17basic_string_viewIcEERKNS0_12format_specsEEUlS5_E_EES7_S7_SC_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_bytesIcLNS0_5alignE2ENS0_14basic_appenderIcEEEET1_S6_NS0_17basic_string_viewIcEERKNS0_12format_specsEENKUlS5_E_clES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_errorCI2St13runtime_errorEPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v1212format_errorD0Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nIciEEPT_S4_T0_c
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpIoEC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpIoE6assignIfTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail8basic_fpIoE6assignIfTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13format_dragonENS1_8basic_fpIoEEjiRNS1_6bufferIcEERi
Trace2Pass: Instrumented 29 arithmetic operations, 1 unreachable blocks, 2 division checks in _ZN3fmt3v126detail13format_dragonENS1_8basic_fpIoEEjiRNS1_6bufferIcEERi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcEixImEERcT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintaSIoEEvT_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigintaSIoEEvT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintlSEi
Trace2Pass: Instrumented 4 arithmetic operations, 1 unreachable blocks, 2 division checks in _ZN3fmt3v126detail6bigintlSEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintaSIiEEvT_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigintaSIiEEvT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint12assign_pow10Ei
Trace2Pass: Instrumented 5 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigint12assign_pow10Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint6assignERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintmLIoEERS2_T_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigintmLIoEERS2_T_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintaSIyEEvT_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigintaSIyEEvT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11add_compareERKNS1_6bigintES4_S4_
Trace2Pass: Instrumented 4 arithmetic operations in _ZN3fmt3v126detail11add_compareERKNS1_6bigintES4_S4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintmLIiEERS2_T_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigintmLIiEERS2_T_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16adjust_precisionERii
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail16adjust_precisionERii
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint13divmod_assignERKS2_
Trace2Pass: Instrumented 1 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail6bigint13divmod_assignERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7compareERKNS1_6bigintES4_
Trace2Pass: Instrumented 5 arithmetic operations in _ZN3fmt3v126detail7compareERKNS1_6bigintES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcEixIiEERcT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigintD2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEEC2ERKS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE4growERNS2_6bufferIjEEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 division checks in _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE4growERNS2_6bufferIjEEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjEC2EPFvRS3_mEPjmm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE3setEPjm
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIjEEE8max_sizeERKS4_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIjEEE8max_sizeERKS4_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIjE8capacityEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE4dataEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIjE8allocateEm
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks, 1 division checks in _ZN3fmt3v126detail9allocatorIjE8allocateEm
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIjE4sizeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9allocatorIjE10deallocateEPjm
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsIN3fmt3v126detail9allocatorIjEEE11_S_max_sizeIKS4_EEmRT_z
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint6assignIoTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail6bigint6assignIoTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjEixImEERjT_
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE6resizeEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE10try_resizeEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE11try_reserveEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE9push_backERKj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint6assignImTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail6bigint6assignImTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8num_bitsIjEEiv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint6squareEv
Trace2Pass: Instrumented 12 arithmetic operations in _ZN3fmt3v126detail6bigint6squareEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEEC2EOS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEEC2EOS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjEixIiEERjT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint20remove_leading_zerosEv
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail6bigint20remove_leading_zerosEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEED2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEED2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE4moveERS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE4moveERS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE10move_allocIS4_TnNSt9enable_ifIXntsr3std16allocator_traitsIT_E38propagate_on_container_move_assignmentE5valueEiE4typeELi0EEEbRS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIjPjS3_TnNSt9enable_ifIXntaasr23is_back_insert_iteratorIT1_EE5valueoosr41has_back_insert_iterator_container_appendIS5_T0_EE5valuesr48has_back_insert_iterator_container_insert_at_endIS5_S6_EE5valueEiE4typeELi0EEES5_S6_S6_S5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIjE5clearEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detaileqENS1_9allocatorIjEES3_
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIjLm32ENS0_6detail9allocatorIjEEE10deallocateEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIjE4dataEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIjPKjPjTnNSt9enable_ifIXntaasr23is_back_insert_iteratorIT1_EE5valueoosr41has_back_insert_iterator_container_appendIS7_T0_EE5valuesr48has_back_insert_iterator_container_insert_at_endIS7_S8_EE5valueEiE4typeELi0EEES7_S8_S8_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint8multiplyIoTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumented 5 arithmetic operations in _ZN3fmt3v126detail6bigint8multiplyIoTnNSt9enable_ifIXoosr3std7is_sameIT_mEE5valuesr3std7is_sameIS5_oEE5valueEiE4typeELi0EEEvS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8num_bitsImEEiv
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bigint10num_bigitsEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v126detail6bigint10num_bigitsEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bigint9get_bigitEi
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v126detail6bigint9get_bigitEi
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIjEixIiEERKjT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint8multiplyEj
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail6bigint8multiplyEj
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIjEixImEERKjT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint5alignERKS2_
Trace2Pass: Instrumented 7 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail6bigint5alignERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint16subtract_alignedERKS2_
Trace2Pass: Instrumented 2 arithmetic operations, 3 unreachable blocks in _ZN3fmt3v126detail6bigint16subtract_alignedERKS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6fill_nIPjjjEET_S4_T0_RKT1_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bigint15subtract_bigitsEijRj
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail6bigint15subtract_bigitsEijRj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumented 7 arithmetic operations in _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13decimal_pointIcEET_NS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20get_significand_sizeERKNS1_14big_decimal_fpE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16compute_exp_sizeEi
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail16compute_exp_sizeEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESA_SA_SG_mOSB_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18decimal_point_implIcEET_NS0_10locale_refE
Trace2Pass: Instrumenting function: _ZNKSt7__cxx118numpunctIcE13decimal_pointEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14digit_groupingIcEC2ENS0_10locale_refEb
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESA_SA_SH_mOSB_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESA_SA_SH_mOSB_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESA_SA_SH_mOSB_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13thousands_sepIcEENS1_20thousands_sep_resultIT_EENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEaSERKS4_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6assignEmc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20thousands_sep_resultIcED2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18thousands_sep_implIcEENS1_20thousands_sep_resultIT_EENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6assignERKS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEPKcNS1_14digit_groupingIcEEEET0_S9_T1_iiRKT2_
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail14digit_groupingIcE13has_separatorEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEEET0_S5_PKci
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E0_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcPKcNS1_14digit_groupingIcEEEET_S9_T1_iiT0_RKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcEET_S5_PKciiT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13copy_noinlineIcPKcNS0_14basic_appenderIcEEEET1_T0_S8_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESA_SA_SH_mmOSB_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_14big_decimal_fpEEET1_S8_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E1_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESA_SA_SG_mmOSB_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_14big_decimal_fpEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESA_SA_SG_mmOSB_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_PKT_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_PKT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_NS0_17basic_string_viewIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEvTnNSt9enable_ifIXsr3std7is_sameIT1_vEE5valueEiE4typeELi0EEET0_S9_PKS6_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_ptrIcNS0_14basic_appenderIcEEmEET0_S5_T1_PKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8bit_castImPKvTnNSt9enable_ifIXeqstT_stT0_EiE4typeELi0EEES6_RKS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_ptrIcS5_mEET0_S7_T1_PKNS0_12format_specsEEUlS5_E_EES8_S8_RSA_mOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_ptrIcNS0_14basic_appenderIcEEmEET0_S5_T1_PKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_ptrIcS5_mEET0_S7_T1_PKNS0_12format_specsEEUlS5_E_EES8_S8_RSA_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_ptrIcS5_mEET0_S7_T1_PKNS0_12format_specsEEUlS5_E_EES8_S8_RSA_mmOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_string_viewIcEC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_format_argsINS0_7contextEEC2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE6handle6formatERNS0_13parse_contextIcEERS2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE7on_textEPKcS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S8_S8_OT0_
Trace2Pass: Instrumented 0 arithmetic operations, 3 unreachable blocks in _ZN3fmt3v126detail23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S8_S8_OT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE8on_errorEPKc
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_handlerIcE8on_errorEPKc
Trace2Pass: Instrumenting function: _ZNK3fmt3v127context3outEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE20on_replacement_fieldEiPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE9on_arg_idEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12parse_arg_idIcRZNS1_23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S9_S9_OT0_E10id_adapterEES9_S9_S9_SB_
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail12parse_arg_idIcRZNS1_23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S9_S9_OT0_E10id_adapterEES9_S9_S9_SB_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE15on_format_specsEiPKcS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_handlerIcE15on_format_specsEiPKcS5_
Trace2Pass: Instrumenting function: _ZNK3fmt3v127context3argEi
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE11next_arg_idEv
Trace2Pass: Instrumented 1 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1213parse_contextIcE11next_arg_idEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE15do_check_arg_idEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail21parse_nonnegative_intIcEEiRPKT_S5_i
Trace2Pass: Instrumented 3 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail21parse_nonnegative_intIcEEiRPKT_S5_i
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S8_S8_OT0_EN10id_adapter8on_indexEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13is_name_startIcEEbT_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail23parse_replacement_fieldIcRNS1_14format_handlerIcEEEEPKT_S8_S8_OT0_EN10id_adapter7on_nameENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE9on_arg_idEi
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE12check_arg_idEi
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v1213parse_contextIcE12check_arg_idEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14format_handlerIcE9on_arg_idENS0_17basic_string_viewIcEE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail14format_handlerIcE9on_arg_idENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE12check_arg_idENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZNK3fmt3v127context6arg_idENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE6get_idIcEEiNS0_17basic_string_viewIT_EE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE14has_named_argsEv
Trace2Pass: Instrumenting function: _ZN3fmt3v12eqENS0_17basic_string_viewIcEES2_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_string_viewIcE7compareES2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7compareIcEEiPKT_S5_m
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEEcvbEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEE13format_customEPKcRNS0_13parse_contextIcEERS2_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1213parse_contextIcE5beginEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20dynamic_format_specsIcEC2Ev
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeE
Trace2Pass: Instrumented 0 arithmetic operations, 4 unreachable blocks in _ZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE4typeEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs7dynamicEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19handle_dynamic_specINS0_7contextEEEvNS0_11arg_id_kindERiRKNS1_7arg_refINT_9char_typeEEERS7_
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail19handle_dynamic_specINS0_7contextEEEvNS0_11arg_id_kindERiRKNS1_7arg_refINT_9char_typeEEERS7_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs13dynamic_widthEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v1211basic_specs13dynamic_widthEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1211basic_specs17dynamic_precisionEv
Trace2Pass: Instrumented 1 arithmetic operations in _ZNK3fmt3v1211basic_specs17dynamic_precisionEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE5visitINS0_6detail13arg_formatterIcEEEEDTclfp_Li0EEEOT_
Trace2Pass: Instrumenting function: _ZNK3fmt3v127context6localeEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE10advance_toEPKc
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_string_viewIcE13remove_prefixEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7arg_refIcEC2Ei
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8to_asciiIcTnNSt9enable_ifIXsr3std11is_integralIT_EE5valueEiE4typeELi0EEEcS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11parse_alignEc
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeEENUt_C2Ev
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeEENUt_clENS1_5stateEb
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeEENUt_clENS1_5stateEb
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs9set_alignENS0_5alignE
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v1211basic_specs9set_alignENS0_5alignE
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs8set_signENS0_4signE
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v1211basic_specs8set_signENS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail2inENS1_4typeEi
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail2inENS1_4typeEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18is_arithmetic_typeENS1_4typeE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11parse_widthIcEEPKT_S5_S5_RNS0_12format_specsERNS1_7arg_refIS3_EERNS0_13parse_contextIS3_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15parse_precisionIcEEPKT_S5_S5_RNS0_12format_specsERNS1_7arg_refIS3_EERNS0_13parse_contextIS3_EE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail15parse_precisionIcEEPKT_S5_S5_RNS0_12format_specsERNS1_7arg_refIS3_EERNS0_13parse_contextIS3_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs13set_localizedEv
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeEENUt0_clENS0_17presentation_typeEi
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZZN3fmt3v126detail18parse_format_specsIcEEPKT_S5_S5_RNS1_20dynamic_format_specsIS3_EERNS0_13parse_contextIS3_EENS1_4typeEENUt0_clENS0_17presentation_typeEi
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs9set_upperEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17code_point_lengthIcEEiPKT_
Trace2Pass: Instrumented 4 arithmetic operations in _ZN3fmt3v126detail17code_point_lengthIcEEiPKT_
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs8set_fillIcEEvNS0_17basic_string_viewIT_EE
Trace2Pass: Instrumented 2 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v1211basic_specs8set_fillIcEEvNS0_17basic_string_viewIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18parse_dynamic_specIcEENS1_25parse_dynamic_spec_resultIT_EEPKS4_S7_RiRNS1_7arg_refIS4_EERNS0_13parse_contextIS4_EE
Trace2Pass: Instrumented 0 arithmetic operations, 3 unreachable blocks in _ZN3fmt3v126detail18parse_dynamic_specIcEENS1_25parse_dynamic_spec_resultIT_EEPKS4_S7_RiRNS1_7arg_refIS4_EERNS0_13parse_contextIS4_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs17set_dynamic_widthENS0_11arg_id_kindE
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v1211basic_specs17set_dynamic_widthENS0_11arg_id_kindE
Trace2Pass: Instrumenting function: _ZN3fmt3v1213parse_contextIcE18check_dynamic_specEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12parse_arg_idIcNS1_20dynamic_spec_handlerIcEEEEPKT_S7_S7_OT0_
Trace2Pass: Instrumented 0 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail12parse_arg_idIcNS1_20dynamic_spec_handlerIcEEEEPKT_S7_S7_OT0_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20dynamic_spec_handlerIcE8on_indexEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20dynamic_spec_handlerIcE7on_nameENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail7arg_refIcEC2ENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs21set_dynamic_precisionENS0_11arg_id_kindE
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v1211basic_specs21set_dynamic_precisionENS0_11arg_id_kindE
Trace2Pass: Instrumenting function: _ZN3fmt3v1211basic_specs8set_typeENS0_17presentation_typeE
Trace2Pass: Instrumenting function: _ZNK3fmt3v127context3argENS0_17basic_string_viewIcEE
Trace2Pass: Instrumenting function: _ZNK3fmt3v1216basic_format_argINS0_7contextEE5visitINS0_6detail19dynamic_spec_getterEEEDTclfp_Li0EEEOT_
Trace2Pass: Instrumenting function: _ZNK3fmt3v1217basic_format_argsINS0_7contextEE3getIcEENS0_16basic_format_argIS2_EENS0_17basic_string_viewIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIiTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIjTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIxTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIyTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclInTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIoTnNSt9enable_ifIXsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIbTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIbTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIfTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIfTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIdTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIdTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIeTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIeTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIPKcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIPKcTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclINS0_17basic_string_viewIcEETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclINS0_17basic_string_viewIcEETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclIPKvTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclIPKvTnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclINS0_16basic_format_argINS0_7contextEE6handleETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS9_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclINS0_16basic_format_argINS0_7contextEE6handleETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS9_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail19dynamic_spec_getterclINS0_9monostateETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS6_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail19dynamic_spec_getterclINS0_9monostateETnNSt9enable_ifIXntsr10is_integerIT_EE5valueEiE4typeELi0EEEyS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIiTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIjTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIxTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIyTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclInTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIoTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIbTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIcTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIfTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIdTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIeTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIPKcTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclINS0_17basic_string_viewIcEETnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclIPKvTnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS8_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclENS0_16basic_format_argINS0_7contextEE6handleE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13arg_formatterIcEclINS0_9monostateETnNSt9enable_ifIXsr10is_builtinIT_EE5valueEiE4typeELi0EEEvS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcjTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IjTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRjEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ej
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcxTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IxTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18write_int_noinlineIcNS0_14basic_appenderIcEEmEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRxEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ex
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEmEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumented 5 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEmEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIcS5_mEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_mEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_mEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEmEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumented 1 arithmetic operations in _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEmEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcyTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IyTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRyEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ey
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcnTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2InTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18write_int_noinlineIcNS0_14basic_appenderIcEEoEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRnEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2En
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEoEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumented 5 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEoEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_9write_intIcS5_oEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_oEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_9write_intIcS5_oEET0_S7_NS1_13write_int_argIT1_EERKNS0_12format_specsEEUlS5_E_EES9_S9_SD_mmOT2_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEoEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumented 1 arithmetic operations in _ZZN3fmt3v126detail9write_intIcNS0_14basic_appenderIcEEoEET0_S5_NS1_13write_int_argIT1_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcoTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IoTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRoEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Eo
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_T_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16check_char_specsERKNS0_12format_specsE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail16check_char_specsERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIchTnNSt9enable_ifIXaaaasr11is_integralIT0_EE5valuentsr3std7is_sameIS4_bEE5valuentsr3std7is_sameIS4_T_EE5valueEiE4typeELi0EEENS0_14basic_appenderIS5_EES9_S4_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IhTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18make_write_int_argIhEENS1_13write_int_argINSt11conditionalIXaalecl8num_bitsIT_EELi32EntLi0EEjNS4_IXlecl8num_bitsIS5_EELi64EEmoE4typeEE4typeEEES5_NS0_4signE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRhEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Eh
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11is_negativeIhTnNSt9enable_ifIXntsr9is_signedIT_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEfTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEfTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IfTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8isfiniteIfTnNSt9enable_ifIXaasr17is_floating_pointIT_EE5valuesr12has_isfiniteIS4_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5isnanIfEEbT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_floatIcNS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET0_S8_RKT1_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15format_hexfloatIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEvS4_NS0_12format_specsERNS1_6bufferIcEE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail15format_hexfloatIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEvS4_NS0_12format_specsERNS1_6bufferIcEE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13convert_floatIfEENSt11conditionalIXoosr3std7is_sameIT_fEE5valueeqcl8num_bitsIS4_EEclL_ZNS1_8num_bitsIdEEivEEEdS4_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12format_floatIdEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEE
Trace2Pass: Instrumented 36 arithmetic operations, 2 unreachable blocks in _ZN3fmt3v126detail12format_floatIdEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEE
Trace2Pass: Instrumenting function: _ZNKSt17integral_constantIbLb1EEcvbEv
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRfEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ef
Trace2Pass: Instrumenting function: _ZSt8isfinitef
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumented 7 arithmetic operations in _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20get_significand_sizeIfEEiRKNS1_9dragonbox10decimal_fpIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEjNS1_14digit_groupingIcEEEET0_S7_T1_iiRKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E0_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcjNS1_14digit_groupingIcEEEET_S7_T1_iiT0_RKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIfEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E1_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIfEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mmOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpImEC2IdEET_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpImE6assignIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail8basic_fpImE6assignIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail13convert_floatIdEENSt11conditionalIXoosr3std7is_sameIT_fEE5valueeqcl8num_bitsIS4_EEclL_ZNS1_8num_bitsIdEEivEEEdS4_E4typeES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11countl_zeroEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail9dragonbox16get_cached_powerEi
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail12format_floatIdEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEEENKUljPcE_clEjSA_
Trace2Pass: Instrumented 8 arithmetic operations in _ZZN3fmt3v126detail12format_floatIdEEiT_iRKNS0_12format_specsEbRNS1_6bufferIcEEENKUljPcE_clEjSA_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail35fractional_part_rounding_thresholdsEi
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8basic_fpIoE6assignIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumented 3 arithmetic operations in _ZN3fmt3v126detail8basic_fpIoE6assignIdTnNSt9enable_ifIXntsr16is_double_doubleIT_EE5valueEiE4typeELi0EEEbS6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEdTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumented 2 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEdTnNSt9enable_ifIXsr17is_floating_pointIT1_EE5valueEiE4typeELi0EEET0_S9_S6_NS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v129loc_valueC2IdTnNSt9enable_ifIXntsr6detail11is_float128IT_EE5valueEiE4typeELi0EEES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8isfiniteIdTnNSt9enable_ifIXaasr17is_floating_pointIT_EE5valuesr12has_isfiniteIS4_EE5valueEiE4typeELi0EEEbS4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5isnanIdEEbT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_floatIcNS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET0_S8_RKT1_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v1216basic_format_argINS0_7contextEEC2IRdEEOT_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5valueINS0_7contextEEC2Ed
Trace2Pass: Instrumenting function: _ZSt8isfinited
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumented 7 arithmetic operations in _ZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20get_significand_sizeIdEEiRKNS1_9dragonbox10decimal_fpIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumented 15 arithmetic operations in _ZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail14do_write_floatIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEEZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandIcNS0_14basic_appenderIcEEmNS1_14digit_groupingIcEEEET0_S7_T1_iiRKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E0_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E0_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail17write_significandINS0_14basic_appenderIcEEcmNS1_14digit_groupingIcEEEET_S7_T1_iiT0_RKT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_11write_fixedIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEEUlS5_E1_EESC_SC_SJ_mmOSD_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11write_fixedIcNS1_14digit_groupingIcEENS0_14basic_appenderIcEENS1_9dragonbox10decimal_fpIdEEEET1_SA_RKT2_iT_RKNS0_12format_specsENS0_4signENS0_10locale_refEENKUlS6_E1_clES6_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mmOSD_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE2ENS0_14basic_appenderIcEERZNS1_14do_write_floatIcNS1_14digit_groupingIcEES5_NS1_9dragonbox10decimal_fpIdEEEET1_SC_RKT2_RKNS0_12format_specsENS0_4signEiNS0_10locale_refEEUlS5_E_EESC_SC_SI_mmOSD_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_PKT_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_PKT_RKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail8bit_castImPKcTnNSt9enable_ifIXeqstT_stT0_EiE4typeELi0EEES6_RKS7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_NS0_17basic_string_viewIT_EERKNS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20write_escaped_stringIcNS0_14basic_appenderIcEEEET0_S5_NS0_17basic_string_viewIT_EE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail20write_escaped_stringIcNS0_14basic_appenderIcEEEET0_S5_NS0_17basic_string_viewIT_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIccNS0_14basic_appenderIcEEEET1_NS0_17basic_string_viewIT0_EES5_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18for_each_codepointIZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEEUljNSB_IcEEE_EEvSG_S7_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail18for_each_codepointIZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEEUljNSB_IcEEE_EEvSG_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEEZNS1_5writeIcS5_TnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SB_NS0_17basic_string_viewIS8_EERKNS0_12format_specsEEUlS5_E_EET1_SI_SG_mmOT2_
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail12write_paddedIcLNS0_5alignE1ENS0_14basic_appenderIcEEZNS1_5writeIcS5_TnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SB_NS0_17basic_string_viewIS8_EERKNS0_12format_specsEEUlS5_E_EET1_SI_SG_mmOT2_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11find_escapeEPKcS3_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail18for_each_codepointIZNS1_11find_escapeEPKcS4_EUljNS0_17basic_string_viewIcEEE_EEvS6_T_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail18for_each_codepointIZNS1_11find_escapeEPKcS4_EUljNS0_17basic_string_viewIcEEE_EEvS6_T_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail18for_each_codepointIZNS1_11find_escapeEPKcS4_EUljNS0_17basic_string_viewIcEEE_EEvS6_T_ENKUlS4_S4_E_clES4_S4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIcPKcPcTnNSt9enable_ifIXntaasr23is_back_insert_iteratorIT1_EE5valueoosr41has_back_insert_iterator_container_appendIS7_T0_EE5valuesr48has_back_insert_iterator_container_insert_at_endIS7_S8_EE5valueEiE4typeELi0EEES7_S8_S8_S7_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail11utf8_decodeEPKcPjPi
Trace2Pass: Instrumented 14 arithmetic operations in _ZN3fmt3v126detail11utf8_decodeEPKcPjPi
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail11find_escapeEPKcS3_ENKUljNS0_17basic_string_viewIcEEE_clEjS5_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail18for_each_codepointIZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEEUljNSB_IcEEE_EEvSG_S7_ENKUlPKcSJ_E_clESJ_SJ_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsEENKUljNSA_IcEEE_clEjSF_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15counting_bufferIcEC2Ev
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail15counting_bufferIcE5countEv
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16display_width_ofEj
Trace2Pass: Instrumented 1 arithmetic operations in _ZN3fmt3v126detail16display_width_ofEj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15counting_bufferIcE4growERNS1_6bufferIcEEm
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail6bufferIcE5clearEv
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsEENKUlS4_E_clES4_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail20write_escaped_stringIcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorEESA_SA_SC_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail20write_escaped_stringIcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorEESA_SA_SC_
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsEEN23bounded_output_iteratorppEi
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsEEN23bounded_output_iteratordeEv
Trace2Pass: Instrumenting function: _ZZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_S9_NS0_17basic_string_viewIS6_EERKNS0_12format_specsEEN23bounded_output_iteratoraSEc
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIcPKcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SC_NS0_17basic_string_viewIS9_EERKNS0_12format_specsEE23bounded_output_iteratorTnNS8_IXntaasr23is_back_insert_iteratorIT1_EE5valueoosr41has_back_insert_iterator_container_appendISJ_SC_EE5valuesr48has_back_insert_iterator_container_insert_at_endISJ_SC_EE5valueEiE4typeELi0EEESJ_SC_SC_SJ_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail16write_escaped_cpIZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorcEES7_S7_RKNS1_18find_escape_resultISA_EE
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm2EcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorEET1_SH_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm4EcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorEET1_SH_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail15write_codepointILm8EcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SA_NS0_17basic_string_viewIS7_EERKNS0_12format_specsEE23bounded_output_iteratorEET1_SH_cj
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail4copyIcPcZNS1_5writeIcNS0_14basic_appenderIcEETnNSt9enable_ifIXsr3std7is_sameIT_cEE5valueEiE4typeELi0EEET0_SB_NS0_17basic_string_viewIS8_EERKNS0_12format_specsEE23bounded_output_iteratorTnNS7_IXntaasr23is_back_insert_iteratorIT1_EE5valueoosr41has_back_insert_iterator_container_appendISI_SB_EE5valuesr48has_back_insert_iterator_container_insert_at_endISI_SB_EE5valueEiE4typeELi0EEESI_SB_SB_SI_
Trace2Pass: Instrumenting function: _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_NS0_9monostateENS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZN3fmt3v126detail5writeIcNS0_14basic_appenderIcEEEET0_S5_NS0_9monostateENS0_12format_specsENS0_10locale_refE
Trace2Pass: Instrumenting function: _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE8max_sizeEv
Trace2Pass: Instrumented 0 arithmetic operations, 1 division checks in _ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE8max_sizeEv
Trace2Pass: Instrumenting function: _ZNK3fmt3v126detail6bufferIcE4dataEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EPKcmRKS3_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EPKcmRKS3_
Trace2Pass: Instrumenting function: _ZNSt16allocator_traitsISaIcEE8max_sizeERKS0_
Trace2Pass: Instrumenting function: _ZNKSt15__new_allocatorIcE8max_sizeEv
Trace2Pass: Instrumenting function: _ZNKSt15__new_allocatorIcE11_M_max_sizeEv
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag
Trace2Pass: Instrumenting function: _ZSt8distanceIPKcENSt15iterator_traitsIT_E15difference_typeES3_S3_
Trace2Pass: Instrumenting function: _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tagEN6_GuardC2EPS4_
Trace2Pass: Instrumenting function: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcPKcS7_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcPKcS7_
Trace2Pass: Instrumenting function: _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tagEN6_GuardD2Ev
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tagEN6_GuardD2Ev
Trace2Pass: Instrumenting function: _ZSt10__distanceIPKcENSt15iterator_traitsIT_E15difference_typeES3_S3_St26random_access_iterator_tag
Trace2Pass: Instrumenting function: _ZSt19__iterator_categoryIPKcENSt15iterator_traitsIT_E17iterator_categoryERKS3_
Trace2Pass: Instrumenting function: _ZN3fmt3v1219basic_memory_bufferIcLm500ENS0_6detail9allocatorIcEEE10deallocateEv
Trace2Pass: Instrumenting function: _ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EEPKS5_
Trace2Pass: Instrumenting function: _ZNSt9basic_iosIcSt11char_traitsIcEE8setstateESt12_Ios_Iostate
Trace2Pass: Instrumenting function: _ZNSt11char_traitsIcE6lengthEPKc
Trace2Pass: Instrumenting function: _ZStorSt12_Ios_IostateS_
Trace2Pass: Instrumenting function: _ZNKSt9basic_iosIcSt11char_traitsIcEE7rdstateEv
Trace2Pass: Instrumenting function: _ZSt5flushIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_
Trace2Pass: Instrumenting function: _ZNKSt9basic_iosIcSt11char_traitsIcEE5widenEc
Trace2Pass: Instrumenting function: _ZSt13__check_facetISt5ctypeIcEERKT_PS3_
Trace2Pass: Instrumented 0 arithmetic operations, 1 unreachable blocks in _ZSt13__check_facetISt5ctypeIcEERKT_PS3_
Trace2Pass: Instrumenting function: _ZNKSt5ctypeIcE5widenEc
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_format_argsINS0_7contextEEC2ILi1ELi0ELy1ETnNSt9enable_ifIXleT_LNS0_6detail3$_0E15EEiE4typeELi0EEERKNS6_16format_arg_storeIS2_XT_EXT0_EXT1_EEE
Trace2Pass: Instrumenting function: _ZN3fmt3v1217basic_format_argsINS0_7contextEEC2ILi1ELi0ELy10ETnNSt9enable_ifIXleT_LNS0_6detail3$_0E15EEiE4typeELi0EEERKNS6_16format_arg_storeIS2_XT_EXT0_EXT1_EEE
Trace2Pass: Instrumenting function: _GLOBAL__sub_I_fmt_test.cpp
11 warnings generated.
=== TEST OUTPUT START ===
Trace2Pass: Runtime initialized (sample_rate=0.100, opt_level=unknown)
FAIL: nan=inf
Trace2Pass: Runtime shutting down
TEST_EXIT_CODE=1
=== TEST OUTPUT END ===
```


## Reproduction

```bash
# Run all projects × flags:
./evaluation/strategies/strategy3_aggressive_flags.sh --llvm 19

# Run a single project:
./evaluation/strategies/strategy3_aggressive_flags.sh --llvm 19 --project mbedtls
```
