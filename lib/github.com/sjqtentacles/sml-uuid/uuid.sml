(* uuid.sml

   Implementation of UUID.

   A uuid is exactly 16 bytes (a Word8Vector). v4/v7 build the bytes, then
   stamp the version nibble (high nibble of byte 6) and the variant bits (top
   two bits of byte 8 set to 10). toString/fromString convert to and from the
   canonical 8-4-4-4-12 hex form. *)

structure Uuid :> UUID =
struct
  type uuid = Word8Vector.vector   (* always length 16 *)

  val nil_ : uuid = Word8Vector.tabulate (16, fn _ => 0w0)

  fun bytes u = u

  fun equals (a, b) =
      let fun same i = i >= 16
                     orelse (Word8Vector.sub (a, i) = Word8Vector.sub (b, i)
                             andalso same (i + 1))
      in same 0 end

  (* set version nibble (byte 6 high nibble) and variant bits (byte 8 top 2). *)
  fun stamp (arr, ver) =
      let
        val b6 = Array.sub (arr, 6)
        val b6' = Word8.orb (Word8.andb (b6, 0wx0F),
                             Word8.<< (Word8.fromInt ver, 0w4))
        val b8 = Array.sub (arr, 8)
        val b8' = Word8.orb (Word8.andb (b8, 0wx3F), 0wx80)  (* 10xxxxxx *)
      in
        Array.update (arr, 6, b6');
        Array.update (arr, 8, b8')
      end

  fun v4 randByte =
      let
        val arr = Array.tabulate (16, fn _ => randByte ())
      in
        stamp (arr, 4);
        Word8Vector.tabulate (16, fn i => Array.sub (arr, i))
      end

  fun v7 {millis, randByte} =
      let
        (* 48-bit big-endian millis in bytes 0..5 *)
        fun msByte k =
            let val shift = Word.fromInt (8 * (5 - k))
                val v = IntInf.andb (IntInf.~>> (millis, shift), 0xFF)
            in Word8.fromInt (IntInf.toInt v) end
        val arr = Array.tabulate (16, fn i =>
                      if i < 6 then msByte i else randByte ())
      in
        stamp (arr, 7);
        Word8Vector.tabulate (16, fn i => Array.sub (arr, i))
      end

  fun version u =
      Word8.toInt (Word8.>> (Word8Vector.sub (u, 6), 0w4))

  (* ---- formatting ---- *)
  val lower = "0123456789abcdef"
  fun hex2 b =
      let val hi = Word8.toInt (Word8.>> (b, 0w4))
          val lo = Word8.toInt (Word8.andb (b, 0wxF))
      in String.implode [String.sub (lower, hi), String.sub (lower, lo)] end

  fun toString u =
      let
        fun seg (lo, hi) =
            String.concat (List.tabulate (hi - lo, fn k => hex2 (Word8Vector.sub (u, lo + k))))
      in
        String.concatWith "-"
          [seg (0, 4), seg (4, 6), seg (6, 8), seg (8, 10), seg (10, 16)]
      end

  (* ---- parsing ---- *)
  fun digitVal c =
      if c >= #"0" andalso c <= #"9" then SOME (Char.ord c - Char.ord #"0")
      else if c >= #"a" andalso c <= #"f" then SOME (Char.ord c - Char.ord #"a" + 10)
      else if c >= #"A" andalso c <= #"F" then SOME (Char.ord c - Char.ord #"A" + 10)
      else NONE

  fun fromString s =
      (* canonical form: 36 chars, hyphens at 8,13,18,23, 32 hex digits *)
      if String.size s <> 36 then NONE
      else if String.sub (s, 8) <> #"-" orelse String.sub (s, 13) <> #"-"
              orelse String.sub (s, 18) <> #"-" orelse String.sub (s, 23) <> #"-"
      then NONE
      else
        let
          (* gather the 32 hex digit characters in order *)
          val hexChars =
              List.filter (fn c => c <> #"-") (String.explode s)
        in
          if List.length hexChars <> 32 then NONE
          else
            let
              exception Bad
              val arr = Array.array (16, 0w0 : Word8.word)
              fun fill (_, []) = ()
                | fill (i, hi :: lo :: rest) =
                    (case (digitVal hi, digitVal lo) of
                         (SOME h, SOME l) =>
                           (Array.update (arr, i, Word8.fromInt (h * 16 + l));
                            fill (i + 1, rest))
                       | _ => raise Bad)
                | fill (_, [_]) = raise Bad
            in
              (fill (0, hexChars);
               SOME (Word8Vector.tabulate (16, fn i => Array.sub (arr, i))))
              handle Bad => NONE
            end
        end

  (* ---- v5 (name-based, SHA-1) ---- *)
  (* The standard RFC 4122 namespace UUIDs. These literals are well-formed, so
     fromString never returns NONE here. *)
  fun ns s = valOf (fromString s)
  val namespaceDns  = ns "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
  val namespaceUrl  = ns "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
  val namespaceOid  = ns "6ba7b812-9dad-11d1-80b4-00c04fd430c8"
  val namespaceX500 = ns "6ba7b814-9dad-11d1-80b4-00c04fd430c8"

  (* SHA-1 over the 16 namespace bytes followed by the name; the first 16 bytes
     of the 20-byte digest become the UUID, then version 5 and the variant bits
     are stamped. Sha1.digest treats a string as a byte sequence. *)
  fun v5 {namespace, name} =
      let
        val digest = Sha1.digest (Byte.bytesToString namespace ^ name)
        val arr = Array.tabulate (16, fn i => Byte.charToByte (String.sub (digest, i)))
      in
        stamp (arr, 5);
        Word8Vector.tabulate (16, fn i => Array.sub (arr, i))
      end
end
