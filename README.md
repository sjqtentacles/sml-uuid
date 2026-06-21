# sml-uuid

[![CI](https://github.com/sjqtentacles/sml-uuid/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-uuid/actions/workflows/ci.yml)

RFC 4122 / RFC 9562 UUID parsing, formatting, and generation for Standard ML.

`sml-uuid` generates version 4 (random), version 5 (name-based, SHA-1), and
version 7 (timestamp-ordered) UUIDs. Generation is **deterministic and
testable**: randomness is supplied by the caller as a byte source
(`unit -> Word8.word`) rather than read from a global RNG, and the v7 timestamp
is passed in explicitly. v5 is deterministic by construction (a SHA-1 hash of
namespace + name). This keeps the library I/O-free and its output reproducible
from its inputs.

## Portability

Pure Standard ML using only the Basis library -- no FFI, no threads. SHA-1 for
v5 comes from a vendored copy of
[`sml-codec`](https://github.com/sjqtentacles/sml-codec) (under
`lib/github.com/sjqtentacles/sml-codec/`). Verified on **MLton** and
**Poly/ML**.

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

For Poly/ML, `use` the vendored `sha1.sig` and `sha1.sml` (under
`lib/github.com/sjqtentacles/sml-codec/`) before `uuid.sig` and `uuid.sml`, in
that order (see the `Makefile`'s `test-poly` target).

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

(* v5: name-based, deterministic (SHA-1 of namespace bytes ++ name) *)
val u5 = Uuid.v5 { namespace = Uuid.namespaceDns, name = "example.com" }
val _  = Uuid.toString u5                (* "cfbff0d1-9375-5685-968c-48ce8b15ae17" *)
val _  = Uuid.version u5                 (* 5 *)

val SOME parsed = Uuid.fromString s      (* accepts upper or lower case *)
val NONE        = Uuid.fromString "nope" (* malformed -> NONE           *)

val same = Uuid.equals (u, parsed)
val raw  = Uuid.bytes u                  (* the 16 bytes *)
```

v7 UUIDs sort by their timestamp prefix, so lexicographic string order matches
chronological order for a fixed byte source.

### v5 namespaces

v5 hashes a namespace UUID together with a name, so the same inputs always
yield the same UUID. The four standard RFC 4122 namespaces are provided:

```sml
Uuid.namespaceDns    (* 6ba7b810-9dad-11d1-80b4-00c04fd430c8 *)
Uuid.namespaceUrl    (* 6ba7b811-9dad-11d1-80b4-00c04fd430c8 *)
Uuid.namespaceOid    (* 6ba7b812-9dad-11d1-80b4-00c04fd430c8 *)
Uuid.namespaceX500   (* 6ba7b814-9dad-11d1-80b4-00c04fd430c8 *)
```

Any UUID can serve as a namespace; nesting `v5` results builds hierarchical,
reproducible identifiers.

## API summary

| Function | Description |
| --- | --- |
| `v4 : (unit -> Word8.word) -> uuid` | Random UUID from a byte source. |
| `v5 : { namespace : uuid, name : string } -> uuid` | Name-based (SHA-1) UUID. |
| `v7 : { millis : IntInf.int, randByte : unit -> Word8.word } -> uuid` | Time-ordered UUID. |
| `namespaceDns`, `namespaceUrl`, `namespaceOid`, `namespaceX500 : uuid` | Standard RFC 4122 namespaces for v5. |
| `toString : uuid -> string` | Canonical lowercase 8-4-4-4-12 form. |
| `fromString : string -> uuid option` | Parse (case-insensitive); `NONE` if malformed. |
| `version : uuid -> int` | The version nibble. |
| `nil_ : uuid` | The all-zero UUID. |
| `equals : uuid * uuid -> bool` | Structural equality. |
| `bytes : uuid -> Word8Vector.vector` | The 16 raw bytes. |

## License

MIT. See [LICENSE](LICENSE).
