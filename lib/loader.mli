(** Reading card and enemy definitions from JSON.

    The loader only turns JSON into [Types] values. It rejects anything
    that cannot become a [Types] value (bad JSON syntax, missing or
    misspelled fields, wrong JSON types, unknown tags such as a status
    ["stun"]). Content that is representable but wrong (duplicate IDs,
    negative costs, empty patterns, ...) is the job of [Validate].

    The loader never raises on bad input. It collects every problem it can
    find, not just the first, and each message starts with where the
    problem is, for example:

    {v
    data/cards.json: cards[2] ("bash").effects[1].status: unknown status "stun" (expected one of: strength, weak, vulnerable, poison)
    v}

    The JSON format is documented in the README ("Content format"). *)

val parse_cards :
  source:string -> Yojson.Safe.t -> (Types.card_def list, string list) result
(** [parse_cards ~source json] reads a cards document
    [{"cards": [...]}]. [source] (usually the file name) begins every
    error message. *)

val parse_enemies :
  source:string -> Yojson.Safe.t -> (Types.enemy_def list, string list) result
(** [parse_enemies ~source json] reads an enemies document
    [{"enemies": [...]}]. [source] begins every error message. *)

val load_files :
  cards:string -> enemies:string -> (Types.content, string list) result
(** [load_files ~cards ~enemies] reads and parses the two files. Errors
    from both files are reported together. *)

val load : string -> (Types.content, string list) result
(** [load dir] is [load_files] on [dir/cards.json] and [dir/enemies.json].
    The game calls [load "data"]. It does not run [Validate]; callers
    should run [Validate.content] on the result before using it. *)
