(* Dependency-free test runner for the Uuid structure.
 * Prints one line per assertion and exits non-zero if any assertion fails. *)

val passed = ref 0
val failed = ref 0

fun check (name : string) (cond : bool) : unit =
    if cond
    then (passed := !passed + 1; print ("ok   - " ^ name ^ "\n"))
    else (failed := !failed + 1; print ("FAIL - " ^ name ^ "\n"))

structure U = Uuid

(* a deterministic byte source: 0,1,2,...,255,0,1,... *)
fun counter () =
    let val r = ref 0
    in fn () => let val v = !r in r := (v + 1) mod 256; Word8.fromInt v end end

(* a constant byte source *)
fun constByte b () = Word8.fromInt b

fun run () =
  let
    (* ---- nil ---- *)
    val () = check "nil toString" (U.toString U.nil_ = "00000000-0000-0000-0000-000000000000")
    val () = check "nil bytes length 16" (Word8Vector.length (U.bytes U.nil_) = 16)
    val () = check "nil version 0" (U.version U.nil_ = 0)
    val () = check "nil equals nil" (U.equals (U.nil_, U.nil_))

    (* ---- v4 with deterministic source (bytes 0..15) ---- *)
    val u4 = U.v4 (counter ())
    val () = check "v4 known string"
                   (U.toString u4 = "00010203-0405-4607-8809-0a0b0c0d0e0f")
    val () = check "v4 version is 4" (U.version u4 = 4)
    val () = check "v4 bytes length 16" (Word8Vector.length (U.bytes u4) = 16)
    (* variant nibble: first char of 4th group must be in {8,9,a,b} *)
    val () =
      let val s = U.toString u4
          val variantChar = String.sub (s, 19)
      in check "v4 variant nibble in {8,9,a,b}"
               (variantChar = #"8" orelse variantChar = #"9"
                orelse variantChar = #"a" orelse variantChar = #"b")
      end

    (* v4 with all-0xFF source: version/variant bits still correct *)
    val uff = U.v4 (constByte 255)
    val () = check "v4 all-FF version 4" (U.version uff = 4)
    val () =
      let val variantChar = String.sub (U.toString uff, 19)
      in check "v4 all-FF variant nibble valid"
               (variantChar = #"8" orelse variantChar = #"9"
                orelse variantChar = #"a" orelse variantChar = #"b")
      end

    (* ---- v7 timestamp prefix ---- *)
    (* millis = 0x0123456789AB -> first 6 bytes big-endian *)
    val ts : IntInf.int = 0x0123456789AB
    val u7 = U.v7 {millis = ts, randByte = constByte 0}
    val () = check "v7 version is 7" (U.version u7 = 7)
    val () = check "v7 timestamp prefix big-endian"
                   (String.isPrefix "0123456789ab" (String.translate
                      (fn #"-" => "" | c => String.str c) (U.toString u7)))
    val () =
      let val b = U.bytes u7
          fun bv i = Word8.toInt (Word8Vector.sub (b, i))
      in check "v7 prefix bytes"
               (bv 0 = 0x01 andalso bv 1 = 0x23 andalso bv 2 = 0x45
                andalso bv 3 = 0x67 andalso bv 4 = 0x89 andalso bv 5 = 0xAB)
      end

    (* v7 monotonic across increasing millis (compare string lexicographically) *)
    val () =
      let
        val a = U.toString (U.v7 {millis = 1000, randByte = constByte 0})
        val b = U.toString (U.v7 {millis = 2000, randByte = constByte 0})
        val c = U.toString (U.v7 {millis = 1000000, randByte = constByte 0})
      in
        check "v7 monotonic by timestamp" (a < b andalso b < c)
      end

    (* ---- toString / fromString round-trip ---- *)
    val () = check "fromString of v4 round-trips"
                   (case U.fromString (U.toString u4) of
                        SOME u => U.equals (u, u4) | NONE => false)
    val () = check "fromString accepts uppercase"
                   (case U.fromString "00010203-0405-4607-8809-0A0B0C0D0E0F" of
                        SOME u => U.equals (u, u4) | NONE => false)
    val () = check "fromString nil round-trips"
                   (case U.fromString "00000000-0000-0000-0000-000000000000" of
                        SOME u => U.equals (u, U.nil_) | NONE => false)
    val () = check "toString of fromString is identity (lowercase)"
                   (case U.fromString "12345678-9abc-def0-1234-567890abcdef" of
                        SOME u => U.toString u = "12345678-9abc-def0-1234-567890abcdef"
                      | NONE => false)

    (* ---- fromString rejects malformed ---- *)
    fun rejects s = not (Option.isSome (U.fromString s))
    val () = check "reject empty" (rejects "")
    val () = check "reject too short" (rejects "1234")
    val () = check "reject missing hyphens"
                   (rejects "000102030405460788090a0b0c0d0e0f")
    val () = check "reject wrong hyphen position"
                   (rejects "0001020-30405-4607-8809-0a0b0c0d0e0f")
    val () = check "reject non-hex char"
                   (rejects "0001020g-0405-4607-8809-0a0b0c0d0e0f")
    val () = check "reject too long"
                   (rejects "00010203-0405-4607-8809-0a0b0c0d0e0fff")
    val () = check "reject extra hyphen group"
                   (rejects "0001-0203-0405-4607-8809-0a0b0c0d0e0f")

    (* ---- v5 (name-based, SHA-1) ---- *)
    (* standard RFC 4122 namespace UUIDs *)
    val () = check "namespaceDns string"
                   (U.toString U.namespaceDns = "6ba7b810-9dad-11d1-80b4-00c04fd430c8")
    val () = check "namespaceUrl string"
                   (U.toString U.namespaceUrl = "6ba7b811-9dad-11d1-80b4-00c04fd430c8")
    val () = check "namespaceOid string"
                   (U.toString U.namespaceOid = "6ba7b812-9dad-11d1-80b4-00c04fd430c8")
    val () = check "namespaceX500 string"
                   (U.toString U.namespaceX500 = "6ba7b814-9dad-11d1-80b4-00c04fd430c8")

    (* known RFC 4122 v5 vectors *)
    val v5dns1 = U.v5 {namespace = U.namespaceDns, name = "example.com"}
    val () = check "v5 dns example.com"
                   (U.toString v5dns1 = "cfbff0d1-9375-5685-968c-48ce8b15ae17")
    val v5dns2 = U.v5 {namespace = U.namespaceDns, name = "python.org"}
    val () = check "v5 dns python.org"
                   (U.toString v5dns2 = "886313e1-3b8a-5372-9b90-0c9aee199e5d")
    val v5url = U.v5 {namespace = U.namespaceUrl, name = "http://example.com/"}
    val () = check "v5 url http://example.com/"
                   (U.toString v5url = "0a300ee9-f9e4-5697-a51a-efc7fafaba67")

    (* version nibble and variant bits *)
    val () = check "v5 version is 5" (U.version v5dns1 = 5)
    val () = check "v5 bytes length 16" (Word8Vector.length (U.bytes v5dns1) = 16)
    val () =
      let val variantChar = String.sub (U.toString v5dns1, 19)
      in check "v5 variant nibble in {8,9,a,b}"
               (variantChar = #"8" orelse variantChar = #"9"
                orelse variantChar = #"a" orelse variantChar = #"b")
      end
    val () =
      let val b8 = Word8Vector.sub (U.bytes v5dns1, 8)
      in check "v5 variant bits 10xxxxxx"
               (Word8.andb (b8, 0wxC0) = 0wx80)
      end

    (* deterministic: same inputs -> same output *)
    val () = check "v5 deterministic"
                   (U.equals (v5dns1, U.v5 {namespace = U.namespaceDns, name = "example.com"}))
    (* different name -> different uuid *)
    val () = check "v5 distinct names differ" (not (U.equals (v5dns1, v5dns2)))

    (* toString / fromString round-trip for v5 *)
    val () = check "v5 fromString round-trips"
                   (case U.fromString (U.toString v5dns1) of
                        SOME u => U.equals (u, v5dns1) | NONE => false)

    (* ---- equals discriminates ---- *)
    val () = check "different uuids not equal" (not (U.equals (u4, U.nil_)))
    val () = check "v4 differs from all-FF v4" (not (U.equals (u4, uff)))
  in
    print ("\n" ^ Int.toString (!passed) ^ " passed, "
           ^ Int.toString (!failed) ^ " failed\n");
    OS.Process.exit (if !failed = 0 then OS.Process.success else OS.Process.failure)
  end

val () = run ()
