(* uuid.sig

   RFC 4122 / RFC 9562 UUID parsing, formatting, and generation for Standard
   ML.

   Generation is deterministic and testable: randomness is supplied by the
   caller as a byte source (`unit -> Word8.word`) rather than read from a
   global RNG, and the v7 timestamp is supplied explicitly. This keeps the
   library I/O-free and its output reproducible from its inputs.

     - v4: 16 random bytes, with the version nibble set to 4 and the variant
           bits set to the RFC 4122 variant (10xx).
     - v7: a 48-bit big-endian Unix-millisecond timestamp prefix, then random
           bytes, again with version 7 and the variant bits set. v7 values are
           monotonically ordered by their timestamp prefix.
     - v5: name-based and deterministic. The 16 namespace bytes are prefixed to
           the name string, hashed with SHA-1, and the first 16 bytes of the
           digest become the UUID with version 5 and the variant bits set. The
           four standard RFC 4122 namespace UUIDs are provided as constants.

   `toString` renders the canonical lowercase 8-4-4-4-12 form; `fromString`
   accepts upper or lower case and returns NONE on anything malformed. *)

signature UUID =
sig
  type uuid

  (* Generate from a caller-supplied byte source. *)
  val v4 : (unit -> Word8.word) -> uuid
  val v7 : { millis : IntInf.int, randByte : unit -> Word8.word } -> uuid

  (* Name-based v5: SHA-1 of the namespace bytes followed by the name. *)
  val v5 : { namespace : uuid, name : string } -> uuid

  (* The standard RFC 4122 namespace UUIDs. *)
  val namespaceDns  : uuid
  val namespaceUrl  : uuid
  val namespaceOid  : uuid
  val namespaceX500 : uuid

  val toString   : uuid -> string                 (* lowercase 8-4-4-4-12 *)
  val fromString : string -> uuid option

  val version : uuid -> int                        (* the version nibble *)
  val nil_    : uuid                               (* all-zero UUID *)
  val equals  : uuid * uuid -> bool
  val bytes   : uuid -> Word8Vector.vector         (* the 16 bytes *)
end
