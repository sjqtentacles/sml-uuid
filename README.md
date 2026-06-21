# sml-uuid

[![CI](https://github.com/sjqtentacles/sml-uuid/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-uuid/actions/workflows/ci.yml)

RFC 4122 / RFC 9562 UUID parsing, formatting, and generation for Standard ML.

`sml-uuid` generates version 4 (random) and version 7 (timestamp-ordered)
UUIDs. Generation is **deterministic and testable**: randomness is supplied by
the caller as a byte source (`unit -> Word8.word`) rather than read from a
global RNG, and the v7 timestamp is passed in explicitly. This keeps the
library I/O-free and its output reproducible from its inputs.

## Portability

Pure Standard ML using only the Basis library -- no FFI, no threads. Verified
on **MLton** and **Poly/ML**.

## Building and testing

```sh
make test        # build + run the suite under MLton (default)
make test-poly   # run the suite under Poly/ML
make all-tests   # run under both
make clean
```

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-uuid
smlpkg sync
```

Then reference the library basis from your own `.mlb`:

```
lib/github.com/sjqtentacles/sml-uuid/uuid.mlb
```

For Poly/ML, `use` the `uuid.sig` and `uuid.sml` sources in order.

## Usage

You supply the randomness, so you choose the RNG (and can make it
deterministic for tests):

```sml
(* a real generator would wire in MLton/Poly random bytes here *)
fun randByte () = (* ... : Word8.word *) 0w0

val u = Uuid.v4 randByte
val s = Uuid.toString u                  (* "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx" *)
val v = Uuid.version u                   (* 4 *)

(* v7: 48-bit big-endian millisecond prefix, then random tail; ordered by time *)
val u7 = Uuid.v7 { millis = 1718900000000, randByte = randByte }

val SOME parsed = Uuid.fromString s      (* accepts upper or lower case *)
val NONE        = Uuid.fromString "nope" (* malformed -> NONE           *)

val same = Uuid.equals (u, parsed)
val raw  = Uuid.bytes u                  (* the 16 bytes *)
```

v7 UUIDs sort by their timestamp prefix, so lexicographic string order matches
chronological order for a fixed byte source.

## API summary

| Function | Description |
| --- | --- |
| `v4 : (unit -> Word8.word) -> uuid` | Random UUID from a byte source. |
| `v7 : { millis : IntInf.int, randByte : unit -> Word8.word } -> uuid` | Time-ordered UUID. |
| `toString : uuid -> string` | Canonical lowercase 8-4-4-4-12 form. |
| `fromString : string -> uuid option` | Parse (case-insensitive); `NONE` if malformed. |
| `version : uuid -> int` | The version nibble. |
| `nil_ : uuid` | The all-zero UUID. |
| `equals : uuid * uuid -> bool` | Structural equality. |
| `bytes : uuid -> Word8Vector.vector` | The 16 raw bytes. |

## License

MIT. See [LICENSE](LICENSE).
